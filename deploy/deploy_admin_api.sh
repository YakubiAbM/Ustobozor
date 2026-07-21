#!/usr/bin/env bash
# Деплой Admin Mobile API на prod VPS
set -euo pipefail

SERVER="root@185.185.142.229"
REMOTE_DIR="/root/backendGreen"
LOCAL_BAGK="$(cd "$(dirname "$0")/../UstoMarketBagk" && pwd)"

echo "==> Upload admin_mobile_api.py + main.py"
scp -o ConnectTimeout=30 \
  "$LOCAL_BAGK/admin_mobile_api.py" \
  "$LOCAL_BAGK/main.py" \
  "$SERVER:$REMOTE_DIR/"

echo "==> Restart ustobozor"
ssh -o ConnectTimeout=30 "$SERVER" "systemctl restart ustobozor && sleep 2 && systemctl is-active ustobozor"

echo "==> Verify API"
ssh -o ConnectTimeout=30 "$SERVER" "curl -sS -o /dev/null -w 'local:%{http_code}\n' http://127.0.0.1:8000/products"

echo "Done. Admin API: /admin/api/dashboard (401 without login — OK)"
