#!/bin/bash
# Native deploy: Postgres + Redis via apt, FastAPI via venv (no Docker Hub)
set -e
export DEBIAN_FRONTEND=noninteractive

cd /root/backendGreen

echo "=== 1. System packages ==="
apt-get update -qq
apt-get install -y python3 python3-venv python3-pip build-essential libpq-dev \
  postgresql postgresql-contrib redis-server

systemctl enable postgresql redis-server
systemctl start postgresql redis-server

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='market'" | grep -q 1 \
  || sudo -u postgres psql -c "CREATE DATABASE market;"
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '7900';" 2>/dev/null || true

echo "=== 2. Python venv ==="
python3 -m venv venv
./venv/bin/pip install --upgrade pip
./venv/bin/pip install -r requirements.txt

if [ ! -f .env ]; then
  echo "ERROR: create .env first"
  exit 1
fi

# Ensure localhost URLs for native mode
grep -q '^DATABASE_URL=' .env && sed -i 's|^DATABASE_URL=.*|DATABASE_URL=postgresql://postgres:7900@127.0.0.1:5432/market|' .env || \
  echo 'DATABASE_URL=postgresql://postgres:7900@127.0.0.1:5432/market' >> .env
grep -q '^REDIS_URL=' .env && sed -i 's|^REDIS_URL=.*|REDIS_URL=redis://127.0.0.1:6379/0|' .env || \
  echo 'REDIS_URL=redis://127.0.0.1:6379/0' >> .env
grep -q '^OTP_BACKEND=' .env && sed -i 's|^OTP_BACKEND=.*|OTP_BACKEND=redis|' .env || \
  echo 'OTP_BACKEND=redis' >> .env

echo "=== 3. Migrations ==="
./venv/bin/python migrate_auth.py

echo "=== 4. systemd service ==="
cat > /etc/systemd/system/ustobozor.service << 'UNIT'
[Unit]
Description=Ustobozor FastAPI
After=network.target postgresql.service redis-server.service

[Service]
Type=simple
User=root
WorkingDirectory=/root/backendGreen
EnvironmentFile=/root/backendGreen/.env
ExecStart=/root/backendGreen/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable ustobozor
systemctl restart ustobozor

sleep 3
systemctl is-active ustobozor
curl -sS -o /dev/null -w "Web HTTP: %{http_code}\n" http://127.0.0.1:8000/web/ || true
echo "Done: http://185.185.142.229:8000/web/"
