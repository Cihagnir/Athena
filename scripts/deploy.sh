#!/bin/sh
# Backend'i sunucuya gönderir ve yeniden başlatır.  Kullanım: scripts/deploy.sh
# Sunucudaki .env, tunnel/ (tünel kimliği) ve veri klasörüne DOKUNMAZ. Ayrıntı: docs/DEPLOY.md
set -eu

HOST="${TT_DEPLOY_HOST:?TT_DEPLOY_HOST verilmedi (ssh ile erişilen sunucu adı)}"
DIR="${TT_DEPLOY_DIR:-task-tracker}"
cd "$(dirname "$0")/.."

echo "→ $HOST:~/$DIR/backend"
ssh "$HOST" "mkdir -p ~/$DIR/backend ~/$DIR/data && chmod 700 ~/$DIR"
rsync -az --delete \
    --exclude '.env' --exclude 'tunnel/' --exclude 'node_modules/' --exclude 'pb_data/' \
    backend/ "$HOST:$DIR/backend/"

ssh "$HOST" "cd ~/$DIR/backend && test -f .env || { echo '.env yok — docs/DEPLOY.md → İlk kurulum'; exit 1; }
    PROFILE=''; test -f tunnel/config.yml && PROFILE='--profile tunnel'
    docker compose \$PROFILE up -d --build 2>&1 | tail -4
    docker compose restart pocketbase >/dev/null   # pb_hooks / pb_migrations değişiklikleri yüklensin
    for i in \$(seq 1 30); do
        PORT=\$(grep -E '^PB_PORT=' .env | cut -d= -f2)
        curl -fs http://127.0.0.1:\${PORT:-8090}/api/health >/dev/null && { echo 'sağlıklı'; exit 0; }
        sleep 1
    done
    echo 'sağlık kontrolü başarısız'; docker compose logs --tail 20; exit 1"
