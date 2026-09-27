# Athena — task + not sistemi

Kişisel, self-hosted **task + not sistemi**. Todoist'in yerine; tamamen modifiye edilebilir, klavye-öncelikli, **e-ink estetiğinde** (monokrom · monospace · hareketsiz).

- **Backend:** PocketBase (Docker) — ortak iş mantığı `pb_hooks` içinde
- **macOS:** Swift + SwiftUI — menü çubuğu, global hotkey'ler, yüzen dashboard panelleri
- **Android:** ayrı native uygulama (ertelendi)

## Dallar

| Dal | Ne için |
|---|---|
| **`local-dev`** | Kendi bilgisayarında çalıştırmak. Backend Docker'da yerelde, Mac uygulaması ona bağlanır. Sunucu, alan adı, tünel gerekmez. |
| **`main`** | `local-dev` + **sunucu katmanı**: backend'i kendi sunucuna kurup Cloudflare Tunnel ve API anahtarıyla internete açmak ([docs/DEPLOY.md](docs/DEPLOY.md), `scripts/deploy.sh`, `scripts/migrate-data.sh`, `backend/tunnel/`). |

Geliştirme `local-dev`'de yapılır; `main` onu merge eder. İki dalda uygulama kodu aynıdır.

## Yerelde çalıştırma (`local-dev`)

Ön koşullar: Docker + Compose (Mac'te ör. [colima](https://github.com/abiosoft/colima) ya da Docker Desktop), Xcode 27, `brew install xcodegen`. Testler için Node 24 + pnpm.

```sh
git clone -b local-dev <repo> athena && cd athena
scripts/setup-local.sh        # .env üretir (rastgele parolalar), backend'i başlatır, giriş bilgilerini yazar
```

Sonra Mac uygulaması — Release derler ve `/Applications/TaskTracker.app`'e kurar (güncellemek için aynı komut):

```sh
scripts/install-mac.sh
```

İlk açılışta giriş ekranı: sunucu `http://127.0.0.1:8090`, e-posta ve parola `setup-local.sh`'ın yazdığı (ya da `backend/.env` → `TT_USER_*`), API anahtarı boş. Ayrıntı ve kısayollar: [macos/README.md](macos/README.md).

Backend testleri: `cd backend && pnpm test && pnpm test:api`. Yönetim paneli: `http://127.0.0.1:8090/_/` (`backend/.env` → `PB_SUPERUSER_*`).

Tüm ayarlar `backend/.env` içindedir; değişkenlerin tablosu: [backend/README.md → Yapılandırma](backend/README.md#yapılandırma-env).

## Sunucuya kurmak (`main`)

[docs/DEPLOY.md](docs/DEPLOY.md): mimari, güvenlik katmanları, sıfırdan kurulum, güncelleme, yerel veriyi taşıma, yedekler.

## Dokümanlar

| Doküman | İçerik |
|---|---|
| [docs/PLAN.md](docs/PLAN.md) | Mimari, veri modeli, ekranlar, klavye mimarisi, fazlar, doğrulama |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Alınan kararlar, gerekçeleri, elenen alternatifler, ertelenenler |
| [docs/DESIGN.md](docs/DESIGN.md) | "E-ink" görsel dili: palet, tipografi, anlam sözlüğü, bileşen kuralları |
| [docs/api.md](docs/api.md) | İki uygulamanın da uyduğu API sözleşmesi (`curl` örnekleriyle) |
| [docs/data-model.md](docs/data-model.md) | Koleksiyonlar ve alanlar |
| [backend/README.md](backend/README.md) | Backend'i çalıştırma, testler, sürüm yükseltme |
| [macos/README.md](macos/README.md) | Mac uygulaması: çalıştırma, kısayollar, mimari, yeni aksiyon/görünüm ekleme rehberi |
| [docs/DEPLOY.md](docs/DEPLOY.md) | *(yalnızca `main`)* Sunucu kurulumu |

```
backend/   PocketBase (Docker) + pb_hooks iş mantığı + testler
macos/     Swift + SwiftUI uygulaması: Core (API paketi) + TaskTracker (arayüz)
scripts/   setup-local.sh (backend), install-mac.sh (Mac uygulaması), make-icon.py; main'de ayrıca deploy.sh, migrate-data.sh
docs/      plan, kararlar, tasarım, API sözleşmesi
```

## Durum

| Faz | Durum |
|---|---|
| 0 · İskelet | ✅ |
| 1 · Backend | ✅ birim 39/39, API 19/19 |
| 2 · macOS | ✅ tüm görünümler (Odak, Triyaj, Hafta, Kanban, Projeler, Notlar), hızlı ekleme `⌃⌥Space`, hızlı not `⌃⌥N`, yüzen mini/liste paneli `⌃⌥M` / `⌃⌥L`, zamanlayıcı, `⌘K` komut paleti, `?` yardım, menü çubuğu öğesi, tam ekran, otomatik başlama. Core paketi 19/19. |
| 4 · Deploy | ✅ sunucu katmanı `main`'de — Cloudflare Tunnel + API anahtarı |
| 3 · Android | ertelendi |

Bilinen eksikler ve sıradakiler: [macos/README.md](macos/README.md) → Sıradakiler.
