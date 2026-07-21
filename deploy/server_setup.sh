#!/bin/bash
# Полный деплой с нуля на VPS
set -e
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y unzip curl ca-certificates

if [ ! -d /root/backendGreen/main.py ] && [ ! -f /root/backendGreen/main.py ]; then
  rm -rf /root/backendGreen
  mkdir -p /root/backendGreen
  unzip -oq /root/ustobozor-lite.zip -d /root/backendGreen || true
fi

bash /root/server_deploy.sh
