#!/usr/bin/env bash
set -Eeuo pipefail
APP_DIR="${ENSPY_DIR:-/opt/enspy}"
BACKUP_DIR="${ENSPY_BACKUP_DIR:-/opt/enspy-backups}"
mkdir -p "$BACKUP_DIR"
cd "$APP_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
DB_CONTAINER="$(docker compose ps -q postgres)"
[[ -n "$DB_CONTAINER" ]] || { echo "Conteneur PostgreSQL introuvable."; exit 1; }

DB_NAME="${POSTGRES_DB:-enspy}"
DB_USER="${POSTGRES_USER:-enspy}"
OUT="$BACKUP_DIR/enspy_${TS}.sql.gz"

docker exec "$DB_CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$OUT"
chmod 600 "$OUT"
echo "Backup créé: $OUT"
