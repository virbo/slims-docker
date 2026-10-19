#!/bin/sh
set -eu

if [ "${1:-}" = "/usr/local/bin/slims-db-init.sh" ]; then
  exec "$@"
fi

: "${DB_HOST:=db}"
: "${DB_PORT:=3306}"
: "${DB_NAME:=senayan}"
: "${DB_USER:?DB_USER must be set}"
: "${DB_PASS:?DB_PASS must be set}"
: "${APP_ENV:=production}"

echo "Waiting for SLiMS database..."
attempt=0
until MYSQL_PWD="${DB_PASS}" mysql \
  --protocol=tcp -h "${DB_HOST}" -P "${DB_PORT}" \
  -u "${DB_USER}" "${DB_NAME}" -Nse "SELECT 1" >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 60 ]; then
    echo "ERROR: database was not reachable after 120 seconds." >&2
    exit 1
  fi
  sleep 2
done

php /usr/local/bin/slims-render-config.php

# Start PHP-FPM and Nginx under a small supervisor shell.
php-fpm -D
exec nginx -g 'daemon off;'
