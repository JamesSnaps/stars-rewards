# Migrating from Supabase + Vercel to Docker

The app only ever used Supabase as **Postgres + PostgREST** (the `/rest/v1/` API)
with the anon key. No Supabase Auth/Storage/Realtime/Edge Functions. So the
self-hosted stack is a faithful drop-in:

| Service | Replaces | Image |
|---|---|---|
| `stars-db` | Supabase Postgres | `postgres:17-alpine` |
| `stars-api` | Supabase `/rest/v1/` | `postgrest/postgrest` |
| `stars-web` | Vercel static hosting | `nginx:alpine` |
| `stars-trmnl` | Vercel `/api/trmnl` function | tiny Node service |

`nginx` serves the static app and proxies `/rest/v1/*` to PostgREST, so the
frontend keeps calling the exact same paths. Deployment is **LAN-only** — keep
port `8090` on your home network.

## One-time migration

```bash
# 0. (Optional) regenerate secrets — already done once in .env:
node scripts/gen-secrets.mjs    # paste output into .env, config.js, trmnl.html

# 1. Back up Supabase WHILE THE PROJECT IS STILL ALIVE
SUPABASE_DB_HOST='aws-1-eu-west-2.pooler.supabase.com' \
SUPABASE_DB_USER='postgres.oxmaqeuhdggpmvxatxzk' \
SUPABASE_DB_PASSWORD='******' \
  ./scripts/1-backup-supabase.sh
#   -> get PASSWORD + host from Supabase dashboard:
#      Project Settings -> Database -> Connection string -> Direct connection (5432)

# 2. Start the database only
docker compose up -d stars-db

# 3. Restore the dump and apply PostgREST grants
./scripts/2-restore-local.sh stars-backup-YYYYMMDD-HHMMSS.dump

# 4. Bring up the rest
docker compose up -d
```

App: `http://<server-ip>:8090`  · TRMNL JSON: `http://<server-ip>:8090/api/trmnl`

## What changed in the repo

- `config.js` — `SUPABASE_URL` is now `''` (same-origin) and `SUPABASE_KEY` is
  the new anon JWT.
- `trmnl.html` — same two values updated inline.
- `.env` — generated secrets (gitignored).
- Vercel/Supabase config is no longer used; you can delete the Vercel project and
  Supabase project **after** confirming the Docker stack works.

## Production deploy on vm-core (Traefik + auto-build)

Pushes to `main` build three images via
`.github/workflows/docker-publish.yml` and publish them to GHCR:

- `ghcr.io/jamessnaps/stars-rewards` — nginx + static app + `/rest/v1/` proxy
- `ghcr.io/jamessnaps/stars-rewards-trmnl` — the e-ink JSON endpoint
- `ghcr.io/jamessnaps/stars-rewards-db` — Postgres with the role bootstrap baked in

`docker-compose.stars.yml` in the vm-core stack pulls these, served at
`https://stars.collardserver.co.uk` via Traefik on vlan5 IPs 10.0.5.25–.28.
**Watchtower auto-updates them** on each new push — no host files to sync.

One-time setup:

1. Make the three GHCR packages **public** (Repo → Packages → Package settings →
   Change visibility), or run `docker login ghcr.io` on the server, so the host
   can pull them.
2. Add the `STARS_*` vars to `/home/$USER/docker/.env` (see `env-template.txt`).
   Generate with `node scripts/gen-secrets.mjs`; the **same** `ANON_JWT` must
   also be in the committed `config.js`/`trmnl.html`, and `JWT_SECRET` must
   match `STARS_JWT_SECRET`.
3. Start the DB, restore your Supabase dump into the `stars-db` container
   (`scripts/2-restore-local.sh`), then start everything:
   ```bash
   ./docker-compose.sh start stars     # pulls images, starts all 4 services
   ./docker-compose.sh stop stars
   ```

By design the Traefik router has **no Authelia** (LAN-only). To gate it behind
SSO like the other apps, uncomment the `auth@file` middleware line in
`docker-compose.stars.yml`.

> Local development still uses the repo's own `docker-compose.yml` (bind-mounted
> files, live edits). The vm-core stack is the image-based production deploy.
