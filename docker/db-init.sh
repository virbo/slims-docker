#!/bin/sh
set -eu

: "${DB_HOST:=db}"
: "${DB_PORT:=3306}"
: "${DB_NAME:=senayan}"
: "${DB_USER:?DB_USER must be set}"
: "${DB_PASS:?DB_PASS must be set}"

SCHEMA="/opt/slims-init/senayan.sql"
if [ ! -s "$SCHEMA" ]; then
  echo "ERROR: SLiMS schema file is missing: $SCHEMA" >&2
  exit 1
fi

echo "Checking whether database '${DB_NAME}' already contains tables..."
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

TABLE_COUNT="$(MYSQL_PWD="${DB_PASS}" mysql \
  --protocol=tcp -h "${DB_HOST}" -P "${DB_PORT}" \
  -u "${DB_USER}" "${DB_NAME}" -Nse \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${DB_NAME}'")"

case "$TABLE_COUNT" in
  ''|*[!0-9]*)
    echo "ERROR: could not safely determine the current table count." >&2
    exit 1
    ;;
esac

if [ "$TABLE_COUNT" -gt 0 ]; then
  echo "Database already contains ${TABLE_COUNT} table(s); skipping schema import. Existing data will not be changed by this initializer."
  exit 0
fi

echo "Database is empty. Importing the official SLiMS schema (sample data is not imported)..."
MYSQL_PWD="${DB_PASS}" mysql \
  --protocol=tcp -h "${DB_HOST}" -P "${DB_PORT}" \
  -u "${DB_USER}" "${DB_NAME}" < "$SCHEMA"

echo "Schema import completed."
