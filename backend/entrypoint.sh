#!/bin/sh
set -e

PB="/pb/pocketbase --dir=/pb/pb_data --hooksDir=/pb/pb_hooks --migrationsDir=/pb/pb_migrations"

# Admin UI hesabı .env'den; her açılışta upsert (parola .env'de değişirse güncellenir).
if [ -n "$PB_SUPERUSER_EMAIL" ] && [ -n "$PB_SUPERUSER_PASSWORD" ]; then
    $PB superuser upsert "$PB_SUPERUSER_EMAIL" "$PB_SUPERUSER_PASSWORD"
fi

exec $PB serve --http=0.0.0.0:8090
