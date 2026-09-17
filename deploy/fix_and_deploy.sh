#!/bin/bash
# Deploy without Docker Hub: Postgres + Redis via apt, app only in Docker
set -e
export DEBIAN_FRONTEND=noninteractive

cd /root/backendGreen

echo "=== 1. Postgres + Redis (apt) ==="
apt-get update -qq
apt-get install -y postgresql postgresql-contrib redis-server

systemctl enable postgresql redis-server
systemctl start postgresql redis-server

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='market'" | grep -q 1 \
  || sudo -u postgres psql -c "CREATE DATABASE market;"
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '7900';" 2>/dev/null || true

echo "=== 2. docker-compose (app only) ==="
cat > /root/backendGreen/docker-compose.yml << 'COMPOSE'
services:
  app:
    build: .
    container_name: ustomarket-app
    network_mode: host
    env_file:
      - .env
    environment:
      - DATABASE_URL=postgresql://postgres:7900@127.0.0.1:5432/market
      - REDIS_URL=redis://127.0.0.1:6379/0
      - OTP_BACKEND=redis
    volumes:
      - ./static:/app/static
      - ./web:/app/web
    restart: always
COMPOSE

if [ ! -f .env ]; then
  echo "ERROR: create .env first (nano .env)"
  exit 1
fi

echo "=== 3. Build app (no postgres/redis pull) ==="
docker compose down 2>/dev/null || true
docker compose up -d --build

echo "=== 4. Migrations ==="
sleep 10
docker compose exec -T app python migrate_auth.py

echo "=== 5. Status ==="
docker compose ps
curl -sS -o /dev/null -w "Web HTTP: %{http_code}\n" http://127.0.0.1:8000/web/ || true
echo "Done: http://185.185.142.229:8000/web/"
