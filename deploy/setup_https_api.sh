#!/bin/bash
# HTTPS для api.ustomarket.tj (Let's Encrypt + Nginx → uvicorn :8000)
# Запуск на VPS: bash setup_https_api.sh
set -e
export DEBIAN_FRONTEND=noninteractive

DOMAIN="api.ustomarket.tj"
APP_PORT=8000
SERVER_IP="185.185.142.229"

echo "=== 1. DNS check ==="
RESOLVED=$(dig +short "$DOMAIN" @8.8.8.8 | tail -1)
if [ -z "$RESOLVED" ]; then
  echo "ERROR: $DOMAIN не резолвится."
  echo "Добавьте A-запись: api.ustomarket.tj -> $SERVER_IP"
  echo "Подождите 5–30 мин и запустите скрипт снова."
  exit 1
fi
if [ "$RESOLVED" != "$SERVER_IP" ]; then
  echo "WARN: $DOMAIN -> $RESOLVED (ожидался $SERVER_IP)"
fi
echo "DNS OK: $DOMAIN -> $RESOLVED"

echo "=== 2. Nginx + Certbot ==="
apt-get update -qq
apt-get install -y nginx certbot python3-certbot-nginx

mkdir -p /var/www/certbot/.well-known/acme-challenge
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_SRC="$SCRIPT_DIR/nginx-api-ustomarket.conf"
if [ ! -f "$NGINX_SRC" ]; then
  NGINX_SRC="/root/nginx-api-ustomarket.conf"
fi
cp "$NGINX_SRC" /etc/nginx/sites-available/ustomarket
ln -sf /etc/nginx/sites-available/ustomarket /etc/nginx/sites-enabled/ustomarket
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable nginx
systemctl restart nginx

echo "=== 3. SSL certificate ==="
certbot --nginx -d "$DOMAIN" \
  --non-interactive --agree-tos --register-unsafely-without-email --redirect

echo "=== 4. Verify ==="
curl -sS -o /dev/null -w "HTTPS /products: %{http_code}\n" "https://$DOMAIN/products"
curl -sS -o /dev/null -w "HTTPS /web/: %{http_code}\n" "https://$DOMAIN/web/"

echo ""
echo "Готово. API: https://$DOMAIN"
echo "Flutter baseUrl: https://$DOMAIN"
