#!/usr/bin/env bash
# Восстановление Ustomarket: backend :8000 + nginx → proxy
set -euo pipefail

APP_DIR="${APP_DIR:-/root/backendGreen}"
DOMAIN="ustobozor.tj"
NGINX_SITE="/etc/nginx/sites-available/ustomarket"

log() { echo "==> $*"; }

log "1. Диагностика"
echo "--- listeners ---"
ss -tlnp | grep -E ':80|:443|:8000|:22' || true
echo "--- docker ---"
docker ps -a 2>/dev/null || echo "docker недоступен"
echo "--- ustomarket service ---"
systemctl is-active ustomarket 2>/dev/null || echo "ustomarket service: inactive/missing"
echo "--- local API ---"
curl -sS --max-time 5 -o /dev/null -w "127.0.0.1:8000 -> %{http_code}\n" "http://127.0.0.1:8000/products?limit=1" || echo "127.0.0.1:8000 -> FAIL"

log "2. Postgres + Redis"
export DEBIAN_FRONTEND=noninteractive
systemctl enable postgresql redis-server 2>/dev/null || true
systemctl start postgresql redis-server 2>/dev/null || true

log "3. Backend (Docker или systemd)"
if [[ -d "$APP_DIR" ]]; then
  cd "$APP_DIR"
  if [[ -f docker-compose.yml ]] && command -v docker >/dev/null 2>&1; then
    docker compose down 2>/dev/null || true
    docker compose up -d --build
    log "Ждём запуск контейнера (25с)..."
    sleep 25
    docker compose ps || true
    docker compose logs app --tail 20 2>/dev/null || true
  elif systemctl list-unit-files | grep -q ustomarket.service; then
    systemctl restart ustomarket
    sleep 3
    systemctl status ustomarket --no-pager | head -15 || true
  else
    echo "WARN: ни docker compose, ни ustomarket.service не найдены в $APP_DIR"
  fi
else
  echo "ERROR: $APP_DIR не существует"
  ls -la /root/ || true
fi

log "4. Проверка backend после перезапуска"
for i in 1 2 3 4 5; do
  if curl -sS --max-time 5 -o /dev/null -w "" "http://127.0.0.1:8000/products?limit=1"; then
    echo "Backend OK на попытке $i"
    break
  fi
  echo "Попытка $i/5 — backend ещё не отвечает, ждём 5с..."
  sleep 5
done
curl -sS --max-time 8 "http://127.0.0.1:8000/products?limit=1" | head -c 120 || {
  echo "ERROR: backend на :8000 не отвечает — смотрите docker compose logs / journalctl -u ustomarket"
  exit 1
}
echo ""

log "5. SSL-сертификат для nginx"
SSL_CERT=""
SSL_KEY=""
for pair in \
  "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem /etc/letsencrypt/live/${DOMAIN}/privkey.pem" \
  "/etc/ssl/${DOMAIN}/fullchain.pem /etc/ssl/${DOMAIN}/privkey.pem" \
  "/etc/ssl/certs/ustomarket-selfsigned.crt /etc/ssl/private/ustomarket-selfsigned.key"; do
  read -r c k <<< "$pair"
  if [[ -f "$c" && -f "$k" ]]; then
    SSL_CERT="$c"
    SSL_KEY="$k"
    break
  fi
done

if [[ -z "$SSL_CERT" ]]; then
  log "Сертификат не найден — создаём self-signed"
  mkdir -p /etc/ssl/private
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/ustomarket-selfsigned.key \
    -out /etc/ssl/certs/ustomarket-selfsigned.crt \
    -subj "/CN=${DOMAIN}"
  SSL_CERT="/etc/ssl/certs/ustomarket-selfsigned.crt"
  SSL_KEY="/etc/ssl/private/ustomarket-selfsigned.key"
fi
echo "SSL: $SSL_CERT"

log "6. Nginx — proxy на :8000"
mkdir -p /var/www/certbot/.well-known/acme-challenge
cat > "$NGINX_SITE" << NGINX
upstream ustomarket_app {
    server 127.0.0.1:8000;
    keepalive 16;
}

server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN} 185.185.142.229;

    client_max_body_size 50M;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }

    location / {
        proxy_pass http://ustomarket_app;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120s;
        proxy_connect_timeout 30s;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name ${DOMAIN} www.${DOMAIN} 185.185.142.229;

    ssl_certificate     ${SSL_CERT};
    ssl_certificate_key ${SSL_KEY};
    ssl_protocols TLSv1.2 TLSv1.3;

    client_max_body_size 50M;

    location / {
        proxy_pass http://ustomarket_app;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120s;
        proxy_connect_timeout 30s;
    }
}
NGINX

ln -sf "$NGINX_SITE" /etc/nginx/sites-enabled/ustomarket
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

nginx -t
systemctl enable nginx
systemctl restart nginx

log "7. Финальная проверка"
curl -sS --max-time 10 -o /dev/null -w "HTTP  :8000/products -> %{http_code}\n" "http://127.0.0.1:8000/products?limit=1"
curl -sS --max-time 10 -o /dev/null -w "HTTPS ${DOMAIN}/products -> %{http_code}\n" "https://${DOMAIN}/products?limit=1" || true
curl -sS --max-time 10 "http://127.0.0.1:8000/products?limit=1" | head -c 150
echo ""
echo ""
echo "Готово. Откройте https://${DOMAIN}/products в браузере телефона."
