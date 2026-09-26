#!/bin/sh
# Yereldeki PocketBase verisini (task'lar, notlar, projeler, kullanıcı) sunucuya taşır.
#   scripts/migrate-data.sh --dry-run   arşivi üretir, sunucuya yollar, içeriğini listeler, siler
#   scripts/migrate-data.sh             GERÇEK taşıma: sunucudaki veri yedeklenip DEĞİŞTİRİLİR
# Kullanıcı kaydı da taşınır → sunucuda giriş parolası yereldeki parola olur (API anahtarı değişmez).
set -eu

HOST="${TT_DEPLOY_HOST:?TT_DEPLOY_HOST verilmedi (ssh ile erişilen sunucu adı)}"
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

# Önce ayrı bir klasöre açılır; yer değiştirme yalnızca açma başarılıysa yapılır — yarıda
# kesilirse sunucu eski verisiyle kalır. `docker run -i`: arşiv container'a stdin'den girer.
ssh "$HOST" "set -e; cd ~/$DIR/backend
    docker run --rm -i -v ~/$DIR:/t alpine sh -c 'rm -rf /t/data.incoming && mkdir /t/data.incoming && tar -C /t/data.incoming -xzf - && test -s /t/data.incoming/data.db' < $ARCHIVE
    docker compose stop pocketbase >/dev/null
    docker run --rm -v ~/$DIR:/t alpine sh -c 'mv /t/data /t/data.before-$STAMP && mv /t/data.incoming /t/data'
    rm -f $ARCHIVE
    PROFILE=''; test -f tunnel/config.yml && PROFILE='--profile tunnel'
    docker compose \$PROFILE up -d >/dev/null
    PORT=\$(grep -E '^PB_PORT=' .env | cut -d= -f2)
    for i in \$(seq 1 30); do curl -fs http://127.0.0.1:\${PORT:-8090}/api/health >/dev/null && break; sleep 1; done
    curl -fs http://127.0.0.1:\${PORT:-8090}/api/health >/dev/null || { echo 'sunucu ayağa kalkmadı'; docker compose logs --tail 20; exit 1; }
    echo 'taşındı — eski veri: ~/$DIR/data.before-$STAMP (sorun yoksa silinebilir)'"
rm -f "$ARCHIVE"
