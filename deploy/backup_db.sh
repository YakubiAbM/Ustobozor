#!/usr/bin/env bash
# Daily Postgres backup from Docker. Install cron on VPS:
#   0 3 * * * /home/ubuntu/Ustobozor/deploy/backup_db.sh >> /var/log/ustobozor-backup.log 2>&1
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/home/ubuntu/backups/ustobozor}"
COMPOSE_FILE="${COMPOSE_FILE:-/home/ubuntu/Ustobozor/UstoMarketBagk/docker-compose.yml}"
KEEP_DAYS="${KEEP_DAYS:-14}"

mkdir -p "$BACKUP_DIR"
STAMP=$(date +%Y%m%d_%H%M%S)
OUT="$BACKUP_DIR/market_${STAMP}.sql.gz"

docker compose -f "$COMPOSE_FILE" exec -T db pg_dump -U postgres market | gzip > "$OUT"
find "$BACKUP_DIR" -name 'market_*.sql.gz' -mtime +"$KEEP_DAYS" -delete
echo "$(date -Is) backup OK: $OUT"
