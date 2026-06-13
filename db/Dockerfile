# Postgres image with the PostgREST role-bootstrap baked in. The script in
# /docker-entrypoint-initdb.d runs once, on first init of an empty data volume,
# and reads AUTHENTICATOR_PASSWORD from the environment at that time.
FROM postgres:17-alpine

COPY db/initdb/ /docker-entrypoint-initdb.d/
