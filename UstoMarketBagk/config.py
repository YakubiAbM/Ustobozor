"""
Конфигурация приложения из переменных окружения.
Секреты и настройки читаются из os.environ (рекомендуется .env через python-dotenv).
"""

import os
from pathlib import Path
from typing import List

try:
    from dotenv import load_dotenv
    # Всегда грузить .env из папки проекта (где лежит config.py), а не из текущей директории
    _env_path = Path(__file__).resolve().parent / ".env"
    load_dotenv(_env_path)
except ImportError:
    pass


def _env_bool(key: str, default: bool = False) -> bool:
    """Читает булево значение из env (1/true/yes)."""
    v = os.getenv(key, "").strip().lower()
    return v in ("1", "true", "yes") if v else default


def _env_int(key: str, default: int) -> int:
    """Читает целое число из env; при ошибке возвращает default."""
    try:
        return int(os.getenv(key, str(default)))
    except ValueError:
        return default


# -----------------------------------------------------------------------------
# База данных
# -----------------------------------------------------------------------------
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./market.db")
USE_SQLITE = "sqlite" in DATABASE_URL

# -----------------------------------------------------------------------------
# JWT (access / refresh токены)
# -----------------------------------------------------------------------------
JWT_SECRET = os.getenv("JWT_SECRET", "change-me-in-production-use-long-secret")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
# Access: короткий (15–30 мин). Refresh: длиннее, хранится в БД/Redis.
ACCESS_TOKEN_TTL_MINUTES = _env_int("ACCESS_TOKEN_TTL_MINUTES", 30)
REFRESH_TOKEN_TTL_DAYS = _env_int("REFRESH_TOKEN_TTL_DAYS", 30)

# -----------------------------------------------------------------------------
# OTP (одноразовые коды входа)
# -----------------------------------------------------------------------------
OTP_TTL_SECONDS = _env_int("OTP_TTL_SECONDS", 300)
OTP_MAX_ATTEMPTS = _env_int("OTP_MAX_ATTEMPTS", 5)
OTP_BLOCK_SECONDS = _env_int("OTP_BLOCK_SECONDS", 1800)
OTP_RATE_LIMIT = _env_int("OTP_RATE_LIMIT", 3)
OTP_RATE_WINDOW = _env_int("OTP_RATE_WINDOW", 900)
OTP_VERIFY_MAX_ATTEMPTS = _env_int("OTP_VERIFY_MAX_ATTEMPTS", 3)

# -----------------------------------------------------------------------------
# Redis (OTP-сессии v1 auth)
# -----------------------------------------------------------------------------
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0").strip()
# memory (default dev) | redis (prod) | auto
OTP_BACKEND = os.getenv("OTP_BACKEND", "memory").strip().lower()

# -----------------------------------------------------------------------------
# Alif SMS (OTP мастерам; пока заглушка без реального контракта)
# -----------------------------------------------------------------------------
ALIF_SMS_API_KEY = os.getenv("ALIF_SMS_API_KEY", "LOCAL_STUB_NO_CONTRACT").strip()

# -----------------------------------------------------------------------------
# Приложение
# -----------------------------------------------------------------------------
DEBUG = _env_bool("DEBUG", False)
# Только dev: вход мастера без OTP (POST /auth/dev-login). На prod = 0
SKIP_MASTER_OTP = _env_bool("SKIP_MASTER_OTP", False)


def _norm_phone_for_env(s: str) -> str:
    """Последние 9 цифр из строки (как в auth.normalize_phone), чтобы в .env можно было писать +992986505650 или 986505650."""
    digits = "".join(c for c in (s or "") if c.isdigit())
    return digits[-9:] if len(digits) >= 9 else digits


# Супер-админ: вход по логину (номер) и паролю из .env.
# Пример: SUPERADMIN_PHONE_NORM=987654321, SUPERADMIN_PASSWORD=1221
SUPERADMIN_PHONE_NORM = _norm_phone_for_env(os.getenv("SUPERADMIN_PHONE_NORM", "").strip())
SUPERADMIN_PASSWORD = os.getenv("SUPERADMIN_PASSWORD", "").strip()

# Для теста: если 1/true — в админку можно зайти без логина (считается супер-админ).
SKIP_ADMIN_AUTH = _env_bool("SKIP_ADMIN_AUTH", False)

# Программа баллов мастеров (временно отключена; MASTER_POINTS_ENABLED=1 чтобы включить).
MASTER_POINTS_ENABLED = _env_bool("MASTER_POINTS_ENABLED", False)

# -----------------------------------------------------------------------------
# CORS (разрешённые origins для браузера)
# -----------------------------------------------------------------------------
ALLOWED_ORIGINS_STR = os.getenv("ALLOWED_ORIGINS", "")
ALLOWED_ORIGINS: List[str] = [o.strip() for o in ALLOWED_ORIGINS_STR.split(",") if o.strip()]
CORS_ALLOW_ALL = len(ALLOWED_ORIGINS) == 0 and DEBUG

# -----------------------------------------------------------------------------
# Trusted hosts (опционально для production)
# -----------------------------------------------------------------------------
TRUSTED_HOSTS_STR = os.getenv("TRUSTED_HOSTS", "")
TRUSTED_HOSTS: List[str] = [h.strip() for h in TRUSTED_HOSTS_STR.split(",") if h.strip()]


# -----------------------------------------------------------------------------
# Push-уведомления (Firebase Cloud Messaging)
# -----------------------------------------------------------------------------
# Legacy (если включён в Firebase): key=AAAA...
FCM_SERVER_KEY = os.getenv("FCM_SERVER_KEY", "").strip()
# HTTP v1: путь к JSON сервис-аккаунта (Firebase Console → Service accounts → Generate new private key)
FCM_SERVICE_ACCOUNT_PATH = os.getenv("FCM_SERVICE_ACCOUNT_PATH", "").strip()

# -----------------------------------------------------------------------------
# PWA: ссылка на поддержку в WhatsApp (номер без +, например 992123456789)
# -----------------------------------------------------------------------------
SUPPORT_WHATSAPP = os.getenv("SUPPORT_WHATSAPP", "992").strip() or "992"
