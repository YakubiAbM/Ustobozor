"""Фоновая очистка просроченных OTP (in-memory backend)."""

import threading
import time

from config import OTP_BACKEND
from services.otp_service import cleanup_expired_otp


def start_otp_cleanup_background(interval_seconds: int = 120) -> None:
    if OTP_BACKEND == "redis":
        return

    def _loop():
        while True:
            time.sleep(interval_seconds)
            try:
                cleanup_expired_otp()
            except Exception:
                pass

    t = threading.Thread(target=_loop, name="otp-cleanup", daemon=True)
    t.start()
