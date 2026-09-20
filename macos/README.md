# macos

task_tracker'ın macOS uygulaması: Swift 6 + SwiftUI (gerektiği yerde AppKit), hedef yalnızca macOS 26.

- Uyduğu API sözleşmesi: [../docs/api.md](../docs/api.md)
- Görsel dil (her ekranın uyduğu kurallar): [../docs/DESIGN.md](../docs/DESIGN.md)
- Yol haritası: [../docs/PLAN.md](../docs/PLAN.md) → Faz 2

**Durum:** Faz 2 / adım 1–2 tamam — giriş, Odak ekranı, hızlı ekleme paneli, Ayarlar, aksiyon kaydı, tam ekran, menü çubuğu öğesi, otomatik başlama, `⌘K` komut paleti, `?` kısayol yardımı. Sıradakiler en altta.

---

## Çalıştırma

Ön koşullar: Xcode 27 (lisans kabul edilmiş + `xcodebuild -runFirstLaunch` bir kez çalıştırılmış), `brew install xcodegen`, backend ayakta ([../backend/README.md](../backend/README.md)).

```sh
cd macos
xcodegen generate            # project.yml → TaskTracker.xcodeproj (repoya girmez)
xcodebuild -project TaskTracker.xcodeproj -scheme TaskTracker \
  -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/TaskTracker.app
```

- İlk açılışta giriş ekranı gelir: sunucu `http://127.0.0.1:8090`, e-posta ve parola `backend/.env` içindeki `TT_USER_*`.
- Yeni dosya ekleyince ya da `project.yml` değişince `xcodegen generate` yeniden çalıştırılır. Xcode'da açmak istersen: `open TaskTracker.xcodeproj`.
- İmza yerel (ad-hoc): Apple Developer hesabı yok, uygulama yalnızca bu Mac'te çalışır.

## Kullanım

| Nerede | Tuş | Ne yapar |
|---|---|---|
| Her yerden | `⌃⌥Space` | Hızlı ekleme panelini aç / kapat |
| Her yerden | `⌃⌥T` | Ana pencereyi göster |
| Ana pencere | `⌘1`…`⌘6` | Görünümler (şimdilik yalnızca ODAK dolu) |
| Ana pencere | `⌘,` | Ayarlar |
| Ana pencere | `⌘N` | Hızlı ekleme paneli |
| Ana pencere | `⌘K` | Komut paleti: her aksiyon adıyla aranır, `↑↓` seç, `↵` çalıştır, `esc` kapat |
| Ana pencere | `?` | O ekranın kısayol listesi (`?` ya da `esc` kapatır; metin alanı odaktayken çalışmaz) |
| Ana pencere | `⌃⌘F` | Tam ekran aç / kapat (durum hatırlanır; bir sonraki açılış aynı halde başlar) |
| Odak listesi | `↑` `↓` / `J` `K` | Gezin |
| Odak listesi | `↵` | Aktif task yap / bırak (`▸`) |
| Odak listesi | `D` | Tamamla / geri al |
| Odak listesi | `Y` | Yarına at |
| Odak listesi | `1`–`4` | Öncelik |
| Odak listesi | `⇥` | Alan filtresi: hepsi → iş → kişisel |
| Hızlı ekleme | `↵` | Ekle (panel açık kalır) |
| Hızlı ekleme | `⇥` | Çok satırlı açıklama alanı ↔ başlık |
| Hızlı ekleme | `⇧↵` | Açıklamada yeni satır |
| Hızlı ekleme | `esc` | Kapat |

**Menü çubuğu öğesi:** `▸ 3/7` — `▸` aktif task varsa görünür, `3/7` bugün biten / toplam; giriş yapılmamışsa `–`. Menüsünde aktif task, hızlı ekleme, ana pencere, ayarlar ve çıkış vardır. **Ayarlar → Başlangıç**'tan gizlenebilir; aynı yerde "oturum açılışında başlat" anahtarı bulunur (oturum açılışıyla başlayınca pencere açılmaz, uygulama arka planda bekler).

Bu tablonun canlı hali uygulamada **Ayarlar → Kısayollar**'dadır; oradan herhangi bir aksiyona global kısayol da atanır. Pencere kapatılınca (`⌘W`) uygulama arka planda yaşar; `⌘Q` kapatır. Hızlı ekleme sözdizimi: [../docs/api.md](../docs/api.md) → Hızlı ekleme.

---

## Mimari

İki katman:

```
Core/                      Swift paketi — arayüz yok, AppKit/SwiftUI yok
  Models.swift             API kayıtlarının Swift karşılıkları (TaskItem, ParsedInput…)
  APIClient.swift          docs/api.md'nin ince istemcisi (async/await + URLSession)
  Realtime.swift           PocketBase SSE: bağlan → abone ol → olay akışı
  Day.swift                "YYYY-MM-DD" gösterimi ("20.09 Paz")
  Tests/                   birim + çalışan backend'e karşı sözleşme testleri

TaskTracker/               uygulama hedefi
  App/
    TaskTrackerApp.swift   @main, pencere sahnesi, menü komutları, AppDelegate
    AppState.swift         kök durum: oturum, yönlendirme (Route), realtime döngüsü
  Theme/
    Theme.swift            DESIGN.md'nin koddaki tek karşılığı: 4 renk, 3 boyut, çizgiler
    InkViews.swift         ortak yapı taşları: InkTag, InkBar, InkRule, InkHints, InkField, InkButtonStyle
  Actions/
    ActionRegistry.swift   aksiyon kaydı + tuş eşleme
    AppActions.swift       bütün aksiyonların tanımı (tek liste)
  Stores/
    AppSettings.swift      UserDefaults: sunucu adresi, e-posta, token, görünüm
    Backend.swift          güncel APIClient + merkezi hata ele alma
    TodayStore.swift       Odak ekranının durumu ve aksiyonları
    SupportingStores.swift ProjectStore (adlar), ActiveTaskStore (aktif task + zamanlayıcı)
    InkTextView.swift      token vurgulu metin alanı (NSTextView); hızlı ekleme ve palet kullanır
  Features/
    Login/ Main/ Today/ QuickAdd/ Settings/
    Overlays/              PaletteView (⌘K), HelpView (?) — ana pencerenin üstüne açılan katmanlar
    MenuBar/               MenuBarMenu — menü çubuğu öğesinin menüsü
  Support/
    LoginItem.swift        oturum açılışında başlama (SMAppService)
project.yml                XcodeGen tanımı (hedef, bağımlılıklar, derleme ayarları)
```

### Veri akışı

```
görünüm ──tuş──▶ ActionRegistry ──▶ store metodu ──▶ Backend.run { api.… } ──▶ sunucu
   ▲                                     │                                        │
   └──────── @Observable durum ◀── reload() ◀──────── realtime olayı (SSE) ◀──────┘
```

- **İnce istemci:** istemcide iş kuralı yoktur. "Bugün" hangi gün, satır nasıl parse edilir, triyaj ne yapar — hepsi sunucuda. Store'lar yalnızca çağırır ve sonucu gösterir.
- **Tek doğruluk kaynağı sunucudur:** her aksiyondan sonra liste yeniden çekilir; iyimser (optimistic) güncelleme yoktur. Yerel ağda fark edilmez, tutarsızlık sınıfını tümden ortadan kaldırır.
- **Realtime:** `AppState.runRealtime` `tasks`, `projects`, `focus_state` konularına abone olur. Olay gelince ilgili store yenilenir (`TodayStore.scheduleReload` art arda olayları 80 ms'de toplar). Bağlantı koparsa 1 s → 30 s artan aralıkla yeniden bağlanır ve **her bağlantıda tam yenileme** yapar — kopukluk sırasında kaçan olaylar böylece telafi edilir.
- **Hatalar:** store'lar `Backend.run` kullanır. `401` → oturum kapanır, giriş ekranı gelir. Diğer hatalar pencerenin altındaki durum satırında `? mesaj` olarak görünür.
- **Eşzamanlılık:** uygulama modülünde her şey varsayılan olarak ana aktördedir (`SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor`). `Core` paketi aktörsüzdür; tipleri `Sendable` değer tipleridir.

### Aksiyon kaydı — klavyenin tek kaynağı

Her aksiyon `Actions/AppActions.swift` içinde **bir kez** tanımlanır: `id`, görünen ad, bağlam, varsayılan tuş(lar), isteğe bağlı varsayılan global kısayol, çalıştıracağı iş. Aşağıdakilerin hepsi bu listeden türer:

| Bağlam | Tuş nasıl yakalanır |
|---|---|
| `.global` | `KeyboardShortcuts` paketi — uygulama arkadayken de çalışır |
| `.mainWindow` | menü komutu (`TaskTrackerApp.commands`) — uygulama öndeyken her görünümde |
| `.anyView` | `MainView.onKeyPress` — odaktaki görünümün işlemediği tuşlar buraya çıkar (`?`) |
| `.todayList` | `TodayView.onKeyPress` → `ActionRegistry.handle` — liste odaktayken, modifier'sız |
| `.quickAdd` | metin alanı yakalar (`InkTextView`); kayıtta yalnızca belgelenir (`isBindable: false`) |

Ayarlar'daki kısayol tablosu da aynı listeden çizilir ve **her aksiyonun bir global kısayol yuvası** vardır (`action.<id>` adıyla saklanır) — sık kullanılan bir aksiyonu kod değiştirmeden global'e terfi ettirebilirsin.

### Katmanlar: komut paleti ve yardım

`AppState.overlay` (`.palette` / `.help` / `nil`) ana pencerenin ortasına opak, 2 px çerçeveli bir katman açar; arka plan karartılmaz (saydamlık yok). Katman açıkken alttaki görünüm klavye odağını bırakır (`keyboardFocus(unless:)`), kapanınca geri alır — böylece palet açıkken `D` alttaki task'ı tamamlamaz. Görünüm değişince katman kapanır.

- **Palet** `ActionRegistry.search` kullanır: sorgudaki her kelime aksiyon başlığında geçmeli; Türkçe karakter ve büyük/küçük harf duyarsız (`tam ekr` → "Tam ekran aç / kapat"). `showsInPalette: false` olan aksiyonlar (gezinme tuşları, paletin kendisi) ve yalnızca belgelenenler listelenmez. Aksiyon, palet kapandıktan **sonra** çalışır.
- **Yardım** o anki görünümün bağlamını (`Route.context`) en üste koyar, ardından `.anyView`, `.mainWindow`, `.global`. Her satırda yerel tuş + kullanıcının atadığı global kısayol birlikte görünür (`AppAction.allKeysDisplay`).

**Tuş dinleyici sırası:** SwiftUI'de tuşlar odaktaki görünüme ve onun *üstündekilere* gider. Bu yüzden `.keyboardFocus(…)` önce, `.onKeyPress { … }` sonra yazılır; tersi sessizce çalışmaz.

### Menü çubuğu ve otomatik başlama

`TaskTrackerApp` içindeki `MenuBarExtra` sahnesi; etiketi `AppState.menuBarLabel`, görünürlüğü `AppSettings.showsMenuBarItem`. Oturum kurulumu (`bootstrap`) görünümden bağımsız olarak `AppState.init` içinde başlar — pencere hiç açılmasa da (login item) sayılar ve realtime çalışır. `LoginItem.launchedAtLogin` doğruysa `AppDelegate` açılışta pencereyi kapatır.

### Hızlı ekleme paneli

`QuickAddController` hem durumu hem pencereyi tutar. Pencere `QuickAddPanel`: çerçevesiz, `.nonactivatingPanel` → öndeki uygulama önde kalır, yalnızca klavye odağı panele geçer (Spotlight davranışı); kapanınca odak kendiliğinden geri döner. Panel her masaüstünde görünür, gölgesizdir; pencerenin içerik dışındaki kısmı saydamdır ve tıklamaları geçirir (içerik büyüyünce pencereyi yeniden konumlamak gerekmesin diye).

Metin alanı `InkTextView` (sarılmış `NSTextView`): SwiftUI `TextField` aralık bazında biçim veremediği için. Her tuş vuruşundan 90 ms sonra `/api/quickadd/preview` çağrılır; yanıttaki token aralıkları UTF-16 ofsetidir ve doğrudan `NSRange` olarak alt çizgiye dönüşür. Yanıt geldiğinde metin değişmişse o önizleme atılır.

---

## Nasıl yapılır

### Yeni bir aksiyon / kısayol eklemek

`Actions/AppActions.swift` içinde ilgili bağlamın listesine bir `AppAction` ekle:

```swift
AppAction(id: "today.block", title: "Engellendi olarak işaretle", context: .todayList,
          keys: [KeyBinding(key: "b", display: "B")]) {
    today.setStatus(.blocked)      // iş store'da yapılır (örnek: bu metot henüz yok, TodayStore'a yazılır)
}
```

Başka hiçbir yere dokunmadan: tuş çalışır, Ayarlar'da listelenir, global kısayol atanabilir olur. Ekranın altındaki ipucu satırı (`InkHints`) elle yazılır — oraya da ekle. Bilinen kısıt: Türkçe klavyede `I` tuşu `ı` üretir; harf seçerken `i/ı` kullanma.

### Yeni bir görünüm (ör. Triyaj) eklemek

1. `Stores/` altında bir store: `@Observable final class`, `Backend` alır, `reload()` + aksiyon metotları. Sunucuya yalnızca `backend.run { try await $0.… }` ile gider.
2. Gerekli endpoint `Core/APIClient.swift`'te yoksa ekle; yanıt tipini `Core/Models.swift`'e yaz; `Core/Tests` içindeki canlı teste bir adım ekle.
3. `Features/<Ad>/<Ad>View.swift`: yalnızca `Theme` ve `InkViews` kullan.
4. `AppState`: store'u oluştur, `reloadAll()`'a ve realtime `switch`'ine ekle.
5. `AppState.swift` → `Route.isImplemented` ve `MainView.content` içindeki `switch`.
6. Klavye: `ActionContext`'e yeni bir bağlam, `AppActions`'a aksiyonlar, görünümde `.onKeyPress { app.registry.handle($0, in: .yeniBağlam) }`.

### Görünümü (renk, boyut, çizgi) değiştirmek

Yalnızca `Theme/Theme.swift`. Ekranlarda `Color(...)`, `.font(.system(...))`, sabit kalınlık yazılmaz. Yeni bir görsel öğe gerekiyorsa `InkViews.swift`'e eklenir. Kurallar: renk yok, gölge/blur/saydamlık yok, animasyon yok, ikon yok (yalnızca glif), köşe yarıçapı 0. Bir kuralı değiştireceksen önce `docs/DESIGN.md`'yi güncelle.

### API sözleşmesi değişince

`docs/api.md` → `backend` testi → `Core/Models.swift` + `APIClient.swift` → `Core/Tests`. Uygulama katmanı çoğu zaman değişmez.

---

## Testler ve doğrulama

```sh
cd macos/Core
swift test                                   # birim testleri (canlı testler atlanır)

set -a; . ../../backend/.env; set +a         # canlı sözleşme testleri: backend ayakta olmalı
TT_URL=http://127.0.0.1:8090 TT_EMAIL="$TT_USER_EMAIL" TT_PASSWORD="$TT_USER_PASSWORD" swift test
```

Canlı testler gerçek sunucuya karşı şunları doğrular: girişsiz istek `401`, ulaşılamayan sunucu hatası, quickadd → odak listesi → aktif task → zamanlayıcı → tamamla → triyaj → sil döngüsü, SSE ile olay teslimi. Oluşturdukları kayıtları (`zz-swift…`) silerler.

Arayüz için otomatik test yok. Ekranları klavyesiz açıp gözle kontrol etmek için **yalnızca DEBUG derlemesinde** iki ortam değişkeni vardır:

```sh
TT_DEBUG_ROUTE=settings \
TT_DEBUG_OVERLAY=palette \
TT_DEBUG_QUICKADD="Rapor yaz salı son:cuma !1 // kısa not" \
  build/Build/Products/Debug/TaskTracker.app/Contents/MacOS/TaskTracker
```

(`TT_DEBUG_OVERLAY`: `palette` ya da `help`.)

Ayarları sıfırlamak (çıkış + varsayılan sunucu + kısayollar): `defaults delete local.tasktracker.mac`
Pencere durumunu sıfırlamak (ör. tam ekranda takılı kaldıysa): `rm -rf ~/Library/Saved\ Application\ State/local.tasktracker.mac.savedState`

---

## Bilinçli kararlar ve tasarımdan sapmalar

| Konu | Durum | Neden |
|---|---|---|
| Token `UserDefaults`'ta | karar | Ad-hoc imzada Keychain her yeniden derlemede izin sorar. Tehdit modeli: tek kullanıcılı Mac, sunucu yalnızca tailnet içinde. Parola saklanmaz; token ~7 gün geçerli, her açılışta yenilenir. |
| `NSAllowsArbitraryLoads` | karar | Sunucu yerelde / tailnet IP'sinde düz `http` olabilir. Faz 4'te `https` adresine geçince daraltılabilir. |
| App Sandbox kapalı | karar | Kişisel araç; global kısayol ve ileride panel davranışları için gereksiz sürtünme. |
| İyimser güncelleme yok | karar | Yukarıda — tutarlılık > milisaniyeler. |
| Pencere köşeleri yuvarlak | **sapma** | macOS başlıklı pencerelerde köşeyi sistem çizer. Kare köşe için ana pencereyi de çerçevesiz `NSWindow`'a çevirmek gerekir (boyutlandırma/taşıma elle yazılır) — ertelendi. Hızlı ekleme paneli çerçevesiz olduğu için kare. |
| Blok imleç `█` yok | **sapma** | `NSTextView`'ın ekleme imleci artık sistem bileşeni; özelleştirmek kırılgan. İmleç `ink` renginde ince çizgi. |
| Kısayol kaydedici kutusu | **sapma** | `KeyboardShortcuts.Recorder` paketin kendi (yuvarlak, İngilizce "Record Shortcut") bileşeni. Tema içi bir kaydedici adım 2'de yazılabilir. |
| Pencere düğmeleri gizli | karar | Renkli trafik ışıkları monokromu bozuyor. `⌘W` / `⌘M` / `⌘Q` / `⌃⌘F` çalışır; pencere arka plandan sürüklenir. |
| Tam ekran geçiş animasyonu | sistem | macOS'in kendi tam ekranı (ayrı masaüstü) kullanılıyor; geçiş animasyonu sisteme ait, "hareket yok" ilkesinin dışında kalıyor. |
| Menü çubuğu menüsü | sistem | Menü çubuğu ve açılan menü macOS'in kendi bileşeni; yazı tipi/renk oraya taşınamaz. Etiket yalnızca metin (`▸ 3/7`), ikon yok. |
| Oturum açılışında gizli başlama | **doğrulanmadı** | `LoginItem.launchedAtLogin` Apple Event'e bakıyor; gerçek bir oturum açılışıyla denenmedi. Yanlış çalışırsa tek etkisi pencerenin açılışta görünmesi olur. |
| Kaydırma çubuğu | sistem | Görünürlüğü macOS ayarına bağlı. |

## Sıradakiler (PLAN.md → Faz 2)

- **Adım 3:** yüzen paneller — mini panel (6 hal) ve onun yerini alan liste paneli, zamanlayıcı çubuğu + süre dolunca ses/bildirim.
- **Adım 4:** Triyaj → Hafta → Kanban → Projeler → Notlar.
- Odak listesinde eksik kalanlar: `⌘↑/⌘↓` ile sıralama, `/` filtre, task detayını görme/düzenleme (`E`), task'a not düşme (`N`).
