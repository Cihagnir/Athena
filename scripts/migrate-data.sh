#!/bin/sh
# Yereldeki PocketBase verisini (task'lar, notlar, projeler, kullanıcı) sunucuya taşır.
#   scripts/migrate-data.sh --dry-run   arşivi üretir, sunucuya yollar, içeriğini listeler, siler
#   scripts/migrate-data.sh             GERÇEK taşıma: sunucudaki veri yedeklenip DEĞİŞTİRİLİR
# Kullanıcı kaydı da taşınır → sunucuda giriş parolası yereldeki parola olur (API anahtarı değişmez).
set -eu

HOST="${TT_DEPLOY_HOST:-<sunucu>}"
DIR="${TT_DEPLOY_DIR:-task-tracker}"
VOLUME="${TT_LOCAL_VOLUME:-backend_pb_data}"
STAMP=$(date +%Y%m%d-%H%M%S)
ARCHIVE="/tmp/tt-pb-data-$STAMP.tgz"
cd "$(dirname "$0")/../backend"

echo "→ yerel sunucu durduruluyor (tutarlı kopya için)"
docker compose stop pocketbase >/dev/null
docker run --rm -v "$VOLUME":/d:ro alpine tar -C /d -cz --exclude backups . > "$ARCHIVE"
docker compose start pocketbase >/dev/null
echo "→ arşiv: $(du -h "$ARCHIVE" | cut -f1)"
scp -q "$ARCHIVE" "$HOST:/tmp/"

if [ "${1:-}" = "--dry-run" ]; then
    ssh "$HOST" "tar -tzf $ARCHIVE | head -12; rm -f $ARCHIVE"
    rm -f "$ARCHIVE"
    echo "deneme tamam — sunucuda hiçbir şey değişmedi"
    exit 0
fi

ssh "$HOST" "set -e; cd ~/$DIR/backend
    docker compose stop pocketbase >/dev/null
    docker run --rm -v ~/$DIR:/t alpine sh -c 'mv /t/data /t/data.before-$STAMP && mkdir /t/data && tar -C /t/data -xzf - ' < $ARCHIVE
    rm -f $ARCHIVE
    PROFILE=''; test -f tunnel/config.yml && PROFILE='--profile tunnel'
    docker compose \$PROFILE up -d >/dev/null
    echo 'taşındı — eski veri: ~/$DIR/data.before-$STAMP (sorun yoksa silinebilir)'"
rm -f "$ARCHIVE"
