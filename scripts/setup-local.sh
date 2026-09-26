#!/bin/sh
# Yerel kurulum: backend/.env üretir (yoksa), PocketBase'i Docker'da başlatır, sağlığını bekler
# ve Mac uygulamasına girilecek bilgileri yazar. Tekrar çalıştırmak güvenlidir (.env'e dokunmaz).
#   scripts/setup-local.sh
set -eu

cd "$(dirname "$0")/../backend"

command -v docker >/dev/null || { echo "docker bulunamadı — Docker Desktop ya da colima kur"; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker çalışmıyor (colima start / Docker Desktop'ı aç)"; exit 1; }

if [ ! -f .env ]; then
    echo "→ backend/.env üretiliyor (rastgele parolalar)"
    SUPER=$(openssl rand -hex 12)
    USERPW=$(openssl rand -hex 12)
    sed -e "s|^PB_SUPERUSER_PASSWORD=.*|PB_SUPERUSER_PASSWORD=$SUPER|" \
        -e "s|^TT_USER_PASSWORD=.*|TT_USER_PASSWORD=$USERPW|" \
        .env.example > .env
    chmod 600 .env
else
    echo "→ backend/.env var, korunuyor"
fi

PORT=$(grep -E '^PB_PORT=' .env | cut -d= -f2)
PORT=${PORT:-8090}

echo "→ PocketBase başlatılıyor"
docker compose up -d --build 2>&1 | tail -3

for i in $(seq 1 30); do
    curl -fs "http://127.0.0.1:$PORT/api/health" >/dev/null && break
    sleep 1
done
curl -fs "http://127.0.0.1:$PORT/api/health" >/dev/null || { echo "sağlık kontrolü başarısız"; docker compose logs --tail 20; exit 1; }

EMAIL=$(grep -E '^TT_USER_EMAIL=' .env | cut -d= -f2)
PASS=$(grep -E '^TT_USER_PASSWORD=' .env | cut -d= -f2)
ADMIN=$(grep -E '^PB_SUPERUSER_EMAIL=' .env | cut -d= -f2)
ADMINPW=$(grep -E '^PB_SUPERUSER_PASSWORD=' .env | cut -d= -f2)

cat <<EOF

hazır.

Mac uygulaması → giriş ekranı
  sunucu        http://127.0.0.1:$PORT
  e-posta       $EMAIL
  parola        $PASS
  API anahtarı  (boş)

Yönetim paneli  http://127.0.0.1:$PORT/_/   ($ADMIN / $ADMINPW)
Bilgiler backend/.env içinde durur. Durdurmak: cd backend && docker compose stop
EOF
