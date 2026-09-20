# Karar Günlüğü

Planlama oturumunda (2026-09-20) alınan kararlar, gerekçeleri ve elenen alternatifler. Yeni kararlar en alta tarihle eklenir. Uygulama planının kendisi: [PLAN.md](PLAN.md).

---

## 1. Hazır araç değil, custom sistem

**Karar:** Kendi sistemimizi yazıyoruz; hazır bir task aracını benimsemiyoruz.

**Gerekçe:** Çıkış noktası "hazır araçlar bir süre sonra yetmiyor, gerektiğinde değiştirebileyim". İhtiyaç listesi (not alanı + hızlı geçici task'lar + çoklu görünüm + köşede dashboard + gün sonu triyaj + aktif task/zamanlayıcı) hiçbir hazır araçta bir arada yok.

**Değerlendirilip elenenler:**
- **Vikunja** — en güçlü adaydı (AGPLv3, API-first, Go + Vue, Android app, CLI, CalDAV, Todoist import). Elenme nedeni: **not kavramı yok** (yalnızca task açıklaması), triyaj ve dashboard modu yok, şema onların → notları eklemek fork gerektirir. Ayrıca Quick Add Magic parser'ı istemci tarafında; API'de yok.
- **Taskwarrior** — Android tarafı zayıf. **Planka / Kanboard** — saf kanban, mobil ve CLI yok. **Super Productivity** — mobil PWA seviyesinde. **Donetick** — ev işleri odaklı, fazla minimal.
- **Raycast eklentisi** fikri de elendi: makinede kurulu değil, kapalı kaynak, ve custom yolda gereksiz.

## 2. Backend: PocketBase

**Karar:** Self-hosted PocketBase; şema tamamen bizim (`projects`, `tasks`, `notes`, `focus_state`).

**Gerekçe:** Auth, REST, realtime (SSE), admin UI ve yedekleme hazır geliyor; tek binary, Docker'da dakikalar içinde kalkıyor. Realtime kritik: Mac'te yapılan değişiklik telefondaki dashboard'da anında görünmeli.

**Risk ve önlem:** Henüz v1.0 değil → sürüm compose'da **pinlenir**, şema `pb_migrations/` altında repoda tutulur.

**Elenenler:** Express + Postgres (bilinen stack ama auth/realtime/migration/admin'i elle yazmak gerekir) · Vikunja API + ayrı not deposu (iki backend, şema kısıtı).

## 3. İnce istemci, akıllı server

**Karar:** Ortak her iş mantığı PocketBase `pb_hooks` (JS) içinde **bir kez** yazılır: hızlı ekleme parser'ı (`/api/quickadd`, `/preview`), toplu görünümler (`/api/views/*`), triyaj aksiyonları (`/api/triage/:id`), aktif task + zamanlayıcı (`/api/focus/*`).

**Gerekçe:** İki ayrı native kod tabanı var; mantığı Swift ve Kotlin'de iki kez yazmak bakım yükünü ikiye katlar. Yan fayda: aynı endpoint'ler `curl`, macOS Shortcuts ve ileride CLI'dan da çalışır. İki uygulama tek sözleşmeye (`docs/api.md`) göre yazılır.

## 4. İstemciler: iki ayrı native uygulama

**Karar:** macOS ve Android için ayrı native uygulamalar. (Kullanıcı kararı — her platformda yoğun özelleştirme yapılacak.)

**Elenen:** Tek React PWA (önerilmişti; tek kod tabanı avantajına rağmen platforma özgü özelleştirme isteği nedeniyle reddedildi).

## 5. macOS: Swift + SwiftUI

**Karar:** Swift + SwiftUI (gerektiğinde AppKit/`NSPanel`), hedef yalnızca macOS 26, proje dosyası XcodeGen ile metin tabanlı.

**Gerekçe:** Gün içinde en sık dokunulan özellikler — global hotkey, odağı çalmayan yüzen panel (Spotlight davranışı), menü çubuğu, ileride masaüstü widget'ı — platformun kendi API'leri. Bütün gün açık kalacak uygulama için en düşük kaynak tüketimi.

**Bilinen bedel:** Xcode kurulumu gerekir; Swift kullanıcı için yeni bir dil; kanban ve markdown editör web'e göre daha çok emek ister (editör v1'de düz metin + önizleme).

**Elenenler:** Tauri (React UI bilinen dil ve büyük görünümler hızlı çıkar; ama widget yok, Spotlight-benzeri panel topluluk eklentisine bağlı) · Electron (200–300 MB RAM) · Compose Desktop (hotkey/menü çubuğu zayıf, JVM).

## 6. Ürün davranışı kararları

| Konu | Karar |
|---|---|
| Not ↔ Task ilişkisi | İki ayrı alan, gevşek bağ (opsiyonel `tasks.note`) |
| Geçici günlük task | Ayrı tip değil: projesiz + bugüne planlı task |
| Gün sonu | **Hızlı triyaj** ekranı: yarına / tarih seç / projeye taşı / sil |
| Görünümler | Odak, Dashboard, Triyaj, Hafta, Kanban, Projeler, Notlar — hepsi gerekli, farklı anlarda |
| Offline | Yok; online yeterli |
| Mac uygulama formu | Dock ikonlu normal uygulama + menü çubuğu; pencere kapanınca arka planda yaşar; **oturum açılışında otomatik başlar** (`SMAppService`) |
| Dashboard | Yüzen panel, iki biçim: **mini** (tek aktif task, hotkey ile detaylara genişler) ve **liste** (bugünün task'ları) |
| Aktif task | **Elle seçilir**; tamamlanınca panel **boş kalır** |
| Zamanlayıcı | Rakam değil, **geriye azalan çubuk**; panelde ikon yok, yalnızca hotkey; `T` → dakika → `Enter`; bitince kısa ses + macOS bildirimi |
| Hızlı ekleme | Enter ekler ve kutu **açık kalır**; Esc kapatır |
| Etkileşim ilkesi | **Klavye-öncelikli**: akışların çoğu hotkey üzerinden |

## 7. Klavye mimarisi

**Karar:** Katmanlı model + merkezi aksiyon kaydı (`ActionRegistry`).
- Katman 1: az sayıda global kısayol (hızlı ekleme, mini panel, liste paneli, ana pencere).
- Katman 2: panel "dinlerken" modifier'sız tek tuşlar. Global hotkey **uygulama değiştirmeden** klavye odağını panele verir; tek atımlık aksiyonlardan sonra odak otomatik önceki uygulamaya döner.
- Katman 3: ana pencere kısayolları + `⌘K` komut paleti + `?` yardım.

**Gerekçe:** Her aksiyona ayrı global kısayol çakışma ve ezber sorunu yaratır. Aksiyon kaydı sayesinde palet, ayarlar ve yardım tek listeden türer; **her aksiyona ayarlardan isteğe bağlı global kısayol atanabilir**, böylece "saf katmanlı mı, doğrudan global mi" kararı kullanım sırasında aksiyon bazında verilir.

**Süreç kararı:** Tekil kısayollar ve görsel tasarım önceden tüketilmez; her geliştirme adımı kullanılabilir sürüm teslim eder, yeni akışlar gerçek kullanımdan gelir.

## 8. Erişim ve altyapı

- Sunucu: `<sunucu>` (Tailscale `<ip>`, Tailscale SSH ile erişim). `~/.ssh/config`'deki Cloudflare Tunnel hostname'i (`server.example.com`) DNS'te çözülmüyor.
- ~~Erişim şimdilik yalnızca Tailscale; public yüzey yok.~~ → **madde 14 ile değişti** (Cloudflare Tunnel + API anahtarı). Tailscale artık yalnızca sunucuya SSH için.
- Apple Developer hesabı yok → yerel imza; bir özellik gerçekten gerektirirse alınır.

## 9. Görsel dil: "E-ink" *(2026-09-20)*

**Karar:** Bütün uygulama e-mürekkep ekran estetiğinde, aşırı minimalist. Üç alt karar: **açık + ters koyu mod** (sistem görünümünü izler) · **saf monokrom** (hiç renk yok) · **monospace** tipografi. Kurallar: [DESIGN.md](DESIGN.md).

**Gerekçe:** Kullanıcı tercihi. Klavye-öncelikli, metin ağırlıklı, bütün gün köşede duran bir araçla örtüşüyor: dikkat çekmez, hızlı ekleme sözdizimi (`!1 #proje @alan`) arayüzün kendi dili olur, monospace ızgara hizalamayı bedavaya getirir.

**Sonuçları:** `projects.color` alanı şemadan çıkarıldı. Öncelik/durum/gecikme/seçim renk yerine ağırlık, glif ve ters çevirmeyle anlatılır. Gölge, blur, saydamlık, animasyon yok → PLAN'daki "panel saydamlığı" seçeneği düştü.

**Elenenler:** yalnızca açık mod (gece parlak) · tek vurgu rengi ya da mat proje renkleri (monokromu sulandırır) · serif / sans / karışık tipografi.

## 10. Backend uygulama kararları *(2026-09-20, Faz 1)*

| Konu | Karar | Gerekçe |
|---|---|---|
| Docker imajı | Kendi `Dockerfile`'ımız: Alpine + resmî release zip'i, sürüm pinli (v0.40.4), checksum doğrulamalı | PocketBase'in resmî imajı yok; topluluk imajına güvenmek yerine resmî binary. Mimari `uname -m`'den okunur → aynı dosya Mac'te (arm64) ve sunucuda (amd64) çalışır. |
| Gün alanları | `scheduled_date` / `due_date` saat dilimsiz `YYYY-MM-DD` **metni** | Datetime alanı UTC'ye çevrilince İstanbul'da gün kayar. Metin sözlük sırasıyla doğru karşılaştırılır. |
| "Bugün" otoritesi | Server (`TZ=Europe/Istanbul`); yanıtlarda `today` döner | İki istemci gece yarısında farklı "bugün" görmesin. `GET /api/views/focus` bu yüzden eklendi. |
| Enum değerleri | DB'de İngilizce (`work/personal`, `active/on_hold/done`); Türkçe yalnızca arayüzde ve parser sözlüğünde | Kod tanımlayıcılarıyla tutarlı, ASCII. |
| Quickadd varsayılan tarihi | Tarihsiz + projesiz → bugün; projeli + tarihsiz → plansız | "Geçici günlük task" tanımının doğrudan karşılığı; projeli task birikime düşer. |
| Bilinmeyen `#proje` | Task yine oluşur, `#…` başlıkta kalır, uyarı döner | Hızlı girişte veri kaybı ve akışı kesen hata olmasın; yazım hatası çöp proje üretmesin. |
| `to_project` triyajı | `scheduled_date` boşalır (opsiyonel `date` ile kurulabilir), alan projeden alınır | Tarih kalsaydı task ertesi gün yine triyaja düşerdi. |
| Girişsiz istekler | Koleksiyon uçları dahil hepsi `401` (global middleware) | PocketBase varsayılanı kural tutmayınca `200 + boş liste` döner; sözleşme tek tip olsun. |
| `focus_state` | REST'ten salt-okunur; yalnızca `/api/focus/*` yazar | Tutarlılık kuralları (task değişince zamanlayıcı sıfırlanır vb.) tek yerde. |
| Zamanlayıcı süresi | Saniye cinsinden saklanır; server tıklamaz | İstemci `started_at + duration`'dan hesaplar; dakika girişi istemcinin işi. |

## 11. Task açıklaması ve bitiş tarihi hızlı eklemede *(2026-09-20)*

**Karar:** Task = başlık + opsiyonel açıklama. Hızlı eklemede açıklamanın iki yolu var: satır içinde `// …` (parser, server'da) ve panelde `Tab` ile açılan çok satırlı alan (`description` gövde alanı). Bitiş tarihi için `son:<tarih>` token'ı eklendi → bir task'ın hem **ne zaman başlanacağı** (`scheduled_date`) hem **ne zamana bitmesi gerektiği** (`due_date`) tek satırda yazılabiliyor. `tasks.notes` → `tasks.description` olarak yeniden adlandırıldı.

**Gerekçe:** Kullanıcı isteği — tasarım incelemesinde hızlı eklemeden detay yazılamadığı fark edildi. `//` tek satırlık akışı (`curl`, Shortcuts, Android) bozmadan çalışır; `Tab` alanı çok satırlı yazı için. İkisi birlikte gelirse birleştirilir, girdi kaybolmaz. Eski `notes` adı hem `notes` koleksiyonuyla hem `tasks.note` ilişkisiyle karışıyordu.

**Tarih çözümü deterministik kalır** (sözlük + takvim aritmetiği), AI yok: her tuş vuruşunda çalışan önizleme için hız, öngörülebilirlik ve dışa bağımsızlık gerekiyor. Yeni kalıplar (`haftaya salı`, `3 gün sonra`…) ihtiyaç çıktıkça sözlüğe + teste eklenir.

**Elenenler:** yalnızca `Tab` alanı (tek satırlık istemciler açıklama ekleyemezdi) · yalnızca `//` (çok satır yazılamaz) · ayrı "özet" ve "detay" alanları (tek markdown alanı yeterli; kalıcı uzun içerik için Notlar + `tasks.note` bağı var).

## 12. macOS uygulama kararları *(2026-09-20, Faz 2 adım 1)*

| Konu | Karar | Gerekçe |
|---|---|---|
| Katmanlama | `macos/Core` (Swift paketi: modeller, API, realtime — arayüzsüz) + `macos/TaskTracker` (SwiftUI) | Core `swift test` ile, çalışan backend'e karşı da sınanıyor; arayüz otomasyonu olmadan sözleşme güvencesi. |
| İstemci durumu | İyimser güncelleme yok: her aksiyondan sonra ve her realtime olayında liste sunucudan yeniden çekilir | Tek doğruluk kaynağı sunucu; yerel ağda gecikme fark edilmez, tutarsızlık sınıfı ortadan kalkar. |
| Token saklama | `UserDefaults` (Keychain değil); parola saklanmaz | Ad-hoc imzada Keychain her derlemede izin soruyor. Tek kullanıcılı Mac + tailnet içi sunucu için kabul edilebilir. |
| Eşzamanlılık | Swift 6, uygulama modülünde varsayılan ana aktör; Core'da `Sendable` değer tipleri | Arayüz kodunda aktör gürültüsü yok, derleyici veri yarışlarını yine de denetliyor. |
| Global kısayol | Her aksiyonun atanabilir bir global yuvası var; varsayılanlar yalnızca `⌃⌥Space` (hızlı ekleme) ve `⌃⌥T` (ana pencere) | PLAN'daki "aksiyonu kod değiştirmeden global'e terfi ettir" ilkesi. `⌥Space` başka araçlarla çakıştığı için seçilmedi. |
| Ayarlar | Ayrı pencere değil, ana pencerede bir görünüm (`⌘,`) | Tek pencere, tek görsel dil; kullanıcı isteği "ufak bir ayarlar sekmesi". |
| Odak: bugün bitenler | `GET /api/views/focus` yanıtına `done` eklendi | İlerleme çubuğu (`2/7`) ve BİTEN bölümü için; "bugün"ü yine server belirliyor. |

Tasarımdan bilinen sapmalar (yuvarlak pencere köşesi, blok imleç, kısayol kaydedici kutusu): [../macos/README.md](../macos/README.md) → "Bilinçli kararlar ve tasarımdan sapmalar".

## 13. Projeler, Notlar ve hızlı not *(2026-09-21)*

Tasarım önce tuvalde netleştirildi, sonra uygulandı. Kullanıcı kararları:

| Konu | Karar |
|---|---|
| Projeler | Şimdilik **yalnızca proje + tanım**. Projeye task tanımlama ekranı sonraya (hızlı eklemede `#ad` zaten çalışıyor). |
| Notlar | **Sticky düzen** (kart ızgarası), monokrom: sabit not 2 px çerçeve + `▪ sabit`. Kart boyutu sabit → klavye gezinmesi öngörülebilir. |
| Hızlı not | Global `⌃⌥N`; `↵` kaydeder, `⇧↵` yeni satır (hızlı eklemenin açıklama alanıyla tutarlı, tek düşünceyi en hızlı kaydeder). |
| Ayrıştırma | Sunucuda (`/api/quicknote`): ilk satır başlık, `#proje` bağ. Android aynı endpoint'i kullanır. |
| Kayıt | Tanım ve not editörlerinde kaydet tuşu yok; yazarken otomatik kayıt. |
| Notu task'a bağlama | Ertelendi (`tasks.note` ilişkisi backend'de hazır). |

## 14. Deploy: Cloudflare Tunnel + API anahtarı *(2026-09-21)*

**Karar:** Backend `<sunucu>`'de Docker ile çalışır ve `https://tasks.example.com` adresinden **Cloudflare Tunnel** ile internete açılır. Bu, madde 8'deki "erişim yalnızca Tailscale, public yüzey yok" kararının **yerini alır** (kullanıcı kararı). Koruma: uygulama düzeyinde **API anahtarı** (`X-API-Key`) + oturum + hız sınırlayıcı; yönetim paneli tünelde kapalı. Ayrıntı: [DEPLOY.md](DEPLOY.md).

**Gerekçe:** Sunucuda alan adı ve Cloudflare kurulumu zaten vardı; Tailscale'in Mac'te (ve telefonda) çoğu zaman kapalı olması uygulamayı kullanılamaz kılardı. Bu karar Android'in erişim sorusunu da çözer ("Ertelenen kararlar"daki madde kapandı).

| Konu | Karar | Gerekçe |
|---|---|---|
| Koruma katmanı | Kendi API anahtarımız (`TT_API_KEYS`, cihaz başına bir tane) | Kullanıcı tercihi: kurulum tamamen bizde, Cloudflare paneline bağımlılık yok. **Bedeli:** anahtarsız istek Cloudflare'de değil bizim kodumuzda reddedilir (PocketBase sürecine ulaşır). Bu yüzden kontrol en yüksek öncelikli ara katmandadır, `/_/` ayrıca tünelde kesilir ve hız sınırlayıcı açıktır. |
| Anahtar ne zaman zorunlu | Yalnızca tünelden gelen isteklerde (`CF-Connecting-IP` var) | Yerel geliştirme ve sunucunun kendi loopback'i anahtarsız kalır; port yalnızca `127.0.0.1`'de olduğundan o yola makineye erişimi olan ulaşır. Başlığı taklit etmek kuralı yalnızca sıkılaştırır. |
| Yanıt kodu | `403` (oturum hatası `401`'den ayrı) | Uygulama `401`'de oturumu kapatır; yanlış anahtar oturum sorunu değildir. |
| Tünel | Ayrı tünel (`task-tracker`), compose içinde container olarak | Gitea'nın tüneline dokunulmaz; systemd/`sudo` gerekmez; PocketBase'e compose ağından ulaşır. |
| Veri | `PB_DATA` ile açık klasör (`~/task-tracker/data`) | İmajdan bağımsız; yedek/taşıma düz dosya işi. Yerelde adlandırılmış volume kalır. |
| Kod aktarımı | `rsync` (`scripts/deploy.sh`) | Proje şimdilik yalnızca yerelde; kullanıcı kendi git'ine sonra push edecek. |
| Port | 8091 | 8090 ve 8080 sunucuda başka projelerde. |
| Veri taşıma | Hazır ama **yapılmadı** (`scripts/migrate-data.sh`) | Kullanıcı önce Mac uygulamasını bir hafta yerelde kullanıp iyileştirecek. |

**Elenenler:** `tailscale serve` (Tailscale sürekli açık olmalı) · Cloudflare Access (daha sıkı ama panel kurulumu ister; ileride önüne eklenebilir) · mevcut Gitea tüneline kural eklemek (çalışan tüneli yeniden başlatmak gerekirdi).

## Ertelenen kararlar

- **Android teknolojisi** (Kotlin/Compose varsayılan aday) — Mac tasarımı oturduktan sonra.
- ~~Telefonun server'a erişimi~~ — madde 14 ile çözüldü: Cloudflare Tunnel + cihaza özel API anahtarı.
- Oturum geçmişi (`focus_sessions`), masaüstü widget'ı, WYSIWYG not editörü, offline.
