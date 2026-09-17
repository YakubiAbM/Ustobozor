#!/bin/bash
# Ustomarket — деплой через консоль Timeweb (VNC)
# 1) Загрузите ustomarket-backend.zip в /root/ через файловый менеджер Timeweb
# 2) Вставьте в консоль: bash /root/timeweb_console_deploy.sh

set -e
ZIP="/root/ustomarket-backend.zip"
DIR="/root/backendGreen"

echo "=== 1. Docker ==="
if ! command -v docker >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y docker.io docker-compose-v2 unzip curl
  systemctl enable docker
  systemctl start docker
fi

echo "=== 2. Распаковка ==="
if [ ! -f "$ZIP" ]; then
  echo "ОШИБКА: положите файл $ZIP (загрузите через панель Timeweb)"
  exit 1
fi
mkdir -p "$DIR"
unzip -o "$ZIP" -d "$DIR"
cd "$DIR"

echo "=== 3. .env ==="
if [ ! -f .env ]; then
  cp .env.example .env
fi
# Минимум для первого запуска (потом отредактируйте: nano .env)
grep -q '^DEBUG=' .env && sed -i 's/^DEBUG=.*/DEBUG=false/' .env || echo 'DEBUG=false' >> .env
grep -q '^SKIP_MASTER_OTP=' .env && sed -i 's/^SKIP_MASTER_OTP=.*/SKIP_MASTER_OTP=0/' .env || echo 'SKIP_MASTER_OTP=0' >> .env
grep -q '^JWT_SECRET=' .env || echo 'JWT_SECRET=change-me-run-openssl-rand-hex-32' >> .env

echo "=== 4. Запуск Docker ==="
docker compose down 2>/dev/null || true
docker compose up -d --build

echo "=== 5. Ожидание БД (20 сек) ==="
sleep 20

echo "=== 6. Миграции ==="
docker compose exec -T app python migrate_auth.py

echo ""
echo "=== ГОТОВО ==="
docker compose ps
echo ""
echo "Проверка на сервере:"
curl -sS -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8000/web/ || true
IP=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "185.185.142.229")
echo "Сайт:  http://${IP}:8000/web/"
echo "Админ: http://${IP}:8000/admin/"
echo ""
echo "Если с телефона не открывается — в Timeweb откройте порт 8000 в Firewall."
