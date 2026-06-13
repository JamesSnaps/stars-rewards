# Web image: nginx serving the static app + proxying /rest/v1/ to PostgREST.
FROM nginx:alpine

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

# Static app files (explicit list so build/db/scripts dirs don't leak into the
# web root).
COPY index.html config.js manifest.json robots.txt sw.js \
     terminal.html trmnl.html /usr/share/nginx/html/
