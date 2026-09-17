"""
Аутентификация покупателей (клиентов): телефон + личный код (мин. 4 символа).
"""

import logging
import time
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy.orm import Session

from auth import (
    create_access_token,
    create_refresh_token,
    find_valid_refresh,
    hash_password,
    hash_token,
    normalize_phone,
    revoke_refresh_by_hash,
    save_refresh_token,
    verify_password,
)
from database import ClientDB, get_db
from services.otp_service import normalize_phone_intl, phone_norm_from_intl
from services.auth_form_security import (
    assert_not_login_locked,
    clear_login_failures,
    guard_auth_form,
    record_login_failure,
    sanitize_display_name,
    validate_password_or_code,
)

try:
    from rate_limit import limiter
except ImportError:
    limiter = None

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth/client", tags=["client-auth"])


def _rate_limit(limit: str):
    if limiter is None:
        return lambda f: f
    return limiter.limit(limit)


class PhoneBody(BaseModel):
    phone_number: str
    website: Optional[str] = None
    form_started_at: Optional[float] = None


class LoginBody(BaseModel):
    phone_number: str
    password: str
    website: Optional[str] = None
    form_started_at: Optional[float] = None


class RegisterBody(BaseModel):
    phone_number: str
    password: str
    name: Optional[str] = None
    website: Optional[str] = None
    form_started_at: Optional[float] = None


class RefreshBody(BaseModel):
    refresh_token: str


def _resolve_phone(phone_raw: str) -> tuple[str, str]:
    phone_intl = normalize_phone_intl(phone_raw)
    phone_norm = phone_norm_from_intl(phone_intl)
    return phone_intl, phone_norm


def _find_client(db: Session, phone_norm: str) -> Optional[ClientDB]:
    return db.query(ClientDB).filter(ClientDB.phone_norm == phone_norm).first()


def _login_lock_key(phone_norm: str, request: Request) -> str:
    ip = request.client.host if request.client else "unknown"
    return f"client:{phone_norm}:{ip}"


def _complete_client_login(db: Session, client: ClientDB, phone_norm: str, request: Request) -> dict:
    access_token = create_access_token(client_id=client.id, phone_norm=phone_norm)
    refresh_token = create_refresh_token()
    ip = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")
    save_refresh_token(
        db, client.id, refresh_token,
        ip=ip, user_agent=user_agent, user_kind="client",
    )
    return {
        "status": "success",
        "user_kind": "client",
        "client_id": client.id,
        "name": client.name or "",
        "phone": client.phone,
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
    }


@router.post("/check-phone")
@_rate_limit("20/minute")
def client_check_phone(req: PhoneBody, request: Request, db: Session = Depends(get_db)):
    """NOT_FOUND — регистрация; PASSWORD_REQUIRED — ввод кода."""
    guard_auth_form(
        request,
        website=req.website,
        form_started_at=req.form_started_at,
        check_timing=False,
    )
    try:
        phone_intl, phone_norm = _resolve_phone(req.phone_number)
    except ValueError:
        raise HTTPException(status_code=400, detail="Некорректный номер телефона")

    client = _find_client(db, phone_norm)
    status_value = "PASSWORD_REQUIRED" if client else "NOT_FOUND"
    return {"status": status_value, "phone_number": phone_intl}


@router.post("/register")
@_rate_limit("5/minute")
def client_register(req: RegisterBody, request: Request, db: Session = Depends(get_db)):
    """Новый клиент: телефон + личный код (мин. 4 символа)."""
    guard_auth_form(
        request,
        website=req.website,
        form_started_at=req.form_started_at,
        for_register=True,
    )
    try:
        phone_intl, phone_norm = _resolve_phone(req.phone_number)
    except ValueError:
        raise HTTPException(status_code=400, detail="Некорректный номер телефона")

    pwd = validate_password_or_code(req.password, label="Код")
    safe_name = sanitize_display_name(req.name, fallback=f"Клиент {phone_norm}")

    if _find_client(db, phone_norm):
        raise HTTPException(status_code=409, detail="Этот номер уже зарегистрирован. Введите код для входа.")

    from datetime import datetime

    client = ClientDB(
        name=safe_name,
        phone=phone_intl,
        phone_norm=phone_norm,
        password_hash=hash_password(pwd),
        created_at=datetime.now().strftime("%Y-%m-%d %H:%M"),
    )
    db.add(client)
    db.commit()
    db.refresh(client)
    return _complete_client_login(db, client, phone_norm, request)


@router.post("/login")
@_rate_limit("15/minute")
def client_login(req: LoginBody, request: Request, db: Session = Depends(get_db)):
    """Вход по телефону и личному коду."""
    guard_auth_form(request, website=req.website, form_started_at=req.form_started_at)
    try:
        phone_intl, phone_norm = _resolve_phone(req.phone_number)
    except ValueError:
        raise HTTPException(status_code=400, detail="Некорректный номер телефона")

    lock_key = _login_lock_key(phone_norm, request)
    assert_not_login_locked(lock_key)

    client = _find_client(db, phone_norm)
    if not client:
        record_login_failure(lock_key)
        raise HTTPException(status_code=401, detail="Неверный телефон или код")

    if not verify_password(req.password, client.password_hash):
        record_login_failure(lock_key)
        raise HTTPException(status_code=401, detail="Неверный телефон или код")

    clear_login_failures(lock_key)
    return _complete_client_login(db, client, phone_norm, request)


@router.post("/refresh")
@_rate_limit("30/minute")
def client_refresh(req: RefreshBody, request: Request, db: Session = Depends(get_db)):
    row = find_valid_refresh(db, req.refresh_token)
    if not row or (getattr(row, "user_kind", None) or "master") != "client":
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")

    client = db.query(ClientDB).filter(ClientDB.id == row.user_id).first()
    if not client:
        revoke_refresh_by_hash(db, row.token_hash)
        raise HTTPException(status_code=401, detail="User not found")

    new_refresh = create_refresh_token()
    ip = request.client.host if request.client else None
    ua = request.headers.get("user-agent")
    save_refresh_token(
        db, client.id, new_refresh,
        ip=ip, user_agent=ua, replaced_token_hash=row.token_hash, user_kind="client",
    )
    row.revoked_at = int(time.time())
    db.commit()

    access_token = create_access_token(client_id=client.id, phone_norm=client.phone_norm)
    return {
        "access_token": access_token,
        "refresh_token": new_refresh,
        "token_type": "bearer",
    }


@router.get("/me")
def client_me(request: Request, db: Session = Depends(get_db)):
    from auth import decode_access_token
    from fastapi import Header

    auth = request.headers.get("Authorization") or ""
    token = auth.replace("Bearer ", "").strip() if auth.startswith("Bearer ") else ""
    if not token:
        raise HTTPException(status_code=401, detail="Not authenticated")

    payload = decode_access_token(token)
    if not payload or payload.get("kind") != "client":
        raise HTTPException(status_code=401, detail="Not authenticated")

    client = db.query(ClientDB).filter(ClientDB.id == int(payload["sub"])).first()
    if not client:
        raise HTTPException(status_code=401, detail="User not found")

    return {
        "status": "success",
        "user_kind": "client",
        "client_id": client.id,
        "name": client.name,
        "phone": client.phone,
    }


@router.post("/logout")
def client_logout(req: RefreshBody, db: Session = Depends(get_db)):
    revoke_refresh_by_hash(db, hash_token(req.refresh_token))
    return {"status": "success"}
