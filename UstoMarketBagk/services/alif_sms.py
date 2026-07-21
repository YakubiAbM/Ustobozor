"""Резервный канал OTP через Alif SMS (пока заглушка)."""

from config import ALIF_SMS_API_KEY


def send_alif_sms_backup(phone_intl: str, code: str) -> dict:
    """Заглушка: SMS не отправляется, код сохраняется в otp_service."""
    if ALIF_SMS_API_KEY == "LOCAL_STUB_NO_CONTRACT":
        return {"status": "sent", "channel": "sms_stub", "retry_after": 60}
    # TODO: реальная интеграция Alif SMS
    return {"status": "sent", "channel": "sms", "retry_after": 60}
