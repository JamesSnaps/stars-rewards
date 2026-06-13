#!/usr/bin/env bash
# Dump the Supabase Postgres database to a local file.
# Run this FIRST, while the Supabase project is still alive.
#
# Runs pg_dump inside a throwaway postgres:17-alpine container, so you don't
# need Postgres client tools installed locally (just Docker).
#
# Connection is passed as DISCRETE parameters (not a URL) so special characters
# in the password don't need escaping. Get these from the Supabase dashboard:
#   Project Settings -> Database -> Connection parameters
#
# Two host options:
#   1. Direct:  SUPABASE_DB_HOST=db.oxmaqeuhdggpmvxatxzk.supabase.co  PORT 5432
#               (may be IPv6-only / not resolve on some home networks)
#   2. Pooler:  SUPABASE_DB_HOST=aws-0-<region>.pooler.supabase.com   PORT 5432
#               SUPABASE_DB_USER=postgres.oxmaqeuhdggpmvxatxzk   (note the .ref)
#               Use the SESSION pooler (port 5432), NOT transaction (6543).
#               This works over IPv4 — use it if option 1 fails to resolve.
#
# Usage:
#   SUPABASE_DB_HOST=db.oxmaqeuhdggpmvxatxzk.supabase.co \
#   SUPABASE_DB_PASSWORD='your-password' \
#     ./scripts/1-backup-supabase.sh
set -euo pipefail

: "${SUPABASE_DB_HOST:?Set SUPABASE_DB_HOST (e.g. db.<ref>.supabase.co or the pooler host)}"
: "${SUPABASE_DB_PASSWORD:?Set SUPABASE_DB_PASSWORD}"
DB_USER="${SUPABASE_DB_USER:-postgres}"
DB_NAME="${SUPABASE_DB_NAME:-postgres}"
DB_PORT="${SUPABASE_DB_PORT:-5432}"

OUT="stars-backup-$(date +%Y%m%d-%H%M%S).dump"

echo "Dumping public schema from ${SUPABASE_DB_HOST}:${DB_PORT} -> ${OUT}"
# pg_dump reads PG* env vars natively — no URL parsing, no escaping needed.
docker run --rm -i \
  -e PGHOST="$SUPABASE_DB_HOST" \
  -e PGPORT="$DB_PORT" \
  -e PGUSER="$DB_USER" \
  -e PGPASSWORD="$SUPABASE_DB_PASSWORD" \
  -e PGDATABASE="$DB_NAME" \
  postgres:17-alpine \
  pg_dump --schema=public --no-owner --no-acl --format=custom \
  > "$OUT"

echo "Done. Backup written to ${OUT} ($(du -h "$OUT" | cut -f1))"
echo "Keep this file safe — it contains all your data."
