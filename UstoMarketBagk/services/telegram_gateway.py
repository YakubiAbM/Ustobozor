"""Telegram Gateway API: отправка и проверка OTP-кода."""

from __future__ import annotations

import httpx

from config import TELEGRAM_GATEWAY_TOKEN, TELEGRAM_GATEWAY_TTL


class TelegramGatewayError(Exception):
    def __init__(self, message: str, *, description: str = "", no_balance: bool = False, flood_wait: bool = False):
        super().__init__(message)
        self.description = description
        self.no_balance = no_balance
        self.flood_wait = flood_wait


def _headers() -> dict:
    if not TELEGRAM_GATEWAY_TOKEN:
        raise TelegramGatewayError("TELEGRAM_GATEWAY_TOKEN не задан")
    return {
        "Authorization": f"Bearer {TELEGRAM_GATEWAY_TOKEN}",
        "Content-Type": "application/json",
    }


def _post(path: str, payload: dict) -> dict:
    url = f"https://gatewayapi.telegram.org/{path}"
    try:
        with httpx.Client(timeout=20) as client:
            resp = client.post(url, json=payload, headers=_headers())
    except httpx.HTTPError as exc:
        raise TelegramGatewayError(f"Telegram Gateway недоступен: {exc}") from exc

    try:
        data = resp.json()
    except Exception as exc:
        raise TelegramGatewayError(f"Некорректный ответ Gateway: {resp.text[:200]}") from exc

    if resp.status_code == 429:
        raise TelegramGatewayError("Flood wait", flood_wait=True, description=data.get("error", ""))

    if not data.get("ok"):
        err = data.get("error", "") or str(data)
        low = err.lower()
        no_balance = "balance" in low or "insufficient" in low
        raise TelegramGatewayError(err or "Gateway error", description=err, no_balance=no_balance)

    return data.get("result") or {}


def send_verification_message(phone_intl: str) -> dict:
    """checkSendAbility + sendVerificationMessage. Возвращает request_id."""
    ability = _post("checkSendAbility", {"phone_number": phone_intl})
    request_id = ability.get("request_id")
    if not request_id:
        raise TelegramGatewayError("Gateway не вернул request_id")

    _post(
        "sendVerificationMessage",
        {
            "phone_number": phone_intl,
            "code_length": 4,
            "ttl": TELEGRAM_GATEWAY_TTL,
            "request_id": request_id,
        },
    )
    return {"status": "sent", "request_id": request_id, "retry_after": 60}


def check_verification_status(request_id: str, code: str) -> bool:
    """Проверка кода через Telegram Gateway."""
    result = _post(
        "checkVerificationStatus",
        {"request_id": request_id, "code": code.strip()},
    )
    status = (result.get("verification_status") or result.get("status") or "").lower()
    return status in ("code_valid", "valid", "verified", "success")
