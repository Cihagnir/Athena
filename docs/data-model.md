# Veri Modeli

Kaynak: `backend/pb_migrations/`. Şema değişikliği = yeni migration dosyası (mevcut dosya düzenlenmez). Her kayıtta ayrıca `id`, `created`, `updated` bulunur.

Tek kullanıcılı sistem: kayıtlarda sahip alanı yok; tüm kurallar "giriş yapılmış olsun" (`@request.auth.id != ""`).

## `projects`

| Alan | Tip | Not |
|---|---|---|
| `name` | text, zorunlu, **benzersiz** | hızlı eklemede `#ad` ile eşleşir |
| `area` | `work` \| `personal`, zorunlu | arayüzde iş / kişisel |
| `status` | `active` \| `on_hold` \| `done`, zorunlu | aktif / beklemede / bitti |
| `description` | text (markdown) | |

Renk alanı **yok** — arayüz saf monokrom ([DESIGN.md](DESIGN.md)).

## `tasks`

| Alan | Tip | Not |
|---|---|---|
| `title` | text, zorunlu | |
| `notes` | text (markdown) | task'a düşülen not |
| `area` | `work` \| `personal`, opsiyonel | boşsa alan filtreli listelerde çıkmaz |
| `project` | → `projects`, opsiyonel | |
| `status` | `todo` \| `doing` \| `blocked` \| `done`, zorunlu | kanban sütunları |
| `priority` | 1–4 tam sayı, zorunlu | 1 en yüksek |
| `scheduled_date` | `YYYY-MM-DD` metni ya da boş | ne zaman **yapılacak**; Odak/Hafta bunu kullanır |
| `due_date` | `YYYY-MM-DD` metni ya da boş | son tarih; hızlı eklemede sözdizimi henüz yok |
| `sort_order` | number | küçükten büyüğe |
| `completed_at` | datetime | server yönetir (`status` ile birlikte) |
| `note` | → `notes`, opsiyonel | gevşek bağ; not ekranı geri-bağlantıları `filter=note="ID"` ile listeler |

- Günler saat dilimsiz metin olarak tutulur: UTC kayması olmaz, `<=` karşılaştırması sözlük sırasıyla doğru çalışır. **Dikkat:** boş metin her tarihten küçüktür → tarih filtrelerinde `scheduled_date != ''` şartı gerekir (`/api/views/*` bunu yapar).
- **Geçici günlük task** ayrı bir tip değil: `project` boş + `scheduled_date` dolu. Triyajda projeye taşınınca kalıcılaşır.

## `notes`

| Alan | Tip | Not |
|---|---|---|
| `title` | text, zorunlu | |
| `body` | text (markdown) | |
| `project` | → `projects`, opsiyonel | |
| `tags` | json (`string[]`) | |
| `pinned` | bool | |

## `focus_state`

Tek kayıt, sabit id: `focusstate00001`. REST'ten yalnızca okunur; `/api/focus/*` yazar.

| Alan | Tip | Not |
|---|---|---|
| `current_task` | → `tasks`, opsiyonel | aktif task |
| `timer_started_at` | datetime | boş = zamanlayıcı yok |
| `timer_duration` | saniye | 0 = zamanlayıcı yok |

## Silme davranışı

İlişkilerin hiçbiri cascade değil: proje silinince task'ların ve notların `project` alanı boşalır (kayıtlar kalır); not silinince `tasks.note` boşalır; aktif task silinince `focus_state` temizlenir.
