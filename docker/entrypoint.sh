#!/bin/sh
set -eu

# Keep the database initializer behavior unchanged.
if [ "${1:-}" = "/usr/local/bin/slims-db-init.sh" ]; then
  exec "$@"
fi

: "${DB_HOST:=db}"
: "${DB_PORT:=3306}"
: "${DB_NAME:=senayan}"
: "${DB_USER:?DB_USER must be set}"
: "${DB_PASS:?DB_PASS must be set}"
: "${APP_ENV:=production}"

# Fix SLiMS configuration directory permissions on every startup.
# The entrypoint must run as root for these operations.
if [ "$(id -u)" -eq 0 ]; then
  if [ -d /var/www/html/config ]; then
    chown www-data:www-data /var/www/html/config
    chmod 750 /var/www/html/config
  else
    echo "ERROR: /var/www/html/config does not exist." >&2
    exit 1
  fi

  # Fix CSP configuration ownership and permissions if it already exists.
  if [ -f /var/www/html/config/csp.php ]; then
    chown www-data:www-data /var/www/html/config/csp.php
    chmod 640 /var/www/html/config/csp.php
  fi
else
  echo "ERROR: entrypoint must run as root to fix config permissions." >&2
  exit 1
fi

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

# Generate SLiMS configuration after fixing directory permissions.
php /usr/local/bin/slims-render-config.php

# Start PHP-FPM and Nginx.
php-fpm -D
exec nginx -g 'daemon off;'