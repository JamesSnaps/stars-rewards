#!/usr/bin/env bash
# Restore a Supabase dump into the local Dockerised Postgres, then apply the
# PostgREST grants. Run AFTER `docker compose up -d stars-db`.
#
# Usage:
#   ./scripts/2-restore-local.sh stars-backup-YYYYMMDD-HHMMSS.dump
set -euo pipefail

DUMP="${1:?Usage: $0 <backup.dump>}"
[ -f "$DUMP" ] || { echo "File not found: $DUMP" >&2; exit 1; }

CONTAINER="$(docker compose ps -q stars-db)"
[ -n "$CONTAINER" ] || { echo "stars-db is not running. Run: docker compose up -d stars-db" >&2; exit 1; }

echo "Waiting for Postgres to be ready..."
until docker exec "$CONTAINER" pg_isready -U stars -d stars >/dev/null 2>&1; do sleep 1; done

echo "Restoring ${DUMP} into stars database..."
docker exec -i "$CONTAINER" pg_restore \
  --no-owner --no-acl \
  --username stars --dbname stars \
  < "$DUMP"

echo "Applying PostgREST grants..."
docker exec -i "$CONTAINER" psql -v ON_ERROR_STOP=1 \
  --username stars --dbname stars \
  < db/grants.sql

echo "Done. Bring up the rest: docker compose up -d"
