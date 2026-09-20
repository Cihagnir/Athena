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
| [macos/README.md](macos/README.md) | Mac uygulaması: çalıştırma, kısayollar, mimari, yeni aksiyon/görünüm ekleme rehberi |

```
backend/   PocketBase (Docker) + pb_hooks iş mantığı + testler
macos/     Swift + SwiftUI uygulaması: Core (API paketi) + TaskTracker (arayüz)
docs/      plan, kararlar, tasarım, API sözleşmesi
```

---

## Durum — 2026-09-20

| Faz | Durum |
|---|---|
| 0 · İskelet | ✅ |
| 1 · Backend | ✅ birim 39/39, API 18/18 |
| 2 · macOS | **adım 1–4 ✅** (tüm görünümler + hızlı not `⌃⌥N`) — yüzen mini/liste paneli (`⌃⌥M` / `⌃⌥L`) + zamanlayıcı; öncesi: giriş, Odak ekranı, hızlı ekleme paneli (global `⌃⌥Space`), Ayarlar, aksiyon kaydı, tam ekran (`⌃⌘F`), menü çubuğu öğesi (`▸ 3/7`), otomatik başlama, `⌘K` komut paleti, `?` yardım. Core paketi 18/18 (canlı sözleşme testleri dahil). |
| 3 · Android · 4 · Deploy | sırada değil |

Tasarım: [docs/DESIGN.md](docs/DESIGN.md) + görsel taslak tuvali (bağlantısı dokümanın başında).

### Devam ederken ilk adım

**Faz 2'nin planlanan dört adımı + task düzenleme tamam.** Plan: Mac uygulaması bir hafta gerçek kullanımda incelenip iyileştirilecek; ardından **Faz 4 (sunucuya deploy)**. Faz 3 (Android) ertelendi. Ayrıntı ve sonraki adımlar: [macos/README.md](macos/README.md) → Sıradakiler.

### Mac uygulamasını çalıştırma

```sh
cd macos && xcodegen generate
xcodebuild -project TaskTracker.xcodeproj -scheme TaskTracker -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/TaskTracker.app
```

Mimari, "nasıl yapılır" rehberleri ve bilinen sapmalar: [macos/README.md](macos/README.md).

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
