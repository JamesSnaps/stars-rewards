#!/bin/bash
# Runs once, on first init of an empty data volume (before the data restore).
# Creates the PostgREST roles: `authenticator` (which PostgREST logs in as) and
# `anon` (the role it switches to for requests bearing the anon JWT). Table
# grants are applied AFTER the data restore — see db/grants.sql.
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD '${AUTHENTICATOR_PASSWORD}';
    CREATE ROLE anon NOLOGIN;
    GRANT anon TO authenticator;
EOSQL
