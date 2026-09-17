#!/usr/bin/env bash
# Hardening VPS after deploy. Run on server as ubuntu (with sudo):
#   sudo bash /home/ubuntu/Ustomarket/deploy/harden_server.sh
set -euo pipefail

ENV_FILE="${ENV_FILE:-/home/ubuntu/Ustomarket/UstoMarketBagk/.env}"

echo "=== .env permissions ==="
if [[ -f "$ENV_FILE" ]]; then
  chmod 600 "$ENV_FILE"
  chown ubuntu:ubuntu "$ENV_FILE"
  stat -c "%a %U:%G %n" "$ENV_FILE"
else
  echo "WARN: $ENV_FILE not found"
fi

echo "=== UFW: only SSH, HTTP, HTTPS (close 8000) ==="
ufw delete allow 8000/tcp 2>/dev/null || true
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
ufw status

echo "=== SSH: disable password login (keys only) ==="
SSHD=/etc/ssh/sshd_config
if grep -q '^PasswordAuthentication' "$SSHD"; then
  sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD"
else
  echo 'PasswordAuthentication no' >> "$SSHD"
fi
if grep -q '^PermitRootLogin' "$SSHD"; then
  sed -i 's/^PermitRootLogin.*/PermitRootLogin prohibit-password/' "$SSHD"
else
  echo 'PermitRootLogin prohibit-password' >> "$SSHD"
fi
systemctl reload ssh || systemctl reload sshd

echo "=== Done. API only via nginx :80/:443 ==="
