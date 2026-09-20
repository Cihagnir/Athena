# task_tracker

Kişisel, self-hosted **task + not sistemi**. Todoist'in yerine; tamamen modifiye edilebilir, klavye-öncelikli, **e-ink estetiğinde** (monokrom · monospace · hareketsiz).

- **Backend:** PocketBase (`<sunucu>` üzerinde Docker) — ortak iş mantığı `pb_hooks` içinde
- **macOS:** Swift + SwiftUI — menü çubuğu, global hotkey'ler, yüzen dashboard panelleri
- **Android:** ayrı native uygulama (teknoloji kararı ertelendi)

| Doküman | İçerik |
|---|---|
| [docs/PLAN.md](docs/PLAN.md) | Mimari, veri modeli, ekranlar, klavye mimarisi, fazlar, doğrulama |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Alınan kararlar, gerekçeleri, elenen alternatifler, ertelenenler |
| [docs/DESIGN.md](docs/DESIGN.md) | "E-ink" görsel dili: palet, tipografi, anlam sözlüğü, bileşen kuralları |
| [docs/api.md](docs/api.md) | İki uygulamanın da uyduğu API sözleşmesi (`curl` örnekleriyle) |
| [docs/data-model.md](docs/data-model.md) | Koleksiyonlar ve alanlar |
| [backend/README.md](backend/README.md) | Backend'i çalıştırma, testler, sürüm yükseltme |

```
backend/   PocketBase (Docker) + pb_hooks iş mantığı + testler
macos/     Swift + SwiftUI uygulaması (Faz 2 — henüz boş)
docs/      plan, kararlar, tasarım, API sözleşmesi
```

---

## Durum — 2026-09-20

**Faz 0 (iskelet) ve Faz 1 (backend) tamamlandı.** Backend yerelde Docker'da çalışıyor; parser birim testleri 21/21, uçtan uca API testleri 15/15 (401 koruması, quickadd, görünümler, triyaj, aktif task + zamanlayıcı, SSE realtime). Tasarım teması belirlendi: [docs/DESIGN.md](docs/DESIGN.md). Sıradaki: **Faz 2 — macOS uygulaması.**

### Ön koşullar — hepsi tamam

Xcode 27.0 (lisans kabul edildi) · Swift 6.4 · XcodeGen · git · Docker (colima). Repo `main` dalında, ilk commit atıldı.

### Devam ederken ilk adım

**Faz 2 / adım 1:** XcodeGen iskeleti → `Theme` (DESIGN.md belirteçleri) → API istemcisi + giriş → `ActionRegistry` → Odak ekranı + hızlı ekleme paneli (ilk kullanılabilir sürüm)

Ayrıntılar: [docs/PLAN.md](docs/PLAN.md) → "Uygulama adımları".

### Backend'i çalıştırma

```sh
colima start && cd backend && docker compose up -d     # API: http://127.0.0.1:8090 · Admin UI: /_/
pnpm test && pnpm test:api
```

Giriş bilgileri `backend/.env` içinde (yerelde üretildi, repoya girmez).

### Ortam notları

- **Sunucu:** `<sunucu>` — Tailscale SSH (`ssh <sunucu>`), IP `<ip>`. Docker sürümü / boş portları henüz **incelenmedi** (Faz 4).
- **Bu Mac:** macOS 26 · Xcode 27.0 · Swift 6.4 · XcodeGen · Docker 29 (**colima**) + Compose 5.2 · Node 24 + pnpm 11 · Python 3.14 · Android Studio + SDK 37 · editör: Zed
- **Kurulu olmayanlar:** Rust, Flutter
- Todoist hesabı geçiş tamamlanana kadar **silinmeyecek**; import script'i Faz 4'te.

### Yeni oturumda Claude'a söylenecek

> "`README.md` ve `docs/` altındaki planı oku, kaldığımız yerden devam edelim."
