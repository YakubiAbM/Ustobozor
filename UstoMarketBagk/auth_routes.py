"""
Аутентификация мастеров: OTP по SMS (Alif stub), refresh/logout/me.
"""

import logging
import time
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from auth import (
    create_access_token,
    create_refresh_token,
    ensure_admin_role_for_phone_norm,
    find_valid_refresh,
    get_current_user,
    get_master_for_me,
    hash_password,
    normalize_phone,
    revoke_refresh_by_hash,
    revoke_all_refresh_for_user,
    save_refresh_token,
    verify_password,
)
from config import DEBUG, SKIP_MASTER_OTP, SUPPORT_WHATSAPP
from database import MasterDB, get_db
from services.alif_sms import send_alif_sms_backup
from services.otp_service import (
    block_message_for_phone,
    check_rate_limit,
    generate_code,
    increment_rate_limit,
    is_otp_store_ready,
    is_phone_blocked,
    normalize_phone_intl,
    phone_norm_from_intl,
    save_otp,
    verify_otp_code,
)

try:
    from rate_limit import limiter
except ImportError:
    limiter = None

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])


def _rate_limit(limit: str):
    if limiter is None:
        return lambda f: f
    return limiter.limit(limit)


class RequestCodeBody(BaseModel):
    phone_number: str


class VerifyCodeBody(BaseModel):
    phone_number: str
    code: str
    name: Optional[str] = None


class RefreshRequest(BaseModel):
    refresh_token: str


class PhoneBody(BaseModel):
    phone_number: str


class LoginPasswordBody(BaseModel):
    phone_number: str
    password: str


class SetNewPasswordBody(BaseModel):
    phone_number: str
    new_password: str


class RegisterBody(BaseModel):
    phone_number: str
    password: str
    name: Optional[str] = None


def _resolve_phone(phone_raw: str) -> tuple[str, str]:
    phone_intl = normalize_phone_intl(phone_raw)
    phone_norm = phone_norm_from_intl(phone_intl)
    return phone_intl, phone_norm


def _find_master_by_phone(db: Session, phone_norm: str) -> Optional[MasterDB]:
    master = db.query(MasterDB).filter(MasterDB.phone_norm == phone_norm).first()
    if master:
        return master
    for m in db.query(MasterDB).filter(MasterDB.phone.isnot(None)).all():
        if normalize_phone(m.phone) == phone_norm:
            m.phone_norm = phone_norm
            db.commit()
            db.refresh(m)
            return m
    return None


def _phone_check_status(master: Optional[MasterDB]) -> str:
    if not master:
        return "NOT_FOUND"
    if int(getattr(master, "is_password_reset", 0) or 0) == 1:
        return "RESET_REQUIRED"
    return "PASSWORD_REQUIRED"


def _validate_password_strength(password: str) -> None:
    pwd = (password or "").strip()
    if len(pwd) < 4:
        raise HTTPException(status_code=400, detail="Пароль должен быть не короче 4 символов")
    if len(pwd) > 64:
        raise HTTPException(status_code=400, detail="Пароль слишком длинный")


@router.post("/check-phone")
@_rate_limit("30/minute")
def check_phone(req: PhoneBody, request: Request, db: Session = Depends(get_db)):
    """Проверка номера: NOT_FOUND | RESET_REQUIRED | PASSWORD_REQUIRED."""
    try:
        phone_intl, phone_norm = _resolve_phone(req.phone_number)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid phone number")

    master = _find_master_by_phone(db, phone_norm)
    status_value = _phone_check_status(master)
    out = {"status": status_value, "phone_number": phone_intl}
    if master:
        out["master_id"] = master.id
        out["name"] = master.name
    return out


@router.post("/login")
@_rate_limit("20/minute")
def login_password(req: LoginPasswordBody, request: Request, db: Session = Depends(get_db)):
    """Вход по телефону и паролю."""
    try:
        phone_intl, phone_norm = _resolve_phone(req.phone_number)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid phone number")

    master = _find_master_by_phone(db, phone_norm)
    if not master:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    if int(getattr(master, "is_password_reset", 0) or 0) == 1:
        raise HTTPException(
            status_code=403,
            detail="Пароль сброшен администратором. Задайте новый пароль в приложении.",
        )

    if not verify_password(req.password, getattr(master, "password_hash", None)):
        if not getattr(master, "password_hash", None):
            raise HTTPException(
                status_code=403,
                detail="Пароль не задан. Попросите администратора сбросить пароль в админке.",
            )
        raise HTTPException(status_code=401, detail="Неверный пароль")

    return _complete_login(db, master, phone_norm, request)


@router.post("/set-new-password")
@_rate_limit("10/minute")
def set_new_password(req: SetNewPasswordBody, request: Request, db: Session = Depends(get_db)):
    """Установка нового пароля после сброса администратором."""
    try:
        phone_intl, phone_norm = _resolve_phone(req.phone_number)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid phone number")

    _validate_password_strength(req.new_password)

    master = _find_master_by_phone(db, phone_norm)
    if not master:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    if int(getattr(master, "is_password_reset", 0) or 0) != 1:
        raise HTTPException(status_code=403, detail="Сброс пароля не одобрен администратором")

    master.password_hash = hash_password(req.new_password.strip())
    master.is_password_reset = 0
    db.commit()
    db.refresh(master)

    return _complete_login(db, master, phone_norm, request)


@router.post("/register")
@_rate_limit("10/minute")
def register_master(req: RegisterBody, request: Request, db: Session = Depends(get_db)):
    """Регистрация нового мастера: телефон + пароль."""
    try:
        phone_intl, phone_norm = _resolve_phone(req.phone_number)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid phone number")

    _validate_password_strength(req.password)

    existing = _find_master_by_phone(db, phone_norm)
    if existing:
        raise HTTPException(status_code=409, detail="Пользователь с этим номером уже зарегистрирован")

    master = MasterDB(
        name=(req.name or "").strip() or "Новый мастер",
        phone=phone_intl,
        phone_norm=phone_norm,
        role="user",
        categories_json="[]",
        services_json="[]",
        portfolio_json="[]",
        password_hash=hash_password(req.password.strip()),
        is_password_reset=0,
    )
    db.add(master)
    db.commit()
    db.refresh(master)

    return _complete_login(db, master, phone_norm, request)


def _ensure_master(db: Session, phone_raw: str, phone_norm: str) -> MasterDB:
    master = db.query(MasterDB).filter(MasterDB.phone_norm == phone_norm).first()
    if not master:
        for m in db.query(MasterDB).filter(MasterDB.phone.isnot(None)).all():
            if normalize_phone(m.phone) == phone_norm:
                m.phone_norm = phone_norm
                db.commit()
                db.refresh(m)
                master = m
                break
    if not master:
        master = MasterDB(
            name="Новый мастер",
            phone=phone_raw.strip(),
            phone_norm=phone_norm,
            role="user",
            categories_json="[]",
            services_json="[]",
            portfolio_json="[]",
        )
        db.add(master)
        db.commit()
        db.refresh(master)
    elif master.phone != phone_raw.strip():
        master.phone = phone_raw.strip()
        db.commit()
    return master


def _master_code(master: MasterDB) -> str:
    """Цифровой код мастера для QR/ручного ввода на кассе (9 цифр телефона или ID)."""
    pn = getattr(master, "phone_norm", None) or normalize_phone(getattr(master, "phone", None) or "")
    if pn:
        return pn
    return str(master.id)


def _complete_login(db: Session, master: MasterDB, phone_norm: str, request: Request) -> dict:
    ensure_admin_role_for_phone_norm(db, phone_norm)
    db.refresh(master)
    role = getattr(master, "role", None) or "user"
    pin_hash = getattr(master, "pin_hash", None)

    access_token = create_access_token(master.id, phone_norm, role)
    refresh_token = create_refresh_token()
    ip = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")
    save_refresh_token(db, master.id, refresh_token, ip=ip, user_agent=user_agent)

    out = {
        "status": "success",
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "master_id": master.id,
        "name": master.name,
        "phone": master.phone,
        "points": master.points,
        "master_code": _master_code(master),
    }
    if role == "admin" and not pin_hash:
        out["need_set_pin"] = True
    return out


@router.post("/request-code")
@_rate_limit("10/minute")
def request_code(req: RequestCodeBody, request: Request):
    """OTP по SMS (Alif stub). Rate limit: 3 запроса / 15 мин."""
    if not is_otp_store_ready():
        raise HTTPException(status_code=503, detail="OTP storage unavailable")

    try:
        phone_intl = normalize_phone_intl(req.phone_number)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid phone number")

    if is_phone_blocked(phone_intl):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=block_message_for_phone(phone_intl),
        )

    if not check_rate_limit(phone_intl):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Слишком много запросов кода. Попробуйте через 15 минут.",
        )

    code = generate_code()
    delivery = send_alif_sms_backup(phone_intl, code)
    save_otp(phone_intl, "sms", code=code)
    if DEBUG:
        print(f"\n  >>> OTP SMS ({phone_intl}): {code} <<<\n", flush=True)
        delivery["dev_code"] = code

    increment_rate_limit(phone_intl)
    return {"status": delivery["status"], "retry_after": delivery.get("retry_after", 60)}


@router.post("/dev-login")
@_rate_limit("20/minute")
def dev_login(req: VerifyCodeBody, request: Request, db: Session = Depends(get_db)):
    """
    Dev-only: вход без OTP (DEBUG=true и SKIP_MASTER_OTP=1).
    На production эндпоинт возвращает 404.
    """
    if not DEBUG or not SKIP_MASTER_OTP:
        raise HTTPException(status_code=404, detail="Not found")

    try:
        phone_intl = normalize_phone_intl(req.phone_number)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid phone number")

    phone_norm = phone_norm_from_intl(phone_intl)
    master = _ensure_master(db, req.phone_number, phone_norm)
    if req.name and req.name.strip():
        master.name = req.name.strip()
        db.commit()

    logger.warning("[auth] DEV login without OTP: %s", phone_intl)
    return _complete_login(db, master, phone_norm, request)


@router.post("/verify-code")
@_rate_limit("10/minute")
def verify_code(req: VerifyCodeBody, request: Request, db: Session = Depends(get_db)):
    """Проверка OTP и выдача JWT."""
    if not is_otp_store_ready():
        raise HTTPException(status_code=503, detail="OTP storage unavailable")

    try:
        phone_intl = normalize_phone_intl(req.phone_number)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid phone number")

    phone_norm = phone_norm_from_intl(phone_intl)
    if is_phone_blocked(phone_intl):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=block_message_for_phone(phone_intl),
        )

    ok, message, remaining = verify_otp_code(phone_intl, req.code)
    if not ok:
        if remaining == 0 and (
            "попыток" in message.lower()
            or "истёк" in message.lower()
            or "заблокирован" in message.lower()
        ):
            raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=message)
        detail = message
        if remaining > 0:
            detail = f"{message}. Осталось попыток: {remaining}"
        raise HTTPException(status_code=400, detail=detail)

    master = _ensure_master(db, req.phone_number, phone_norm)
    if req.name and req.name.strip():
        master.name = req.name.strip()
        db.commit()

    return _complete_login(db, master, phone_norm, request)


@router.post("/refresh")
@_rate_limit("30/minute")
def auth_refresh(req: RefreshRequest, request: Request, db: Session = Depends(get_db)):
    row = find_valid_refresh(db, req.refresh_token)
    if not row:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")

    master = db.query(MasterDB).filter(MasterDB.id == row.user_id).first()
    if not master:
        revoke_refresh_by_hash(db, row.token_hash)
        raise HTTPException(status_code=401, detail="User not found")

    new_refresh = create_refresh_token()
    ip = request.client.host if request.client else None
    ua = request.headers.get("user-agent")
    save_refresh_token(
        db, master.id, new_refresh,
        ip=ip, user_agent=ua, replaced_token_hash=row.token_hash,
    )
    row.revoked_at = int(time.time())
    db.commit()

    phone_norm = getattr(master, "phone_norm", None) or normalize_phone(master.phone)
    role = getattr(master, "role", None) or "user"
    access_token = create_access_token(master.id, phone_norm, role)

    return {
        "access_token": access_token,
        "refresh_token": new_refresh,
        "token_type": "bearer",
    }


@router.post("/logout")
def auth_logout(req: RefreshRequest, db: Session = Depends(get_db)):
    from auth import hash_token
    revoke_refresh_by_hash(db, hash_token(req.refresh_token))
    return {"status": "success"}


@router.post("/logout_all")
def auth_logout_all(master: MasterDB = Depends(get_current_user), db: Session = Depends(get_db)):
    revoke_all_refresh_for_user(db, master.id)
    return {"status": "success"}


@router.get("/me")
def auth_me(master: MasterDB = Depends(get_master_for_me)):
    return {
        "status": "success",
        "master_id": master.id,
        "name": master.name,
        "phone": master.phone,
        "points": master.points,
        "master_code": _master_code(master),
        "debt": float(getattr(master, "debt", 0) or 0),
        "support_whatsapp": SUPPORT_WHATSAPP,
    }
