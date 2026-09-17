#!/usr/bin/env bash
# Run on VPS after DNS A records point to this server:
#   sudo bash /home/ubuntu/Ustomarket/deploy/enable_https.sh
set -euo pipefail

DOMAIN=ustobozor.tj
EMAIL="${CERTBOT_EMAIL:-admin@ustobozor.tj}"

apt-get update -qq
apt-get install -y certbot python3-certbot-nginx

certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" \
  --non-interactive --agree-tos -m "$EMAIL" --redirect

nginx -t
systemctl reload nginx
echo "HTTPS OK: https://$DOMAIN"
