#!/usr/bin/env python3
"""Generate a local gitignored .env.production with strong secrets.

Usage (from UstoMarketBagk/):
  python3 scripts/generate_prod_env.py

Then copy to the VPS as .env:
  scp .env.production root@92.119.185.114:/root/Ustobozor/UstoMarketBagk/.env
"""

from __future__ import annotations

import secrets
import string
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / ".env.production"


def _token(n: int) -> str:
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(n))


def main() -> None:
    pg = _token(28)
    admin_pw = _token(16)
    jwt = secrets.token_hex(32)
    body = f"""# PROD secrets for VPS 92.119.185.114 — DO NOT COMMIT
# Copy to server as .env

POSTGRES_PASSWORD={pg}
DATABASE_URL=postgresql://postgres:{pg}@db:5432/market

SUPERADMIN_PHONE_NORM=987654321
SUPERADMIN_PASSWORD={admin_pw}

SKIP_ADMIN_AUTH=0
DEBUG=false
SKIP_MASTER_OTP=0

REDIS_URL=redis://redis:6379/0
OTP_BACKEND=redis
ALIF_SMS_API_KEY=
OTP_RATE_LIMIT=3
OTP_RATE_WINDOW=900
OTP_TTL_SECONDS=300
OTP_VERIFY_MAX_ATTEMPTS=3
OTP_BLOCK_SECONDS=1800

JWT_SECRET={jwt}

ALLOWED_ORIGINS=https://ustobozor.tj,https://www.ustobozor.tj
PUBLIC_BASE_URL=https://ustobozor.tj
"""
    OUT.write_text(body, encoding="utf-8")
    print(f"Wrote {OUT}")
    print("File is gitignored. Copy to server as .env — do not commit.")


if __name__ == "__main__":
    main()
