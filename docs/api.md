# API Sözleşmesi

macOS ve Android uygulamalarının uyduğu **tek kaynak**. Backend: PocketBase v0.40.4 + `backend/pb_hooks`.
Buradaki her davranış `backend/tests/api/api.test.js` ile sınanır; sözleşme değişirse test de değişir.

- Yerel adres: `http://127.0.0.1:8090` (deploy sonrası: `https://<sunucu>.<tailnet>.ts.net`)
- Tüm gövdeler JSON. Günler saat dilimsiz `YYYY-MM-DD` metnidir; "bugün" **server'ın** `TZ` ayarına göre belirlenir — istemci kendi saatinden gün hesaplamaz, yanıtlardaki `today` alanını kullanır.
- Hata gövdesi: `{ "status": 400, "message": "…", "data": {} }`

Örneklerde:

```sh
PB=http://127.0.0.1:8090
```

## Kimlik doğrulama

Tek kullanıcı (`backend/.env` → `TT_USER_EMAIL` / `TT_USER_PASSWORD`), açılışta otomatik oluşturulur. Kayıt (sign-up) kapalıdır.

```sh
TOKEN=$(curl -s -X POST $PB/api/collections/users/auth-with-password \
  -H 'Content-Type: application/json' \
  -d '{"identity":"me@task-tracker.local","password":"…"}' | jq -r .token)
```

Sonraki her istekte: `Authorization: $TOKEN` (önek yok). Token yenileme: `POST /api/collections/users/auth-refresh`.

**Girişsiz her istek `401` döner** — özel endpoint'ler de, `projects | tasks | notes | focus_state` koleksiyon uçları da.

## Hızlı ekleme

Sözdizimi — token'lar satırın herhangi bir yerinde, boşlukla ayrılmış; her türden yalnızca **ilki** tüketilir, tanınmayan her şey başlıkta kalır:

| Token | Anlam |
|---|---|
| `bugün` `yarın` | **başlama günü** (`scheduled_date`): task o gün Odak'a düşer |
| `pzt` `sal` `çar` `per` `cum` `cmt` `paz` (+ uzun adları) | bir sonraki o gün; bugünün adı yazılırsa haftaya |
| `25.09` `25/09` `25.09.2027` | yılsız ve geçmişte kalan tarih gelecek yıla yuvarlanır; geçersiz tarih (`31.02`) token sayılmaz |
| `son:cuma` `son:yarın` `son:25.09` | **bitiş / son tarih** (`due_date`): `son:` + yukarıdaki tarih biçimlerinden herhangi biri. Başlama gününden bağımsızdır; çözülemeyen (`son:31.02`) başlıkta kalır |
| `!1` … `!4` | öncelik (1 en yüksek; varsayılan 4) |
| `#proje` | ada göre eşleşir: büyük/küçük harf ve Türkçe karakter duyarsız, boşluk yerine `-`, **tekil önek** yeterli (`#fin` → Finans). Bitmiş projeler eşleşmez. |
| `@iş` `@kişisel` | alan; verilmezse projenin alanı miras alınır |
| `// …` | tek başına duran ilk `//`'den sonrası **açıklama**dır; parse edilmez (içinde `yarın`, `#x` geçebilir). `https://…` içindeki `//` ayraç sayılmaz |
| `"…"` / `“…”` | tüm satır tırnak içindeyse parse kapalı, içerik aynen başlık olur |

ASCII yazımlar da geçerli (`bugun`, `yarin`, `sali`, `@is`, `@kisisel`).

Tarih çözümü **deterministik**tir (sözlük + takvim aritmetiği, `backend/pb_hooks/lib/parser.js`); aynı girdi aynı gün içinde hep aynı sonucu verir.

Kurallar:
- **Tarihsiz + projesiz** → `scheduled_date = bugün` (geçici günlük task). **Projeli + tarihsiz** → `scheduled_date` boş (proje birikimi).
- `son:` başlama günü vermez: `Rapor son:cuma` (projesiz) → başlama bugün, bitiş cuma. Bitiş başlamadan önceyse task yine oluşur, `warnings: ["due_before_scheduled"]` döner.
- Eşleşmeyen/belirsiz `#proje` **girdiyi kaybettirmez**: task yine oluşur, `#…` başlıkta kalır, `warnings: ["project_not_found"]` döner.
- Başlık boş kalıyorsa (`yarın !1`, `// yalnızca açıklama`) → `400`. `text` en fazla 500 karakter (`//` kısmı dahil); uzun açıklama `description` alanıyla gönderilir.

### `POST /api/quickadd/preview`

Yazarken canlı önizleme; kayıt oluşturmaz.

```sh
curl -s -X POST $PB/api/quickadd/preview -H "Authorization: $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"text":"Faturayı öde yarın !1 #finans @kişisel"}'
```

```json
{
  "literal": false,
  "valid": true,
  "title": "Faturayı öde",
  "scheduled_date": "2026-09-21",
  "due_date": null,
  "priority": 1,
  "project": { "id": "…", "name": "Finans", "area": "personal" },
  "area": "personal",
  "description": null,
  "tokens": [
    { "type": "date", "raw": "yarın", "start": 13, "end": 18, "value": "2026-09-21" },
    { "type": "priority", "raw": "!1", "start": 19, "end": 21, "value": 1 },
    { "type": "project", "raw": "#finans", "start": 22, "end": 29, "value": { "id": "…", "name": "Finans", "area": "personal" } },
    { "type": "area", "raw": "@kişisel", "start": 30, "end": 38, "value": "personal" }
  ],
  "warnings": []
}
```

- `tokens[].start/end`: özgün metindeki **UTF-16** ofsetleri (Swift'te `String.utf16` / `NSRange`, Kotlin'de doğrudan `String` indeksi). Vurgulama bunlarla yapılır.
- Token türleri: `date` · `due` · `priority` · `project` · `area` · `description` (`//`'den satır sonuna; `value` = açıklama metni, her zaman son token).
- Çözülemeyen proje token'ında `value: null`.
- `valid: false` → Enter'a basılırsa quickadd `400` dönecek demektir.

### `POST /api/quickadd`

Gövde: `{ "text": "…", "description": "…" }`. `description` opsiyoneldir: paneldeki çok satırlı açıklama alanı buradan gelir (markdown, parse edilmez). Satırda `// …` de varsa ikisi alt alta birleştirilir (önce satırdaki), hiçbiri kaybolmaz.

```sh
curl -s -X POST $PB/api/quickadd -H "Authorization: $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"text":"Teklifi gönder salı son:cuma !1 // fiyat tablosunu ekle"}'
```

→ `{ "task": <task kaydı>, "parsed": <preview ile aynı yapı> }`

## Görünümler

### `GET /api/views/focus?area=work|personal`

Odak, Dashboard ve Triyaj'ın listesi: `scheduled_date ≤ bugün ∧ status ≠ done`, `sort_order` sıralı. Dünden kalanlar da buradadır (triyaj bu listeyi tek tek gezer). `area` verilirse yalnızca o alan; alanı boş task'lar filtreli listede çıkmaz.

```sh
curl -s "$PB/api/views/focus?area=work" -H "Authorization: $TOKEN"
```

→ `{ "today": "2026-09-20", "tasks": [ <task>, … ] }`

### `GET /api/views/week?start=YYYY-MM-DD`

`start` verilmezse bugün; 7 gün döner.

```sh
curl -s $PB/api/views/week -H "Authorization: $TOKEN"
```

```json
{
  "today": "2026-09-20", "start": "2026-09-20", "end": "2026-09-26",
  "days": [
    { "date": "2026-09-20", "weekday": 0, "open_count": 3, "done_count": 1, "tasks": [] }
  ],
  "overdue": []
}
```

- `weekday`: 0 = Pazar … 6 = Cumartesi. `tasks` o günün **tüm** task'ları (bitenler dahil); yük göstergesi = `open_count`.
- `overdue`: bugünden önceye planlı, bitmemiş task'lar (`start`'tan bağımsız).

### `GET /api/views/projects`

```sh
curl -s $PB/api/views/projects -H "Authorization: $TOKEN"
```

→ `{ "projects": [ { "project": <proje kaydı>, "open_count": 4, "done_count": 6, "progress": 0.6, "note_count": 2 } ] }` — `status`, sonra `name` sıralı; `progress` = biten / toplam (0–1).

## Triyaj

### `POST /api/triage/{id}`

| `action` | Ek alan | Etki |
|---|---|---|
| `tomorrow` | — | `scheduled_date = bugün + 1` |
| `date` | `date` (zorunlu) | `scheduled_date = date` |
| `to_project` | `project` (id, zorunlu), `date` (opsiyonel) | projeye taşır, **alanı projeden alır**, `scheduled_date`'i boşaltır (ya da `date`'e kurar) → günlük akıştan çıkar |
| `delete` | — | task'ı siler |

```sh
curl -s -X POST $PB/api/triage/TASK_ID -H "Authorization: $TOKEN" \
  -H 'Content-Type: application/json' -d '{"action":"tomorrow"}'
```

→ `{ "action": "tomorrow", "task": <task> }` (`delete`'te `task: null`). Bilinmeyen `action` / bozuk tarih → `400`; olmayan task ya da proje → `404`.

## Aktif task + zamanlayıcı

Durum tek kayıtta tutulur: `focus_state/focusstate00001`. **Yalnızca bu endpoint'ler yazar**; REST ile yazma kapalıdır. İstemciler `focus_state` koleksiyonunu realtime dinler.

Yanıtların hepsi aynı yapıda:

```json
{
  "state": { "id": "focusstate00001", "current_task": "…", "timer_started_at": "2026-09-20 16:45:00.000Z", "timer_duration": 1500 },
  "task": { }
}
```

| Endpoint | Davranış |
|---|---|
| `GET /api/focus` | mevcut durum; aktif task yoksa `task: null` |
| `POST /api/focus/{id}` | task'ı aktif yapar; farklı bir task'a geçiliyorsa zamanlayıcı sıfırlanır. Tamamlanmış task → `400` |
| `POST /api/focus/clear` | aktif task'ı ve zamanlayıcıyı boşaltır |
| `POST /api/focus/timer` | `{"action":"start","duration":1500}` (saniye, 1–86400) · `{"action":"stop"}`. Aktif task yokken `start` → `400` |

```sh
curl -s -X POST $PB/api/focus/TASK_ID -H "Authorization: $TOKEN"
curl -s -X POST $PB/api/focus/timer -H "Authorization: $TOKEN" \
  -H 'Content-Type: application/json' -d '{"action":"start","duration":1500}'
```

- Zamanlayıcı server'da **tıklamaz**: kalan süre = `timer_started_at + timer_duration − şimdi`, istemcide hesaplanır. Süre dolunca server bir şey yapmaz; ses/bildirim istemcinin işidir. Durdurulmuş/yok: `timer_duration = 0`, `timer_started_at = ""`.
- Aktif task **tamamlanınca ya da silinince** (hangi yoldan olursa olsun) `current_task` ve zamanlayıcı boşalır; otomatik yeni task atanmaz.

## Koleksiyonlar (standart PocketBase REST)

`/api/collections/{projects|tasks|notes}/records` — listeleme (`filter`, `sort`, `expand`, `page`, `perPage`), `GET/POST/PATCH/DELETE`. Alanlar: [data-model.md](data-model.md).

```sh
# task'ı tamamla
curl -s -X PATCH $PB/api/collections/tasks/records/TASK_ID -H "Authorization: $TOKEN" \
  -H 'Content-Type: application/json' -d '{"status":"done"}'

# proje oluştur
curl -s -X POST $PB/api/collections/projects/records -H "Authorization: $TOKEN" \
  -H 'Content-Type: application/json' -d '{"name":"Finans","area":"personal","status":"active"}'
```

Server tarafı kurallar (istemci uğraşmaz):
- `status` → `done` olunca `completed_at` dolar; `done`'dan çıkınca boşalır.
- REST ile task oluştururken `status` ve `priority` zorunludur (quickadd bunları kendisi doldurur).
- Sıralama: `sort_order` küçükten büyüğe. Quickadd yeni task'a `Date.now()` verir (liste sonu); araya taşırken iki komşunun ortalaması yazılır.

## Realtime (SSE)

PocketBase'in standart protokolü:

1. `GET /api/realtime` (SSE) → ilk olay `PB_CONNECT`, verisi `{ "clientId": "…" }`
2. `POST /api/realtime` + `Authorization` → `{ "clientId": "…", "subscriptions": ["tasks", "focus_state", "projects", "notes"] }` → `204`
3. Sonrasında olay adı = abonelik adı, veri = `{ "action": "create|update|delete", "record": { } }`

Özel endpoint'lerin yaptığı değişiklikler (quickadd, triyaj, focus) de aynı olayları üretir. Toplu görünümler (`/api/views/*`) için ayrı olay yoktur: istemci `tasks` olayını alınca ilgili görünümü yeniden çeker.
