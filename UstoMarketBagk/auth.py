"""
Аутентификация: JWT access/refresh, хэширование OTP и refresh-токенов,
зависимости get_current_user и require_admin для защиты эндпоинтов.
"""

import hashlib
import hmac
import json
import secrets
import time
from types import SimpleNamespace
from typing import List, Optional

import jwt
from fastapi import Depends, HTTPException, Query, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer, APIKeyCookie
from sqlalchemy.orm import Session

from config import (
    ACCESS_TOKEN_TTL_MINUTES,
    JWT_ALGORITHM,
    JWT_SECRET,
    OTP_BLOCK_SECONDS,
    OTP_MAX_ATTEMPTS,
    OTP_TTL_SECONDS,
    REFRESH_TOKEN_TTL_DAYS,
    SKIP_ADMIN_AUTH,
    SUPERADMIN_PHONE_NORM,
)
from database import AdminDB, ClientDB, MasterDB, RefreshTokenDB, get_db

# Bearer token или cookie access_token для веб-админки
security = HTTPBearer(auto_error=False)
cookie_scheme = APIKeyCookie(name="access_token", auto_error=False)

# Супер-админ без JWT: подписанная cookie (логин+пароль из .env)
SUPERADMIN_SESSION_COOKIE = "superadmin_session"
SUPERADMIN_SESSION_TTL_SECONDS = 86400 * 7  # 7 дней


def create_superadmin_session_value() -> str:
    """Подписанное значение для cookie супер-админа (без токенов)."""
    raw = f"superadmin_{int(time.time())}"
    sig = hmac.new(JWT_SECRET.encode(), raw.encode(), hashlib.sha256).hexdigest()
    return f"{raw}.{sig}"


def verify_superadmin_session_value(value: str) -> bool:
    """Проверяет подпись и срок действия cookie супер-админа."""
    if not value or "." not in value:
        return False
    raw, sig = value.rsplit(".", 1)
    if not raw.startswith("superadmin_") or len(sig) != 64:
        return False
    expected = hmac.new(JWT_SECRET.encode(), raw.encode(), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected, sig):
        return False
    try:
        ts = int(raw.replace("superadmin_", ""))
        return (int(time.time()) - ts) <= SUPERADMIN_SESSION_TTL_SECONDS
    except ValueError:
        return False


def get_superadmin_fake_master():
    """Объект «мастер» для супер-админа (вход по cookie, без БД/токена)."""
    return SimpleNamespace(
        id=0,
        role="admin",
        is_superadmin=1,
        phone_norm=SUPERADMIN_PHONE_NORM or "",
        phone=SUPERADMIN_PHONE_NORM or "",
        admin_permissions=None,
        name="Супер-админ",
    )


# -----------------------------------------------------------------------------
# Нормализация телефона и хэширование
# -----------------------------------------------------------------------------

def normalize_phone(phone: str) -> str:
    """Оставляет только последние 9 цифр номера (единый формат для поиска)."""
    digits = "".join(c for c in phone if c.isdigit())
    return digits[-9:] if len(digits) >= 9 else digits


def hash_token(token: str) -> str:
    """SHA-256 хэш строки (для хранения refresh-токенов в БД)."""
    return hashlib.sha256(token.encode()).hexdigest()


def hash_otp(code: str) -> str:
    """Хэш OTP-кода (в БД храним только хэш)."""
    return hashlib.sha256(code.encode()).hexdigest()


def verify_otp_hash(stored_hash: Optional[str], code: str) -> bool:
    """Проверяет, что код совпадает с сохранённым хэшем."""
    if not stored_hash:
        return False
    return hashlib.sha256(code.encode()).hexdigest() == stored_hash


try:
    import bcrypt
except ImportError:
    bcrypt = None  # type: ignore


def hash_pin(pin: str) -> str:
    """Bcrypt-хэш 4-значного PIN для входа в админку."""
    if bcrypt is None:
        raise RuntimeError("bcrypt is required for PIN hashing")
    return bcrypt.hashpw(pin.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_pin_hash(stored_hash: Optional[str], pin: str) -> bool:
    """Проверяет PIN: bcrypt (новые) или legacy SHA-256."""
    if not stored_hash or not pin:
        return False
    if stored_hash.startswith("$2"):
        try:
            return bcrypt.checkpw(pin.encode("utf-8"), stored_hash.encode("utf-8"))
        except Exception:
            return False
    return hashlib.sha256(pin.encode()).hexdigest() == stored_hash


def hash_password(password: str) -> str:
    """Bcrypt-хэш пароля (мастер / клиент)."""
    if bcrypt is None:
        raise RuntimeError("bcrypt is required for password hashing")
    pwd = (password or "").encode("utf-8")
    return bcrypt.hashpw(pwd, bcrypt.gensalt()).decode("utf-8")


def verify_password(plain_password: str, stored_hash: Optional[str]) -> bool:
    if not stored_hash or not plain_password or bcrypt is None:
        return False
    try:
        return bcrypt.checkpw(
            plain_password.encode("utf-8"),
            stored_hash.encode("utf-8"),
        )
    except Exception:
        return False


# -----------------------------------------------------------------------------
# JWT Access Token
# -----------------------------------------------------------------------------

def create_access_token(
    master_id: Optional[int] = None,
    phone_norm: str = "",
    role: str = "user",
    admin_id: Optional[int] = None,
    client_id: Optional[int] = None,
) -> str:
    """Создаёт JWT access token. client_id — покупатель; admin_id — админ; иначе master."""
    now = int(time.time())
    if client_id is not None:
        payload = {
            "sub": str(client_id),
            "kind": "client",
            "phone_norm": phone_norm,
            "iat": now,
            "exp": now + ACCESS_TOKEN_TTL_MINUTES * 60,
            "type": "access",
        }
    elif admin_id is not None:
        payload = {
            "sub": str(admin_id),
            "kind": "admin",
            "phone_norm": phone_norm,
            "iat": now,
            "exp": now + ACCESS_TOKEN_TTL_MINUTES * 60,
            "type": "access",
        }
    else:
        payload = {
            "sub": str(master_id or 0),
            "phone_norm": phone_norm,
            "role": role,
            "iat": now,
            "exp": now + ACCESS_TOKEN_TTL_MINUTES * 60,
            "type": "access",
        }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_access_token(token: str) -> Optional[dict]:
    """Декодирует и проверяет access token; при истечении или ошибке возвращает None."""
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        if payload.get("type") != "access":
            return None
        return payload
    except (jwt.ExpiredSignatureError, jwt.InvalidTokenError):
        return None


# -----------------------------------------------------------------------------
# Refresh Token (rotation: в БД только hash)
# -----------------------------------------------------------------------------

def create_refresh_token() -> str:
    """Генерирует криптостойкий refresh token."""
    return secrets.token_urlsafe(48)


def save_refresh_token(
    db: Session,
    user_id: int,
    token: str,
    ip: Optional[str] = None,
    user_agent: Optional[str] = None,
    replaced_token_hash: Optional[str] = None,
    user_kind: str = "master",
) -> RefreshTokenDB:
    """Сохраняет новый refresh token (hash) в БД."""
    now = int(time.time())
    expires = now + REFRESH_TOKEN_TTL_DAYS * 86400
    token_hash = hash_token(token)
    row = RefreshTokenDB(
        user_id=user_id,
        user_kind=user_kind,
        token_hash=token_hash,
        created_at=now,
        expires_at=expires,
        revoked_at=None,
        replaced_by_token_hash=replaced_token_hash,
        ip=ip,
        user_agent=user_agent,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def find_valid_refresh(db: Session, token: str) -> Optional[RefreshTokenDB]:
    """Ищет активный (не отозванный, не истёкший) refresh token по хэшу."""
    h = hash_token(token)
    return db.query(RefreshTokenDB).filter(
        RefreshTokenDB.token_hash == h,
        RefreshTokenDB.revoked_at.is_(None),
        RefreshTokenDB.expires_at > int(time.time()),
    ).first()


def revoke_refresh_by_hash(db: Session, token_hash: str) -> None:
    """Отзывает один refresh token по его хэшу (logout)."""
    row = db.query(RefreshTokenDB).filter(RefreshTokenDB.token_hash == token_hash).first()
    if row:
        row.revoked_at = int(time.time())
        db.commit()


def revoke_all_refresh_for_user(db: Session, user_id: int) -> None:
    """Отзывает все refresh токены пользователя (logout all devices)."""
    now = int(time.time())
    db.query(RefreshTokenDB).filter(RefreshTokenDB.user_id == user_id).update(
        {"revoked_at": now}, synchronize_session=False
    )
    db.commit()


# -----------------------------------------------------------------------------
# Зависимости FastAPI: текущий пользователь и админ
# -----------------------------------------------------------------------------

async def get_current_user(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    cookie: Optional[str] = Depends(cookie_scheme),
    db: Session = Depends(get_db),
):
    """
    Извлекает текущего пользователя: сначала cookie супер-админа (без токенов),
    иначе Bearer/cookie access_token (JWT).
    """
    # Супер-админ по подписанной cookie (логин+пароль из .env, без JWT)
    session_cookie = request.cookies.get(SUPERADMIN_SESSION_COOKIE)
    if session_cookie and verify_superadmin_session_value(session_cookie):
        return get_superadmin_fake_master()

    token = (credentials.credentials if credentials and credentials.credentials else None) or cookie
    if not token:
        if SKIP_ADMIN_AUTH:
            return get_superadmin_fake_master()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    payload = decode_access_token(token)
    if not payload:
        if SKIP_ADMIN_AUTH:
            return get_superadmin_fake_master()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if payload.get("kind") == "admin":
        admin_id = int(payload["sub"])
        admin = db.query(AdminDB).filter(AdminDB.id == admin_id).first()
        if not admin:
            if SKIP_ADMIN_AUTH:
                return get_superadmin_fake_master()
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Admin not found")
        setattr(admin, "role", "admin")
        return admin
    master_id = int(payload["sub"])
    master = db.query(MasterDB).filter(MasterDB.id == master_id).first()
    if not master:
        if SKIP_ADMIN_AUTH:
            return get_superadmin_fake_master()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    if getattr(master, "role", None) == "admin" and _is_superadmin_by_phone(master):
        master.is_superadmin = 1
    return master


async def get_master_for_orders_history(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    cookie: Optional[str] = Depends(cookie_scheme),
    phone: Optional[str] = Query(None, description="Запасной вариант: идентификация по телефону"),
    db: Session = Depends(get_db),
) -> MasterDB:
    """
    Для GET /orders/history: Bearer (master или client), при отсутствии — query phone.
    Для JWT клиента возвращается объект-заглушка с phone_norm.
    """
    token = (credentials.credentials if credentials and credentials.credentials else None) or cookie
    if token:
        payload = decode_access_token(token)
        if payload:
            if payload.get("kind") == "client":
                client_id = int(payload["sub"])
                client = db.query(ClientDB).filter(ClientDB.id == client_id).first()
                if client:
                    return SimpleNamespace(
                        id=0,
                        phone_norm=client.phone_norm,
                        phone=client.phone,
                        role="client",
                        is_client=True,
                    )
            master_id = int(payload["sub"])
            master = db.query(MasterDB).filter(MasterDB.id == master_id).first()
            if master:
                return master
    if phone and str(phone).strip():
        phone_norm = normalize_phone(str(phone).strip())
        if len(phone_norm) >= 9:
            master = db.query(MasterDB).filter(MasterDB.phone_norm == phone_norm).first()
            if not master:
                for m in db.query(MasterDB).filter(MasterDB.phone.isnot(None)).all():
                    if normalize_phone(m.phone or "") == phone_norm:
                        master = m
                        break
            if master:
                return master
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Not authenticated",
        headers={"WWW-Authenticate": "Bearer"},
    )


async def get_master_for_me(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    cookie: Optional[str] = Depends(cookie_scheme),
    phone: Optional[str] = Query(None, description="Запасной вариант: идентификация по телефону"),
    db: Session = Depends(get_db),
) -> MasterDB:
    """Для GET /auth/me: сначала Bearer, при отсутствии — по query phone (обновление баллов в приложении)."""
    token = (credentials.credentials if credentials and credentials.credentials else None) or cookie
    if token:
        payload = decode_access_token(token)
        if payload:
            master_id = int(payload["sub"])
            master = db.query(MasterDB).filter(MasterDB.id == master_id).first()
            if master:
                return master
    if phone and str(phone).strip():
        phone_norm = normalize_phone(str(phone).strip())
        if len(phone_norm) >= 9:
            master = db.query(MasterDB).filter(MasterDB.phone_norm == phone_norm).first()
            if not master:
                for m in db.query(MasterDB).filter(MasterDB.phone.isnot(None)).all():
                    if normalize_phone(m.phone or "") == phone_norm:
                        master = m
                        break
            if master:
                return master
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Not authenticated",
        headers={"WWW-Authenticate": "Bearer"},
    )


def require_admin(master: MasterDB = Depends(get_current_user)) -> MasterDB:
    """Зависимость: допускает только пользователей с role=admin; иначе 403."""
    role = getattr(master, "role", None) or "user"
    if role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin required")
    return master


# Список экранов админки для раздачи прав
ADMIN_SCOPES = ["dashboard", "orders", "products", "masters", "cashier"]


def _is_superadmin_by_phone(master: MasterDB) -> bool:
    """True, если номер мастера совпадает с SUPERADMIN_PHONE_NORM (из .env)."""
    if not SUPERADMIN_PHONE_NORM:
        return False
    pn = getattr(master, "phone_norm", None) or normalize_phone(getattr(master, "phone", None) or "")
    return (pn or "").strip() == SUPERADMIN_PHONE_NORM


def get_admin_permissions(master: MasterDB) -> List[str]:
    """Список разрешённых экранов для админа. Супер-админ получает все."""
    if getattr(master, "is_superadmin", None):
        return list(ADMIN_SCOPES)
    if _is_superadmin_by_phone(master):
        return list(ADMIN_SCOPES)
    raw = getattr(master, "admin_permissions", None)
    if not raw or not str(raw).strip():
        return []
    try:
        out = json.loads(raw)
        return [s for s in out if s in ADMIN_SCOPES]
    except (TypeError, json.JSONDecodeError):
        return []


def has_admin_permission(master: MasterDB, scope: str) -> bool:
    """Проверяет доступ админа к экрану (scope). Супер-админ имеет доступ ко всему."""
    if getattr(master, "is_superadmin", None):
        return True
    if _is_superadmin_by_phone(master):
        return True
    return scope in get_admin_permissions(master)


# URL для каждого раздела админки (для редиректа «на первый доступный»)
_ADMIN_SCOPE_URLS = {
    "dashboard": "/admin/dashboard",
    "orders": "/admin/orders",
    "products": "/admin/products",
    "masters": "/admin/masters",
    "cashier": "/admin/cashier",
}


def get_first_admin_page_url(master: MasterDB) -> str:
    """
    Возвращает URL первого по порядку раздела, к которому у админа есть доступ.
    После входа редиректим сюда, чтобы не попадать на дашборд без прав.
    """
    perms = get_admin_permissions(master)
    for scope in ADMIN_SCOPES:
        if scope in perms and scope in _ADMIN_SCOPE_URLS:
            return _ADMIN_SCOPE_URLS[scope]
    return "/admin/dashboard"


def require_superadmin(master: MasterDB = Depends(require_admin)) -> MasterDB:
    """Зависимость: только супер-админ (управление другими админами)."""
    if getattr(master, "is_superadmin", None):
        return master
    if _is_superadmin_by_phone(master):
        return master
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Superadmin required")


def require_admin_permission(scope: str):
    """Фабрика зависимости: админ должен иметь доступ к экрану scope."""

    def _dep(master: MasterDB = Depends(require_admin)) -> MasterDB:
        if not has_admin_permission(master, scope):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=f"Нет доступа: {scope}")
        return master

    return _dep


# -----------------------------------------------------------------------------
# OTP: блокировка и проверка срока действия
# -----------------------------------------------------------------------------

def is_otp_blocked(master: MasterDB) -> bool:
    """Проверяет, заблокирован ли пользователь из-за превышения попыток ввода OTP."""
    blocked = getattr(master, "otp_blocked_until", None)
    if not blocked:
        return False
    return int(time.time()) < blocked


def check_otp_ttl(master: MasterDB) -> bool:
    """True, если OTP ещё не истёк (в пределах OTP_TTL_SECONDS)."""
    created = getattr(master, "otp_created_at", 0) or 0
    return (int(time.time()) - created) <= OTP_TTL_SECONDS


def set_otp_blocked(master: MasterDB, db: Session) -> None:
    """Включает блокировку OTP на OTP_BLOCK_SECONDS (после N неверных попыток)."""
    master.otp_blocked_until = int(time.time()) + OTP_BLOCK_SECONDS
    db.commit()


def ensure_admin_role_for_phone_norm(db: Session, phone_norm: str) -> None:
    """
    Выдаёт роль admin при первом входе. Супер-админ: SUPERADMIN_PHONE_NORM или первый админ.
    """
    master = db.query(MasterDB).filter(MasterDB.phone_norm == phone_norm).first()
    if not master:
        return
    if SUPERADMIN_PHONE_NORM and phone_norm == SUPERADMIN_PHONE_NORM:
        master.role = "admin"
        master.is_superadmin = 1
        db.commit()
        return
    any_admin = db.query(MasterDB).filter(MasterDB.role == "admin").first()
    if not any_admin:
        master.role = "admin"
        master.is_superadmin = 1  # первый админ — супер-админ
        db.commit()


async def get_current_client(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db),
) -> ClientDB:
    """Bearer JWT с kind=client → ClientDB."""
    token = credentials.credentials if credentials and credentials.credentials else None
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    payload = decode_access_token(token)
    if not payload or payload.get("kind") != "client":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    client = db.query(ClientDB).filter(ClientDB.id == int(payload["sub"])).first()
    if not client:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return client
