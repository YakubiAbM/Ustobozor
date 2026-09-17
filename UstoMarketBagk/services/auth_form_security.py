"""
Защита форм регистрации/входа: санитизация, honeypot, анти-флуд, lockout.
Только оборонительные меры (без обхода защит).
"""

from __future__ import annotations

import re
import threading
import time
from typing import Optional

from fastapi import HTTPException, Request

# --- лимиты полей ---
NAME_MAX_LEN = 80
PASSWORD_MAX_LEN = 64
PASSWORD_MIN_LEN = 4
# Минимальное время заполнения формы (сек) — отсекает наивных ботов
MIN_FORM_FILL_SECONDS = 1.2
MAX_FORM_FILL_SECONDS = 60 * 60 * 6  # 6 часов — устаревший токен формы

# Honeypot: любое непустое значение = бот
HONEYPOT_FIELD = "website"

# Lockout после неудачных логинов
LOGIN_FAIL_WINDOW = 15 * 60
LOGIN_FAIL_MAX = 8
LOGIN_LOCK_SECONDS = 15 * 60

# Регистрации с одного IP
REGISTER_IP_WINDOW = 60 * 60
REGISTER_IP_MAX = 5

_lock = threading.Lock()
_login_fails: dict[str, list[float]] = {}
_login_blocks: dict[str, float] = {}
_register_ip: dict[str, list[float]] = {}

_CTRL_AND_TAGS = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]|<[^>]*>")
_MULTI_SPACE = re.compile(r"\s+")
# Имя: буквы (в т.ч. кириллица/таджик.), пробелы, дефис, апостроф
_NAME_ALLOWED = re.compile(
    r"[^\w\s\-'.\u0400-\u04FF\u0500-\u052F]+",
    re.UNICODE,
)


def client_ip(request: Request) -> str:
    forwarded = (request.headers.get("x-forwarded-for") or "").split(",")[0].strip()
    if forwarded:
        return forwarded[:45]
    if request.client and request.client.host:
        return request.client.host[:45]
    return "unknown"


def sanitize_display_name(raw: Optional[str], *, fallback: str = "Пользователь") -> str:
    """Убирает HTML/управляющие символы и ограничивает длину имени."""
    text = (raw or "").strip()
    text = _CTRL_AND_TAGS.sub(" ", text)
    text = _NAME_ALLOWED.sub("", text)
    text = _MULTI_SPACE.sub(" ", text).strip()
    if len(text) > NAME_MAX_LEN:
        text = text[:NAME_MAX_LEN].rstrip()
    return text or fallback


def validate_password_or_code(password: str, *, label: str = "Пароль") -> str:
    pwd = (password or "").strip()
    if len(pwd) < PASSWORD_MIN_LEN:
        raise HTTPException(
            status_code=400,
            detail=f"{label} должен быть не короче {PASSWORD_MIN_LEN} символов",
        )
    if len(pwd) > PASSWORD_MAX_LEN:
        raise HTTPException(status_code=400, detail=f"{label} слишком длинный")
    # Запрет управляющих символов и нулевых байтов
    if any(ord(c) < 32 for c in pwd):
        raise HTTPException(status_code=400, detail=f"Недопустимые символы в поле «{label}»")
    return pwd


def assert_honeypot_empty(website: Optional[str]) -> None:
    if website is not None and str(website).strip():
        # Тихий отказ как у rate-limit — не подсказываем боту
        raise HTTPException(status_code=400, detail="Некорректный запрос")


def assert_form_timing(form_started_at: Optional[float | int]) -> None:
    """Отклоняет мгновенную отправку и слишком старые формы."""
    if form_started_at is None:
        return  # старые клиенты без поля — не ломаем
    try:
        started = float(form_started_at)
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail="Некорректный запрос")
    now = time.time()
    elapsed = now - started
    if elapsed < MIN_FORM_FILL_SECONDS:
        raise HTTPException(status_code=400, detail="Слишком быстрая отправка. Подождите секунду.")
    if elapsed > MAX_FORM_FILL_SECONDS or started > now + 60:
        raise HTTPException(status_code=400, detail="Сессия формы устарела. Обновите экран.")


def assert_not_login_locked(key: str) -> None:
    with _lock:
        until = _login_blocks.get(key, 0)
        if until > time.time():
            wait = int(until - time.time())
            minutes = max(1, wait // 60)
            raise HTTPException(
                status_code=429,
                detail=f"Слишком много попыток. Попробуйте через {minutes} мин.",
            )


def record_login_failure(key: str) -> None:
    now = time.time()
    with _lock:
        hits = [t for t in _login_fails.get(key, []) if t >= now - LOGIN_FAIL_WINDOW]
        hits.append(now)
        _login_fails[key] = hits
        if len(hits) >= LOGIN_FAIL_MAX:
            _login_blocks[key] = now + LOGIN_LOCK_SECONDS
            _login_fails[key] = []


def clear_login_failures(key: str) -> None:
    with _lock:
        _login_fails.pop(key, None)
        _login_blocks.pop(key, None)


def assert_register_ip_allowed(ip: str) -> None:
    now = time.time()
    with _lock:
        hits = [t for t in _register_ip.get(ip, []) if t >= now - REGISTER_IP_WINDOW]
        if len(hits) >= REGISTER_IP_MAX:
            raise HTTPException(
                status_code=429,
                detail="Слишком много регистраций с этого устройства. Попробуйте позже.",
            )
        hits.append(now)
        _register_ip[ip] = hits


def guard_auth_form(
    request: Request,
    *,
    website: Optional[str] = None,
    form_started_at: Optional[float | int] = None,
    for_register: bool = False,
    check_timing: bool = True,
) -> None:
    """Общий барьер для register/login/check-phone."""
    assert_honeypot_empty(website)
    if check_timing:
        assert_form_timing(form_started_at)
    if for_register:
        assert_register_ip_allowed(client_ip(request))
