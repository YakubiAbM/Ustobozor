#!/bin/bash
set -e
cd /root/backendGreen

if [ ! -f .env ]; then
  JWT=$(openssl rand -hex 32)
  cat > .env << EOF
DATABASE_URL=postgresql://postgres:7900@db:5432/market
SUPERADMIN_PHONE_NORM=986505650
SUPERADMIN_PASSWORD=7900
SKIP_ADMIN_AUTH=0
DEBUG=false
SKIP_MASTER_OTP=0
TELEGRAM_BOT_TOKEN=8353786544:AAFimU0W-xKksDDnULatciYzi9EF0Ri7xVE
TELEGRAM_CHAT_ID=6318017185
TELEGRAM_GATEWAY_TOKEN=AAEBRAAAT-wjiT6h6xcSE7z58NjmKyFkdL9h8NSDwS5KTg
REDIS_URL=redis://redis:6379/0
OTP_BACKEND=redis
OTP_RATE_LIMIT=3
OTP_RATE_WINDOW=900
OTP_TTL_SECONDS=300
OTP_VERIFY_MAX_ATTEMPTS=3
OTP_BLOCK_SECONDS=1800
ALIF_SMS_API_KEY=LOCAL_STUB_NO_CONTRACT
JWT_SECRET=${JWT}
EOF
  echo "Created .env"
fi

docker compose down 2>/dev/null || true
docker compose up -d --build
echo "Waiting 35s for DB..."
sleep 35
docker compose exec -T app python migrate_auth.py
docker compose ps
curl -sS -o /dev/null -w "Web: HTTP %{http_code}\n" http://127.0.0.1:8000/web/ || true
echo "Done: http://185.185.142.229:8000/web/"
