> Durum ve devam adımları: [../README.md](../README.md) · Karar gerekçeleri: [DECISIONS.md](DECISIONS.md) · Görsel dil: [DESIGN.md](DESIGN.md) · API: [api.md](api.md)

# Kişisel Task + Not Sistemi — Custom Geliştirme Planı

## Context

Todoist (ve genel olarak hazır araçlar) zamanla yetmiyor; hedef, **tamamen modifiye edilebilir, kendi server'ında çalışan kişisel bir sistem**. İhtiyaçlar:

- **Not alanı:** uzun dönem fikirler, proje notları, "ne yapmak istiyoruz / nasıl yapacağız" detayları.
- **Task alanı:** iş + kişisel günlük task'lar; hızlı ve geçici yazılabilmeli, task'a not düşülebilmeli.
- **Çoklu görünüm:** aynı task havuzu farklı anlarda farklı görünümle — bugün/odak, kanban, haftalık yük, proje panoraması.
- **Dashboard kullanımı:** gün içinde bilgisayarın köşesinde ya da telefonda sürekli açık duran odak listesi.
- **Gün sonu triyaj:** bitmeyen task'lar için tek ekranda hızlı karar.

### Verilen kararlar

| Konu | Karar |
|---|---|
| Yaklaşım | Hazır araç değil, custom. (Vikunja değerlendirildi: task tarafı güçlü ama not kavramı, triyaj ve dashboard modu yok; şema onların.) |
| Backend | **PocketBase**, `<sunucu>` üzerinde Docker |
| İstemciler | **İki ayrı native uygulama** — platform başına yoğun özelleştirme yapılacağı için. **macOS: Swift + SwiftUI (kesinleşti)**; Android teknolojisi Mac tasarımı netleşince ayrıca kararlaştırılacak. **Önce Mac.** |
| Not ↔ Task | İki ayrı alan, gevşek bağ |
| Offline | Yok — online yeterli |
| Erişim | ~~Yalnızca Tailscale~~ → Cloudflare Tunnel (`tasks.example.com`) + API anahtarı — [DEPLOY.md](DEPLOY.md) |
| Görsel dil | **"E-ink"**: açık + ters koyu mod, saf monokrom, monospace, hareketsiz → [DESIGN.md](DESIGN.md) |

### Ortam tespiti

- `<sunucu>` 2026-09-20 akşamı itibarıyla **online** (Tailscale SSH: `ssh <sunucu>`); Docker sürümü ve boş portlar henüz incelenmedi. Geliştirme yine de yerelde, Mac'teki Docker ile başlar; deploy Faz 4'te.
- **Xcode 27.0** (lisans kabul edildi), Swift 6.4 ve XcodeGen kurulu — Mac fazının ön koşulları hazır.
- Docker bu Mac'te **colima** ile çalışıyor (`colima start`).
- Android Studio + SDK 37 kurulu. Node 24 + pnpm mevcut (parser testleri ve import script'i için).
- Telefonun Tailscale'i 28 gündür kapalı → Android fazında erişim kararı verilecek (aşağıda).

---

## Temel tasarım ilkesi: ince istemci, akıllı server

İki ayrı kod tabanı olduğundan, **ortak her mantık bir kez, server'da yazılır**; istemciler yalnızca sunum + platforma özgü yeteneklerle ilgilenir. PocketBase'in `pb_hooks` (JS) mekanizması bunun için kullanılır:

- `POST /api/quickadd` — ham metni alır, parse eder, task'ı oluşturur. Parser tek yerde; Swift ve Kotlin'de tekrar yazılmaz. Bonus: `curl`, macOS Shortcuts, ileride CLI — hepsi aynı endpoint'i kullanır.
- `POST /api/quickadd/preview` — yazarken canlı önizleme (neyin tarih/öncelik/proje algılandığı).
- `POST /api/quicknote` (+ `/preview`) — hızlı not: ilk satır başlık, `#proje` bağ, kalanı gövde.
- `GET /api/views/focus` (açık task'lar + bugün bitenler), `GET /api/views/week`, `GET /api/views/projects` — odak listesi, haftalık yük ve proje panoraması gibi toplu hesaplar server'da; istemci hazır JSON'u çizer. "Bugün"ün ne olduğuna da server karar verir (`TZ`).
- `POST /api/triage/:id` — `tomorrow | date | to_project | delete` aksiyonları tek noktadan.
- `GET /api/focus`, `POST /api/focus/:id`, `/api/focus/clear`, `/api/focus/timer` — aktif task ve zamanlayıcı durumu.

PocketBase'in resmî SDK'ları JS ve Dart; Swift/Kotlin için resmî SDK yok. REST yüzeyi küçük olduğundan her platformda **ince bir kendi API istemcimiz** yazılır (auth token, CRUD, SSE ile realtime). API sözleşmesi `docs/api.md`'de tek kaynak olarak tutulur — iki uygulama da ona göre yazılır.

## Mimari

```
<sunucu> (Docker)                         İstemciler
┌───────────────────────────────┐             ┌─ macOS · SwiftUI
│ PocketBase (sürüm pinli)      │             │   menü çubuğu · global hotkey hızlı ekleme
│  SQLite · Auth · REST · SSE   │◄── HTTPS ──┤   her zaman üstte yüzen dashboard paneli
│  pb_migrations/  (şema)       │ (Tailscale  │
│  pb_hooks/       (iş mantığı) │   Serve)    └─ Android · Kotlin + Compose
└───────────────────────────────┘                 ana ekran widget'ı · ekranı açık tutan dashboard
```

### Veri modeli

| Koleksiyon | Alanlar |
|---|---|
| `projects` | `name`, `area` (`work`/`personal`), `status` (`active`/`on_hold`/`done`), `description` — renk alanı yok (saf monokrom) |
| `tasks` | `title`, `description` (markdown, opsiyonel), `area`, `project?` → projects, `status` (todo/doing/blocked/done), `priority` (1–4), `scheduled_date?`, `due_date?` (saat dilimsiz `YYYY-MM-DD` metni), `sort_order`, `completed_at?`, `note?` → notes |
| `notes` | `title`, `body` (markdown), `project?` → projects, `tags[]`, `pinned` |
| `focus_state` | tek kayıt: `current_task?` → tasks, `timer_started_at?`, `timer_duration?` (aktif task + zamanlayıcı; tüm istemcilerde ortak) |

- **Geçici günlük task** = `project` boş + `scheduled_date` bugün. Ayrı tip değil; triyajda projeye taşınarak kalıcılaşır.
- **Gevşek bağ** = opsiyonel `tasks.note`; not ekranında bağlı task'lar geri-bağlantı olarak listelenir.
- API kuralı: tüm koleksiyonlar yalnızca giriş yapmış tek kullanıcıya açık. Kayıt kapalı.
- Ayrıntı: [data-model.md](data-model.md)

### Ekranlar (her iki uygulamada, platforma göre uyarlanmış)

| Ekran | Davranış |
|---|---|
| **Odak** | `scheduled_date ≤ bugün ∧ status ≠ done`, `sort_order` sıralı; iş/kişisel filtresi; üstte hızlı ekleme. |
| **Dashboard** | Odak'ın sade, sürekli açık hali; realtime (SSE) ile canlı. Mac: yüzen panel (`NSPanel`, `.floating`). Android: `FLAG_KEEP_SCREEN_ON`. |
| **Triyaj** | Bugün bitmeyenler tek tek: yarına · tarih seç · projeye taşı · sil. Mac'te tamamen klavyeyle (`1`–`4`), Android'de kaydırma hareketleriyle. |
| **Hafta** | 7 gün, gün başına yük göstergesi, günler arası taşıma. |
| **Kanban** | `status` sütunları, sürükleyerek durum değiştirme. |
| **Projeler** | Açık task sayısı + ilerleme; detayda task'lar ve notlar. |
| **Notlar** | Liste + markdown editör; proje/etiket filtresi; sabitleme. |

**Hızlı ekleme sözdizimi** (Türkçe destekli): `Faturayı öde yarın son:cuma !1 #finans @kişisel // IBAN gelen kutusunda` — `bugün/yarın/pzt…` (başlama), `son:<tarih>` (bitiş), `!1–4`, `#proje`, `@iş/@kişisel`, `// açıklama`; tüm satır tırnak içindeyse parse kapalı. Ayrıntı: [api.md](api.md).

---

## Uygulama adımları

Repo: `/Users/<kullanıcı>/Desktop/software_projects/task_tracker`

```
backend/   Dockerfile · docker-compose.yml · pb_migrations/ · pb_hooks/ (main, quickadd, views, triage, focus, tasks + lib/) · tests/unit · tests/api
macos/     SwiftUI uygulaması (Xcode projesi)
android/   Kotlin + Compose uygulaması (Gradle projesi)
scripts/   import-todoist.ts
docs/      api.md (tek sözleşme) · data-model.md · DESIGN.md · PLAN.md · DECISIONS.md
```

### Faz 1 — Backend (yerelde, Docker) — ✅ tamamlandı (2026-09-20)
1. Pinli PocketBase compose'u; `pb_data` named volume; port yalnızca `127.0.0.1`.
2. Koleksiyonların (`projects`, `notes`, `tasks`, `focus_state`) migration'ları + API kuralları + tek kullanıcı.
3. `lib/parser.js` saf fonksiyon olarak; Node test runner ile birim testleri (Türkçe tarih sözcükleri, öncelik, proje, alan, tırnak kaçışı).
4. `pb_hooks` endpoint'leri: quickadd, preview, views, triage, focus + task kayıt kuralları (`completed_at`, aktif task'ı boşaltma).
5. `docs/api.md` — iki uygulamanın da uyacağı sözleşme; her endpoint için `curl` örneği.

*Sistem `curl` ile uçtan uca kullanılabilir durumda — istemciler bunun üzerine gelir. Çalıştırma ve testler: [../backend/README.md](../backend/README.md).*

### Faz 2 — macOS uygulaması (ön koşul: Xcode kurulumu)

**Teknoloji kararları**
- **Swift + SwiftUI**, hedef **yalnızca macOS 26** (kişisel kullanım; en yeni API'ler serbest). Gerektiği yerde AppKit (`NSPanel`).
- Proje dosyası metin tabanlı: **XcodeGen** (`macos/project.yml`) → Xcode açmadan Zed'de yazılır, terminalden `xcodebuild` ile derlenir.
- Mimari: `@Observable` store'lar · `async/await` + `URLSession` ile ince API istemcisi · realtime için `URLSession.bytes` üzerinden SSE.
- Bağımlılıklar minimum: global hotkey için `KeyboardShortcuts` (kullanıcı tarafından yeniden atanabilir kısayollar); gerisi platform.
- Not editörü v1: düz metin markdown + yan yana render önizleme. WYSIWYG sonraya.
- İmzalama: ücretli Apple Developer hesabı **yok** → yerel imzayla ("Sign to Run Locally") yalnızca bu Mac'te çalışır. Bir özellik hesabı gerçekten gerektirirse o noktada haber verilir.

**Uygulama formu**
- Dock ikonlu normal uygulama **+** menü çubuğu öğesi. Pencere kapatılınca arka planda yaşamaya devam eder.
- **Oturum açılışında otomatik başlar** — macOS'in yerleşik login item API'si (`SMAppService.mainApp`), ayarlardan aç/kapa. (systemd muadili; ayrı bir servis/daemon gerekmez.)
- Tüm kısayollar ayarlar ekranından yeniden atanabilir. *Ek kısayol ve tasarım detayları geliştirme sırasında, gerçek kullanımdan gelen isteklerle eklenir (bkz. "Çalışma biçimi").*

**Yüzen paneller** (`NSPanel`, her zaman üstte, odağı çalmaz, tüm masaüstlerinde, konumu hatırlanır)
1. **Mini panel — tek task odaklı:** o an üzerinde çalışılan task'ı gösterir. Hotkey ile **genişler** → task detayları (notlar, proje, tarih, öncelik) görünür; tekrar basınca daralır.
2. **Liste paneli:** bugünün task'ları; tıklayarak tamamlama, bir task'ı "şu an bunu çalışıyorum" olarak işaretleme.
- İkisi **aynı köşeyi paylaşır**: liste paneli açılınca mini panelin yerini alır, `Esc` ile mini panele dönülür (aynı anda ikisi görünmez). Hotkey ile geçiş; ayrı bir hotkey ile gizle/göster. Konum ve ölçüler: [DESIGN.md](DESIGN.md) → Yerleşim.

**Hızlı ekleme paneli**
- Global hotkey ile her yerden açılır, canlı parse önizlemesi gösterir.
- **Enter = ekle, kutu açık kalır** (arka arkaya giriş); **Esc = kapat**.
- **Tab = çok satırlı açıklama alanı** (opsiyonel); kısa notlar satır içinde `// …` ile.

**Aktif task + zamanlayıcı**
- Aktif task **elle seçilir**; tamamlanınca mini panel **boş kalır** ("sıradaki ne?"), otomatik atama yok.
- Durum server'da tek kayıt olarak tutulur (`focus_state`: `current_task`, `timer_started_at`, `timer_duration`) → Mac'te seçilen aktif task ve çalışan zamanlayıcı telefonda da aynı görünür. Endpoint'ler: `POST /api/focus/:id`, `POST /api/focus/clear`, `POST /api/focus/timer` (start/stop).
- **Zamanlayıcı görseli rakam değil, geriye doğru azalan bir ilerleme çubuğu.** Mini panelde bunun için ikon/buton **yok**; yalnızca hotkey ile başlatılır.
- Süre girişi: `T` → dakika yaz → `Enter` (çalışırken `T` = durdur). Süre dolunca: **kısa ses + macOS bildirimi** (panel gizliyken de haber verir); akışı kesen soru yok.
- Oturum geçmişi (`focus_sessions`) şimdilik kaydedilmez; model sonradan eklemeye uygun.

**Klavye mimarisi — sistemin ana etkileşim biçimi** *(taslak; kullanıcı onayı ve eklemeleri bekleniyor)*

İlke: fare hiçbir akış için zorunlu olmaz. Panellerde görünür buton/ikon minimumda tutulur; her aksiyon bir tuşa bağlıdır.

**Merkezi aksiyon kaydı (`ActionRegistry`) — ilk günden kurulur.** Her aksiyon tek yerde tanımlanır: `id`, görünen ad, bağlam (mini panel / liste / ana pencere / global), varsayılan tuş, handler. Panel tuşları, `⌘K` komut paleti, `?` kısayol listesi ve ayarlar ekranı **bu tek listeden türer**. Sonuçları:
- Yeni akış eklemek = kayda birkaç satır; palette/ayarlarda/yardımda kendiliğinden görünür. Kısayollar bu yüzden **önceden tek tek belirlenmez, geliştirme sırasında kullanıma göre eklenir.**
- **Her aksiyona ayarlardan isteğe bağlı global kısayol atanabilir** → model varsayılan olarak katmanlıdır; kullanıcı sık kullandığı aksiyonu (örn. "aktif task'ı tamamla") kod değişmeden doğrudan global'e terfi ettirir.

**Mini panel halleri:** *pasif* (görünür, klavyeyi dinlemez) → global hotkey → *dinliyor* (kenarlık yanar) → `E` → *geniş* (detaylar). `H` gizler. Liste paneli mini panelin yerinde açılır ve doğrudan dinler; `P` ile sabitlenirse pasif dashboard olarak köşede kalır, `Esc` ile mini panele döner.

- *Katman 1 — Global (her uygulamadan; az sayıda, modifier'lı):* hızlı ekleme · mini panel (göster + odağı ver / gizle) · liste paneli · ana pencere.
- *Katman 2 — Panel odaktayken tek tuş (modifier'sız):* global hotkey, **uygulama değiştirmeden** klavye odağını panele verir (Spotlight davranışı: `NSPanel` + `.nonactivatingPanel` — öndeki uygulama önde ve görünür kalır, ana pencere açılmaz, masaüstü değişmez). Panel dinlerken ince bir kenarlıkla belli eder. **Tek atımlık aksiyonlardan** (`D`, `T`+süre, aktif task seçimi) sonra odak **otomatik olarak** önceki uygulamaya döner; `E` gibi "bakma" modlarında `Esc`'e kadar panelde kalır.
  - Mini panel: `E` detayları genişlet/daralt · `T` zamanlayıcı · `D` tamamla · `Space` aktif task seç (liste açılır) · `N` task'a not düş · `Esc` geri dön
  - Liste paneli: `↑↓`/`J K` gezin · `Enter` aktif yap · `D` tamamla · `⌘↑/⌘↓` sırala · `1–4` öncelik · `Y` yarına at · `Tab` iş/kişisel · `/` filtre
- *Katman 3 — Ana pencere:* `⌘1…⌘6` görünümler · `⌘N` task · `⌘⇧N` not · triyajda `1–4` · **`⌘K` komut paleti** (her aksiyon adıyla aranabilir → %100 klavye kapsaması) · `?` o ekrana özel kısayol listesi.

**Sıra**
1. ✅ *(2026-09-20)* Proje iskeleti (XcodeGen) + `Theme` (DESIGN.md belirteçleri) + API istemcisi + giriş + `ActionRegistry` + Odak ekranı + hızlı ekleme paneli + Ayarlar (sunucu adresi, görünüm, kısayol listesi) → **gerçek kullanıma geçiş noktası**. Uygulama belgesi: [../macos/README.md](../macos/README.md)
2. ✅ *(2026-09-20)* Menü çubuğu öğesi + login item + kısayol ayarları + `⌘K` komut paleti + `?` yardım + tam ekran (`⌃⌘F`)
3. ✅ *(2026-09-20)* Yüzen paneller (mini → liste) + aktif task + zamanlayıcı çubuğu (`N` not düşme hariç — ertelendi)
4. ✅ *(2026-09-21)* Triyaj → Hafta → Kanban → Projeler → Notlar
5. ✅ *(2026-09-21)* Task düzenleme katmanı (`E` → `E`) + mini panelde `N` ile not düşme

**Çalışma biçimi:** her adım sonunda uygulama kullanılır durumda teslim edilir; kullanıcı gerçek kullanımdan yeni akış/kısayol/tasarım istekleriyle gelir, bunlar bir sonraki adıma girmeden önce işlenir. Görsel dilin ilkeleri [DESIGN.md](DESIGN.md)'de sabit ("E-ink"); tonlar, ölçüler ve yerleşim 1. adımda oradaki varsayılanlarla başlar, kullanım sırasında birlikte ayarlanır.

### Faz 3 — Android uygulaması
1. API istemcisi (OkHttp + SSE) + Odak + hızlı ekleme.
2. Dashboard modu (ekran açık kalır) + ana ekran widget'ı (Glance).
3. Triyaj (kaydırma hareketleri) → Hafta → Kanban → Projeler → Notlar.
4. **Erişim kararı bu fazda verilir:** telefonda Tailscale always-on **ya da** hazırdaki Cloudflare Tunnel (`example.com`) ile yalnızca bu servisi yayınlama.

Faz 2 ve 3 yalnızca `docs/api.md`'ye bağımlı; sıraları değiştirilebilir ya da paralel yürütülebilir.

### Faz 4 — Deploy ve geçiş — ✅ *(2026-09-21)*: altyapı + veri taşıma

> Aşağıdaki ilk plan `tailscale serve` öngörüyordu; uygulanan kurulum Cloudflare Tunnel + API anahtarıdır → [DEPLOY.md](DEPLOY.md). Kalan: sunucu dışı yedek, Todoist import'u.

1. `<sunucu>` ayağa kalkınca: compose + migrations + hooks aktarımı, `tailscale serve` ile tailnet içi gerçek HTTPS, `pb_data` için zamanlanmış yedek.
2. Uygulamalarda server adresi ayarlardan değiştirilebilir (yerel → `https://<sunucu>.<tailnet>.ts.net`).
3. `scripts/import-todoist.ts` — Todoist REST API → PocketBase. Todoist hesabı geçiş tamamlanana kadar silinmez.

**Kapsam dışı (şimdilik):** offline/sync, çoklu kullanıcı, web arayüzü (PocketBase admin UI ham veri tarayıcısı olarak yeterli), iOS.

---

## Doğrulama

- **Backend** *(✅ `pnpm test` 30/30, `pnpm test:api` 17/17)*: `docker compose up` → admin UI açılıyor, koleksiyonlar migration'dan oluşmuş. Parser testleri geçiyor. `docs/api.md`'deki her `curl` örneği beklenen yanıtı veriyor; giriş yapılmadan tüm endpoint'ler `401/403` dönüyor.
- **Realtime:** `curl` ile eklenen task, açık uygulamadaki Odak/Dashboard'da yenilemeden beliriyor.
- **macOS:** global hotkey başka bir uygulama öndeyken paneli açıyor; satır yazıp Enter → task oluşuyor; dashboard paneli tam ekran olmayan tüm pencerelerin üstünde kalıyor.
- **Android:** dashboard modunda ekran kapanmıyor; widget güncel odak listesini gösteriyor; Mac'ten eklenen task telefonda saniyeler içinde görünüyor.
- **Triyaj:** `scheduled_date` dün olan bitmemiş task triyajda çıkıyor; "yarına" aksiyonu tarihi doğru güncelliyor.
- **Deploy:** tailnet adresi geçerli sertifikayla açılıyor; Tailscale kapalıyken erişilemiyor; yedek dosyası oluşuyor ve geri yüklenebiliyor.

## Kaynaklar

- [PocketBase](https://github.com/pocketbase/pocketbase) · [Releases](https://github.com/pocketbase/pocketbase/releases) · [JS SDK (referans)](https://github.com/pocketbase/js-sdk)
- Değerlendirilip elenen: [Vikunja](https://vikunja.io/features) · [Vikunja vs Todoist](https://vikunja.io/compare/todoist/) · [isitreallyfoss](https://isitreallyfoss.com/projects/vikunja/) · [awesome-selfhosted](https://awesome-selfhosted.net/tags/task-management--to-do-lists.html)
