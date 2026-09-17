#!/bin/bash
# Cloudflare Tunnel → локальный API (uvicorn :8000)
# Быстрый старт: bash cloudflare_tunnel.sh check
# Запуск туннеля: bash cloudflare_tunnel.sh run
# Сервис (автозапуск): bash cloudflare_tunnel.sh install
set -e

APP_URL="http://127.0.0.1:8000"
CF_BIN="/usr/local/bin/cloudflared"
SERVICE_NAME="cloudflared-ustomarket"

cmd_check() {
  echo "=== cloudflared ==="
  if command -v cloudflared >/dev/null 2>&1; then
    cloudflared --version
  else
    echo "НЕ установлен"
  fi
  echo ""
  echo "=== systemd ==="
  systemctl status "$SERVICE_NAME" 2>/dev/null | head -12 || systemctl status cloudflared 2>/dev/null | head -12 || echo "сервис не найден"
  echo ""
  echo "=== конфиги ==="
  ls -la /etc/cloudflared/ 2>/dev/null || echo "/etc/cloudflared/ — нет"
  ls -la ~/.cloudflared/ 2>/dev/null || echo "~/.cloudflared/ — нет"
  echo ""
  echo "=== API локально ==="
  curl -sS -o /dev/null -w "ustomarket :8000 -> %{http_code}\n" "$APP_URL/products" || echo "API не отвечает на :8000"
}

cmd_install_bin() {
  if command -v cloudflared >/dev/null 2>&1; then
    echo "cloudflared уже есть: $(cloudflared --version)"
    return
  fi
  echo "Установка cloudflared..."
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) CF_ARCH=amd64 ;;
    aarch64) CF_ARCH=arm64 ;;
    *) echo "Unsupported arch: $ARCH"; exit 1 ;;
  esac
  curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" -o "$CF_BIN"
  chmod +x "$CF_BIN"
  "$CF_BIN" --version
}

# Одна команда — временный HTTPS URL (*.trycloudflare.com, меняется после перезапуска)
cmd_run() {
  cmd_install_bin
  echo ""
  echo "Запуск туннеля → $APP_URL"
  echo "Скопируйте HTTPS URL из вывода и вставьте в Flutter baseUrl"
  echo "Ctrl+C для остановки"
  echo ""
  exec cloudflared tunnel --url "$APP_URL"
}

# Quick tunnel как systemd-сервис (URL всё равно меняется при каждом рестарте quick tunnel)
cmd_install() {
  cmd_install_bin
  cat > /etc/systemd/system/${SERVICE_NAME}.service << UNIT
[Unit]
Description=Cloudflare Quick Tunnel to Ustomarket API
After=network.target ustomarket.service

[Service]
Type=simple
ExecStart=${CF_BIN} tunnel --url ${APP_URL}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME"
  systemctl restart "$SERVICE_NAME"
  sleep 5
  echo ""
  echo "Лог (ищите trycloudflare.com URL):"
  journalctl -u "$SERVICE_NAME" -n 30 --no-pager
}

case "${1:-check}" in
  check) cmd_check ;;
  install-bin) cmd_install_bin ;;
  run) cmd_run ;;
  install) cmd_install ;;
  *)
    echo "Usage: $0 {check|install-bin|run|install}"
    exit 1
    ;;
esac
