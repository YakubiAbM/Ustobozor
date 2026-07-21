"""
Хранение OTP-сессий (memory или Redis) и проверка кодов.
"""

from __future__ import annotations

import hashlib
import random
import threading
import time
from typing import Optional, Tuple

from config import (
    OTP_BACKEND,
    OTP_BLOCK_SECONDS,
    OTP_MAX_ATTEMPTS,
    OTP_RATE_LIMIT,
    OTP_RATE_WINDOW,
    OTP_TTL_SECONDS,
    OTP_VERIFY_MAX_ATTEMPTS,
    REDIS_URL,
)

_lock = threading.Lock()
_memory_store: dict[str, dict] = {}
_rate_store: dict[str, list[float]] = {}
_redis = None


def _get_redis():
    global _redis
    if _redis is not None:
        return _redis
    if OTP_BACKEND in ("redis", "auto"):
        try:
            import redis

            _redis = redis.from_url(REDIS_URL, decode_responses=True)
            _redis.ping()
            return _redis
        except Exception:
            if OTP_BACKEND == "redis":
                return None
    return None


def is_otp_store_ready() -> bool:
    if OTP_BACKEND == "memory":
        return True
    if OTP_BACKEND == "redis":
        return _get_redis() is not None
    return True  # auto: fallback to memory


def normalize_phone_intl(phone_raw: str) -> str:
    digits = "".join(c for c in (phone_raw or "") if c.isdigit())
    if len(digits) < 9:
        raise ValueError("Invalid phone number")
    if digits.startswith("992"):
        return f"+{digits}"
    if len(digits) == 9:
        return f"+992{digits}"
    return f"+{digits}"


def phone_norm_from_intl(phone_intl: str) -> str:
    digits = "".join(c for c in phone_intl if c.isdigit())
    return digits[-9:] if len(digits) >= 9 else digits


def generate_code(length: int = 4) -> str:
    return "".join(str(random.randint(0, 9)) for _ in range(length))


def _key(phone_intl: str) -> str:
    return f"otp:{phone_intl}"


def _hash_code(code: str) -> str:
    return hashlib.sha256(code.strip().encode()).hexdigest()


def save_otp(phone_intl: str, channel: str, *, code: str | None = None, request_id: str | None = None) -> None:
    payload = {
        "channel": channel,
        "code_hash": _hash_code(code) if code else None,
        "request_id": request_id,
        "created_at": int(time.time()),
        "attempts": 0,
        "blocked_until": 0,
    }
    r = _get_redis()
    if r:
        r.setex(_key(phone_intl), OTP_TTL_SECONDS, __import__("json").dumps(payload))
        return
    with _lock:
        _memory_store[phone_intl] = payload


def _load_otp(phone_intl: str) -> Optional[dict]:
    r = _get_redis()
    if r:
        raw = r.get(_key(phone_intl))
        if not raw:
            return None
        return __import__("json").loads(raw)
    with _lock:
        return dict(_memory_store.get(phone_intl) or {}) or None


def _save_otp_state(phone_intl: str, state: dict) -> None:
    r = _get_redis()
    if r:
        ttl = max(1, OTP_TTL_SECONDS - (int(time.time()) - int(state.get("created_at", 0))))
        r.setex(_key(phone_intl), ttl, __import__("json").dumps(state))
        return
    with _lock:
        _memory_store[phone_intl] = state


def check_rate_limit(phone_intl: str) -> bool:
    now = time.time()
    window_start = now - OTP_RATE_WINDOW
    with _lock:
        hits = [t for t in _rate_store.get(phone_intl, []) if t >= window_start]
        _rate_store[phone_intl] = hits
        return len(hits) < OTP_RATE_LIMIT


def increment_rate_limit(phone_intl: str) -> None:
    with _lock:
        _rate_store.setdefault(phone_intl, []).append(time.time())


def is_phone_blocked(phone_intl: str) -> bool:
    state = _load_otp(phone_intl)
    if not state:
        return False
    blocked_until = int(state.get("blocked_until") or 0)
    return blocked_until > int(time.time())


def block_message_for_phone(phone_intl: str) -> str:
    state = _load_otp(phone_intl) or {}
    blocked_until = int(state.get("blocked_until") or 0)
    wait = max(0, blocked_until - int(time.time()))
    minutes = max(1, wait // 60)
    return f"Номер временно заблокирован. Попробуйте через {minutes} мин."


def verify_otp_code(phone_intl: str, code: str) -> Tuple[bool, str, int]:
    """
    Returns: (ok, message, remaining_attempts)
    """
    state = _load_otp(phone_intl)
    if not state:
        return False, "Код не запрашивался или истёк. Запросите новый код.", 0

    now = int(time.time())
    if int(state.get("blocked_until") or 0) > now:
        return False, block_message_for_phone(phone_intl), 0

    if now - int(state.get("created_at", 0)) > OTP_TTL_SECONDS:
        return False, "Срок действия кода истёк. Запросите новый код.", 0

    channel = state.get("channel") or "sms"
    ok = False

    if channel == "tg" and state.get("request_id"):
        from services.telegram_gateway import TelegramGatewayError, check_verification_status

        try:
            ok = check_verification_status(state["request_id"], code)
        except TelegramGatewayError as exc:
            ok = False
            msg = str(exc)
            attempts = int(state.get("attempts") or 0) + 1
            state["attempts"] = attempts
            if attempts >= OTP_VERIFY_MAX_ATTEMPTS:
                state["blocked_until"] = now + OTP_BLOCK_SECONDS
                _save_otp_state(phone_intl, state)
                return False, "Превышено число попыток. Номер временно заблокирован.", 0
            _save_otp_state(phone_intl, state)
            remaining = max(0, OTP_VERIFY_MAX_ATTEMPTS - attempts)
            return False, msg or "Неверный код", remaining
    else:
        ok = state.get("code_hash") == _hash_code(code)

    if ok:
        r = _get_redis()
        if r:
            r.delete(_key(phone_intl))
        else:
            with _lock:
                _memory_store.pop(phone_intl, None)
        return True, "OK", OTP_VERIFY_MAX_ATTEMPTS

    attempts = int(state.get("attempts") or 0) + 1
    state["attempts"] = attempts
    if attempts >= OTP_VERIFY_MAX_ATTEMPTS:
        state["blocked_until"] = now + OTP_BLOCK_SECONDS
        _save_otp_state(phone_intl, state)
        return False, "Превышено число попыток. Номер временно заблокирован.", 0

    _save_otp_state(phone_intl, state)
    remaining = max(0, OTP_VERIFY_MAX_ATTEMPTS - attempts)
    return False, "Неверный код", remaining


def cleanup_expired_otp() -> int:
    """Удаляет просроченные OTP из memory store."""
    now = int(time.time())
    removed = 0
    with _lock:
        expired = [
            phone
            for phone, state in _memory_store.items()
            if now - int(state.get("created_at", 0)) > OTP_TTL_SECONDS + 60
        ]
        for phone in expired:
            _memory_store.pop(phone, None)
            removed += 1
        # rate limit windows
        for phone in list(_rate_store.keys()):
            _rate_store[phone] = [t for t in _rate_store[phone] if t >= now - OTP_RATE_WINDOW]
            if not _rate_store[phone]:
                _rate_store.pop(phone, None)
    return removed
