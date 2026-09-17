#!/usr/bin/env bash
# Минимальное восстановление Ustomarket (вставить в консоль Timeweb)
set -e
cd /root/backendGreen || { echo "Нет /root/backendGreen"; ls /root; exit 1; }
systemctl start postgresql redis-server 2>/dev/null || true
docker compose down 2>/dev/null || true
docker compose up -d --build
sleep 25
curl -s --max-time 8 http://127.0.0.1:8000/products?limit=1 | head -c 120 || exit 1
echo ""
C=/etc/letsencrypt/live/ustobozor.tj/fullchain.pem
K=/etc/letsencrypt/live/ustobozor.tj/privkey.pem
[[ -f $C ]] || C=/etc/ssl/certs/ustomarket-selfsigned.crt
[[ -f $K ]] || K=/etc/ssl/private/ustomarket-selfsigned.key
[[ -f $C ]] || { mkdir -p /etc/ssl/private; openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/ustomarket-selfsigned.key -out /etc/ssl/certs/ustomarket-selfsigned.crt -subj /CN=ustobozor.tj; C=/etc/ssl/certs/ustomarket-selfsigned.crt; K=/etc/ssl/private/ustomarket-selfsigned.key; }
cat > /etc/nginx/sites-available/ustomarket << EOF
upstream ustomarket_app { server 127.0.0.1:8000; }
server {
    listen 80; listen [::]:80;
    server_name ustobozor.tj www.ustobozor.tj 185.185.142.229;
    client_max_body_size 50M;
    location / { proxy_pass http://ustomarket_app; proxy_set_header Host \$host; proxy_set_header X-Forwarded-Proto \$scheme; }
}
server {
    listen 443 ssl; listen [::]:443 ssl;
    server_name ustobozor.tj www.ustobozor.tj 185.185.142.229;
    ssl_certificate $C; ssl_certificate_key $K;
    client_max_body_size 50M;
    location / { proxy_pass http://ustomarket_app; proxy_set_header Host \$host; proxy_set_header X-Forwarded-Proto \$scheme; }
}
EOF
ln -sf /etc/nginx/sites-available/ustomarket /etc/nginx/sites-enabled/ustomarket
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx
curl -sI --max-time 10 https://ustobozor.tj/products?limit=1 | head -3
echo DONE
