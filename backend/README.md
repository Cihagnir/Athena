# backend

PocketBase v0.40.4 (Docker) + iş mantığı (`pb_hooks`). Sözleşme: [../docs/api.md](../docs/api.md) · Şema: [../docs/data-model.md](../docs/data-model.md)

```
Dockerfile            pinli PocketBase imajı (sürüm: PB_VERSION; checksum doğrulanır)
entrypoint.sh         superuser upsert → serve
docker-compose.yml    port yalnızca 127.0.0.1 · pb_data named volume · hooks/migrations salt-okunur bağlı
pb_migrations/        şema — değişiklik = yeni dosya
pb_hooks/
  main.pb.js          API anahtarı kapısı · 401 koruması · .env'den kullanıcı · public ayarlar (hız sınırı, yedek)
  quicknote.pb.js     /api/quicknote, /api/quicknote/preview
  quickadd.pb.js      /api/quickadd, /api/quickadd/preview
  views.pb.js         /api/views/focus | week | projects
  triage.pb.js        /api/triage/{id}
  focus.pb.js         /api/focus…
  tasks.pb.js         completed_at + aktif task'ı boşaltma kuralları
  lib/parser.js       hızlı ekleme parser'ı (saf; Node'da da çalışır)
  lib/notes.js        hızlı not ayrıştırıcısı (saf)
  lib/dates.js        YYYY-MM-DD aritmetiği, "bugün"
  lib/store.js        ortak DB yardımcıları
tests/unit/           parser testleri (sunucu gerekmez)
tests/api/            çalışan sunucuya karşı uçtan uca testler
```

## Çalıştırma

En kısa yol (repo kökünden): `scripts/setup-local.sh` — `.env` yoksa `.env.example`'dan rastgele parolalarla üretir, PocketBase'i başlatır, sağlığını bekler ve uygulamaya girilecek bilgileri yazar. Elle:

```sh
colima start                 # Docker daemon (Mac'te colima ya da Docker Desktop)
cp .env.example .env         # ilk kurulumda; parolaları doldur (aşağıdaki tablo)
docker compose up -d --build
```

- API: `http://127.0.0.1:8090/api/` · Admin UI: `http://127.0.0.1:8090/_/` (`PB_SUPERUSER_*`)
- Uygulama kullanıcısı (`TT_USER_*`) ilk açılışta oluşturulur. Sonradan parola değiştirmek için Admin UI kullanılır (`.env`'deki değer yalnızca ilk oluşturmada okunur; superuser ise her açılışta `.env`'den güncellenir).
- `pb_hooks` ya da `pb_migrations` değişince: `docker compose restart`
- Loglar: `docker compose logs -f`

## Yapılandırma (`.env`)

Tüm ayarlar `backend/.env` içindeki ortam değişkenleridir (`docker compose` `env_file` ile okur, hook'lar `$os.getenv` ile alır). Şablon: [`.env.example`](.env.example). Dosya repoya girmez; `scripts/deploy.sh` sunucudakine dokunmaz.

| Değişken | Ne için | Yerel (`setup-local.sh`) | Sunucu ([DEPLOY.md](../docs/DEPLOY.md)) |
|---|---|---|---|
| `TZ` | "bugün / yarın" hesabının saat dilimi | `Europe/Istanbul` | aynı |
| `PB_PORT` | PocketBase'in `127.0.0.1`'de dinlediği port | `8090` | boş bir port |
| `PB_DATA` | verinin duracağı klasör; boşsa Docker volume (`task-tracker_pb_data`) | boş | `/home/<kullanıcı>/task-tracker/data` |
| `PB_SUPERUSER_EMAIL` / `_PASSWORD` | yönetim paneli (`/_/`) hesabı; her açılışta `.env`'den güncellenir | rastgele üretilir | `openssl rand -hex 16` |
| `TT_USER_EMAIL` / `_PASSWORD` | uygulamaların giriş yaptığı tek kullanıcı; yoksa açılışta oluşturulur, sonra yalnızca Admin UI'dan değişir | rastgele üretilir | kendin belirle |
| `TT_API_KEYS` | virgülle ayrılmış anahtarlar; doluysa tünelden gelen **her** istek `X-API-Key` taşımalı (`403`). Cihaz başına bir tane önerilir | boş (kapı kapalı) | `openssl rand -hex 32` |
| `TT_PUBLIC` | `1`: hız sınırlayıcı, Cloudflare gerçek istemci IP'si, günlük yedek (04:00, son 14) | boş | `1` |

`.env` değişince `docker compose restart` **yetmez** (ortam değişkenleri yeniden okunmaz): `docker compose up -d`.

Sunucuya özgü diğer iki yer: `tunnel/config.yml` (Cloudflare Tunnel; şablon `tunnel/config.example.yml`, yalnızca `main` dalında) ve Mac'te `TT_DEPLOY_HOST` / `TT_DEPLOY_DIR` (deploy betikleri için). Uygulama tarafında sunucu adresi ve API anahtarı Ayarlar (`⌘,`) ekranından girilir.

## Sunucu

Sunucu kurulumu, API anahtarı, tünel, yedekler ve veri taşıma: [../docs/DEPLOY.md](../docs/DEPLOY.md). Güncelleme göndermek: `TT_DEPLOY_HOST=<sunucu> ../scripts/deploy.sh`.

## Testler

```sh
pnpm test        # parser birim testleri
pnpm test:api    # uçtan uca; sunucu ayakta olmalı. Kendi kayıtlarını ("zz-test…") temizler.
```

## Sürüm yükseltme

`Dockerfile` (`PB_VERSION`) ve `docker-compose.yml` (`image:` etiketi) birlikte güncellenir → `docker compose up -d --build` → `pnpm test:api`. PocketBase v1.0 öncesi olduğu için sürüm notları okunmadan yükseltilmez.

## JSVM notları (v0.40.4'te doğrulandı)

- Her handler izole çalışır: dosya düzeyindeki değişkenler handler içinden görünmez → modüller handler **içinde** `require` edilir.
- `onServe` hook'u yok; açılış işleri `onBootstrap` içinde `e.next()`'ten sonra yapılır.
- `findRecordsByFilter` Go slice'ı döner → `lib/store.js` düz diziye çevirir.
- Tip tanımları: `docker exec task-tracker-pb cat /pb/pb_data/types.d.ts`
