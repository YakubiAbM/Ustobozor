#!/bin/bash
# Деплой БЕЗ загрузки файлов с ПК — только консоль Timeweb
# Вставьте целиком в VNC-консоль

set -e
DIR="/root/backendGreen"
REPO="https://github.com/YakubiAbM/backendGreen.git"

echo "=== Установка Docker + Git ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y git docker.io docker-compose-v2 curl unzip ca-certificates
systemctl enable docker 2>/dev/null || true
systemctl start docker 2>/dev/null || true

echo "=== Скачивание кода с GitHub ==="
rm -rf "$DIR"
if git clone --depth 1 "$REPO" "$DIR"; then
  echo "Git clone OK"
else
  echo "Git не сработал — пробуем zip с GitHub (архив)..."
  rm -rf "$DIR" /tmp/bg.zip
  curl -fsSL -o /tmp/bg.zip "https://github.com/YakubiAbM/backendGreen/archive/refs/heads/main.zip" \
    || curl -fsSL -o /tmp/bg.zip "https://github.com/YakubiAbM/backendGreen/archive/refs/heads/master.zip"
  unzip -q /tmp/bg.zip -d /tmp
  mv /tmp/backendGreen-main "$DIR" 2>/dev/null || mv /tmp/backendGreen-master "$DIR"
fi

cd "$DIR"
echo "=== .env ==="
cp -n .env.example .env 2>/dev/null || true
grep -q '^DEBUG=' .env && sed -i 's/^DEBUG=.*/DEBUG=false/' .env || echo 'DEBUG=false' >> .env
grep -q '^SKIP_MASTER_OTP=' .env && sed -i 's/^SKIP_MASTER_OTP=.*/SKIP_MASTER_OTP=0/' .env || echo 'SKIP_MASTER_OTP=0' >> .env
grep -q '^JWT_SECRET=' .env || echo "JWT_SECRET=$(openssl rand -hex 32 2>/dev/null || echo change-me-secret)" >> .env

echo "=== Docker ==="
docker compose down 2>/dev/null || true
docker compose up -d --build
echo "Ждём 25 сек..."
sleep 25
docker compose exec -T app python migrate_auth.py

echo ""
echo "=== ГОТОВО ==="
docker compose ps
curl -sS -o /dev/null -w "Web: HTTP %{http_code}\n" http://127.0.0.1:8000/web/ || true
echo "Откройте: http://185.185.142.229:8000/web/"
echo "Firewall Timeweb: откройте TCP 8000 если снаружи не открывается"
