# backend

PocketBase v0.40.4 (Docker) + iş mantığı (`pb_hooks`). Sözleşme: [../docs/api.md](../docs/api.md) · Şema: [../docs/data-model.md](../docs/data-model.md)

```
Dockerfile            pinli PocketBase imajı (sürüm: PB_VERSION; checksum doğrulanır)
entrypoint.sh         superuser upsert → serve
docker-compose.yml    port yalnızca 127.0.0.1 · pb_data named volume · hooks/migrations salt-okunur bağlı
pb_migrations/        şema — değişiklik = yeni dosya
pb_hooks/
  main.pb.js          401 koruması + .env'den kullanıcı oluşturma
  quickadd.pb.js      /api/quickadd, /api/quickadd/preview
  views.pb.js         /api/views/focus | week | projects
  triage.pb.js        /api/triage/{id}
  focus.pb.js         /api/focus…
  tasks.pb.js         completed_at + aktif task'ı boşaltma kuralları
  lib/parser.js       hızlı ekleme parser'ı (saf; Node'da da çalışır)
  lib/dates.js        YYYY-MM-DD aritmetiği, "bugün"
  lib/store.js        ortak DB yardımcıları
tests/unit/           parser testleri (sunucu gerekmez)
tests/api/            çalışan sunucuya karşı uçtan uca testler
```

## Çalıştırma

```sh
colima start                 # Docker daemon (bu Mac'te colima)
cp .env.example .env         # ilk kurulumda; parolaları doldur
docker compose up -d --build
```

- API: `http://127.0.0.1:8090/api/` · Admin UI: `http://127.0.0.1:8090/_/` (`PB_SUPERUSER_*`)
- Uygulama kullanıcısı (`TT_USER_*`) ilk açılışta oluşturulur. Sonradan parola değiştirmek için Admin UI kullanılır (`.env`'deki değer yalnızca ilk oluşturmada okunur; superuser ise her açılışta `.env`'den güncellenir).
- `pb_hooks` ya da `pb_migrations` değişince: `docker compose restart`
- Loglar: `docker compose logs -f`

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
