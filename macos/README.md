# macos

task_tracker'ın macOS uygulaması: Swift 6 + SwiftUI (gerektiği yerde AppKit), hedef yalnızca macOS 26.

- Uyduğu API sözleşmesi: [../docs/api.md](../docs/api.md)
- Görsel dil (her ekranın uyduğu kurallar): [../docs/DESIGN.md](../docs/DESIGN.md)
- Yol haritası: [../docs/PLAN.md](../docs/PLAN.md) → Faz 2

**Durum:** Faz 2 / adım 1–3 + adım 4'ün **tamamı** (Triyaj, Hafta, Kanban, Projeler, Notlar + hızlı not) tamam — yüzen panel (mini + liste) ve zamanlayıcı dahil. Öncesi: giriş, Odak ekranı, hızlı ekleme paneli, Ayarlar, aksiyon kaydı, tam ekran, menü çubuğu öğesi, otomatik başlama, `⌘K` komut paleti, `?` kısayol yardımı. Sıradakiler en altta.

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

- İlk açılışta giriş ekranı gelir: sunucu `http://127.0.0.1:8090`, e-posta ve parola `backend/.env` içindeki `TT_USER_*`. **API anahtarı** alanı yalnızca internete açık sunucu için doldurulur — [../docs/DEPLOY.md](../docs/DEPLOY.md) → Mac uygulamasını sunucuya bağlamak.
- Yeni dosya ekleyince ya da `project.yml` değişince `xcodegen generate` yeniden çalıştırılır. Xcode'da açmak istersen: `open TaskTracker.xcodeproj`.
- İmza yerel (ad-hoc): Apple Developer hesabı yok, uygulama yalnızca bu Mac'te çalışır.

## Kullanım

| Nerede | Tuş | Ne yapar |
|---|---|---|
| Her yerden | `⌃⌥Space` | Hızlı ekleme panelini aç / kapat |
| Her yerden | `⌃⌥N` | Hızlı not panelini aç / kapat: `↵` kaydet (panel açık kalır) · `⇧↵` yeni satır · ilk satır başlık · ilk satırdaki `#proje` bağlar · `esc` kapat |
| Her yerden | `⌃⌥T` | Ana pencereyi göster |
| Her yerden | `⌃⌥M` | Mini panel: klavyeyi ver / bırak (uygulama öne gelmez; çerçeve 2 px olur) |
| Her yerden | `⌃⌥L` | Liste panelini aç / kapat (mini panelin yerinde açılır) |
| Mini panel | `E` | Detayları genişlet / daralt (proje, alan, bitiş, açıklama) |
| Mini panel | `T` | Zamanlayıcı: dakika yaz + `↵` başlatır; çalışıyorsa `T` durdurur |
| Mini panel | `N` | Aktif task'a not düş: yaz + `↵` → açıklamanın sonuna satır olarak eklenir |
| Mini panel | `D` | Aktif task'ı tamamla → panel boşalır ("sıradaki ne?") |
| Mini panel | `␣` | Aktif task seç → liste paneli açılır |
| Mini panel | `H` | Paneli tamamen gizle. `⌃⌥M` (ya da `⌃⌥L`) geri getirir ve klavyeyi verir; gizli kalma tercihi yeniden başlatmada da korunur. Klavyeyi vermeden göster/gizle: "Yüzen paneli göster / gizle" aksiyonu (palet ya da Ayarlar'dan kısayol) |
| Mini panel | `esc` | Klavyeyi önceki uygulamaya geri ver |
| Liste paneli | `↵` | Seçili task'ı aktif yap, mini panele dön |
| Liste paneli | `P` | Sabitle: klavyeyi bıraksa da liste açık kalır (pasif dashboard) |
| Liste paneli | `esc` | Mini panele dön |
| Liste paneli | `↑↓ J K D Y 1–4 ⇥` | Odak listesindeki anlamlarıyla aynı |
| Ana pencere | `⌘1`…`⌘6` | Görünümler (şimdilik yalnızca ODAK dolu) |
| Ana pencere | `⌘,` | Ayarlar |
| Ana pencere | `⌘N` | Hızlı ekleme paneli |
| Ana pencere | `⌘K` | Komut paleti: her aksiyon adıyla aranır, `↑↓` seç, `↵` çalıştır, `esc` kapat |
| Ana pencere | `?` | O ekranın kısayol listesi (`?` ya da `esc` kapatır; metin alanı odaktayken çalışmaz) |
| Ana pencere | `⌘M` / `⌘W` | Küçült (Dock'a) / kapat (uygulama arka planda kalır) |
| Ana pencere | `⌃⌘F` | Tam ekran aç / kapat (durum hatırlanır; bir sonraki açılış aynı halde başlar) |
| Odak listesi | `↑` `↓` / `J` `K` | Gezin |
| Odak · Hafta · Kanban | `E` | Detayı aç; **detay açıkken tekrar `E` → düzenleme katmanı**. `esc` detayı kapatır, çift tık da açar |
| Düzenleme katmanı | `⇥` `⇧⇥` · `↵` · `esc` | Alanlar arası gez (başlık, başla, son, öncelik, alan, proje, açıklama) · kaydet (açıklamada `⇧↵` yeni satır) · vazgeç. Tarihler hızlı ekleme sözlüğüyle yazılır (`cuma`, `25.09`); boş bırakmak alanı temizler |
| Odak listesi | `↵` | Aktif task yap / bırak (`▸`) |
| Odak listesi | `D` | Tamamla / geri al |
| Odak listesi | `Y` | Yarına at |
| Odak listesi | `1`–`4` | Öncelik |
| Odak listesi | `⇥` | Alan filtresi: hepsi → iş → kişisel |
| Triyaj | `1` | Yarına at |
| Triyaj | `2` | Tarih seç: hızlı eklemenin sözlüğüyle yazılır (`cuma`, `yarın`, `25.09`); çözülen gün canlı görünür, `↵` onaylar |
| Triyaj | `3` | Projeye taşı: yazarak süz, `↑↓` seç, `↵` taşı. Listede olmayan ad **yeni proje** olarak oluşturulur (alanı task'tan, yoksa kişisel). Task günlük akıştan çıkar |
| Triyaj | `4` | Sil — `↵` ile onaylanır |
| Triyaj | `D` / `␣` | Tamamlandı say / atla (atlanan kuyruğun sonunda kalmaz; bir sonraki triyajda yeniden gelir) |
| Triyaj | `esc` | Alt moddan çık; karar ekranındaysa Odak'a dön |
| Hafta | `↑↓` / `J K` | Gezin (gecikenler + 7 gün, tek liste) |
| Hafta | `←` `→` / `H L` | Seçili task'ı bir gün geri / ileri taşı. Geçmişe taşınmaz (en erken bugün); gecikmiş task `→` ile bugüne gelir |
| Hafta | `B` | Task'ı bugüne al |
| Hafta | `D` · `E` · `↵` | Tamamla / geri al · detay · aktif yap |
| Hafta | `.` `,` `0` | Sonraki hafta · önceki hafta (bu haftadan geriye gidilmez) · bu haftaya dön |
| Kanban | `↑↓` `←` `→` / `J K H L` | Kartlar ve sütunlar arasında gezin (boş sütun atlanır) |
| Kanban | `⇧←` `⇧→` | Kartı önceki / sonraki duruma taşı: yapılacak ↔ yapılıyor ↔ engelli ↔ bitti. Fareyle sürükle-bırak da çalışır |
| Kanban | `D` · `E` · `↵` | Tamamla / geri al · açıklamayı aç · aktif yap |
| Projeler | `↑↓` · `N` · `E`/`↵` · `R` | Gezin · yeni proje (ad yaz, `↵`) · tanımı düzenle (yazarken kaydedilir, `esc` çıkar) · yeniden adlandır |
| Projeler | `S` · `A` · `⌫` | Durum: aktif → beklemede → bitti · alan: iş ↔ kişisel · sil (`↵` ile onay; task ve notlar silinmez) |
| Notlar | `↑↓` `←` `→` · `↵`/`E` · `N` | Izgarada gezin · notu aç / düzenle (ilk satır başlık, yazarken kaydedilir, `esc` döner) · yeni not |
| Notlar | `P` · `⇥` · `/` · `⌫` | Sabitle / bırak · proje filtresi · ara (`↵` uygula, `esc` temizle) · sil (`↵` ile onay) |
| Hızlı ekleme | `↵` | Ekle (panel açık kalır) |
| Hızlı ekleme | `⇥` | Çok satırlı açıklama alanı ↔ başlık |
| Hızlı ekleme | `⇧↵` | Açıklamada yeni satır |
| Hızlı ekleme | `esc` | Kapat |

**Yüzen panel:** giriş yapılınca ana ekranın sağ üstünde belirir; **herhangi bir yerinden tutulup sürüklenir**, bırakıldığı yer hatırlanır (ekranın dışına taşarsa içeri çekilir; kaybolursa `⌘K` → "Yüzen paneli varsayılan konuma al"), her masaüstünde ve tam ekran uygulamaların üstünde durur. Pasifken tuşlara tepki vermez; `⌃⌥M` ya da üstüne tıklamak klavyeyi ona verir. Tek atımlık aksiyonlardan (`D`, süre başlatma, aktif task seçme) sonra klavye kendiliğinden önceki uygulamaya döner. Zamanlayıcı dolunca kısa ses + macOS bildirimi gelir (ilk zamanlayıcıda bildirim izni sorulur).

**Pencere düğmeleri:** sol üstte `✕ – □` — kapat, küçült, tam ekran (sistemin renkli düğmelerinin monokrom karşılığı; her ekranda, giriş dahil). Tam ekrandayken `–` önce tam ekrandan çıkarır (macOS tam ekran pencereyi küçültemez).

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
    TriageStore.swift      Triyaj kuyruğu, karar modları (tarih / proje / silme onayı)
    WeekStore.swift        Hafta görünümü: 7 gün + gecikenler, gün taşıma, haftalar arası gezinme
    KanbanStore.swift      Kanban: durum sütunları, kart/sütun gezinme, durum taşıma
    ProjectsScreenStore.swift  Projeler görünümü: seçim + modlar (oluştur / adlandır / tanım / sil)
    NotesStore.swift       Notlar: ızgara, proje filtresi, arama, editör (otomatik kayıt)
    TaskEditorModel.swift  Task düzenleme katmanı: alanlar, canlı tarih çözümü, doğrulama, kayıt
    SupportingStores.swift ProjectStore (adlar), ActiveTaskStore (aktif task + zamanlayıcı)
    InkTextView.swift      token vurgulu metin alanı (NSTextView); hızlı ekleme ve palet kullanır
  Features/
    Login/ Main/ Today/ Triage/ Week/ Kanban/ Projects/ Notes/ QuickAdd/ QuickNote/ Settings/
    Overlays/              PaletteView (⌘K), HelpView (?), TaskEditorView — ana pencerenin üstüne açılan katmanlar
    Panel/                 PanelController (durum + pencere), PanelView (mini ve liste içerikleri)
    MenuBar/               MenuBarMenu — menü çubuğu öğesinin menüsü
  Support/
    LoginItem.swift        oturum açılışında başlama (SMAppService)
    TimerAlert.swift       süre dolunca ses + bildirim
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
| `.miniPanel` / `.listPanel` | `PanelView.onKeyPress`; liste paneli önce kendi bağlamına, sonra `.todayList`'e bakar (aynı aksiyonlar iki yerde de çalışır) |
| `.quickAdd` | metin alanı yakalar (`InkTextView`); kayıtta yalnızca belgelenir (`isBindable: false`) |

Ayarlar'daki kısayol tablosu da aynı listeden çizilir ve **her aksiyonun bir global kısayol yuvası** vardır (`action.<id>` adıyla saklanır) — sık kullanılan bir aksiyonu kod değiştirmeden global'e terfi ettirebilirsin.

### Katmanlar: komut paleti ve yardım

`AppState.overlay` (`.palette` / `.help` / `nil`) ana pencerenin ortasına opak, 2 px çerçeveli bir katman açar; arka plan karartılmaz (saydamlık yok). Katman açıkken alttaki görünüm klavye odağını bırakır (`keyboardFocus(unless:)`), kapanınca geri alır — böylece palet açıkken `D` alttaki task'ı tamamlamaz. Görünüm değişince katman kapanır.

- **Palet** `ActionRegistry.search` kullanır: sorgudaki her kelime aksiyon başlığında geçmeli; Türkçe karakter ve büyük/küçük harf duyarsız (`tam ekr` → "Tam ekran aç / kapat"). `showsInPalette: false` olan aksiyonlar (gezinme tuşları, paletin kendisi) ve yalnızca belgelenenler listelenmez. Aksiyon, palet kapandıktan **sonra** çalışır.
- **Yardım** o anki görünümün bağlamını (`Route.context`) en üste koyar, ardından `.anyView`, `.mainWindow`, `.global`. Her satırda yerel tuş + kullanıcının atadığı global kısayol birlikte görünür (`AppAction.allKeysDisplay`).

**Tuş dinleyici sırası:** SwiftUI'de tuşlar odaktaki görünüme ve onun *üstündekilere* gider. Bu yüzden `.keyboardFocus(…)` önce, `.onKeyPress { … }` sonra yazılır; tersi sessizce çalışmaz.

**Klavye güvenlik ağı (`AppState.installKeyFallback`):** SwiftUI tuşları yalnızca klavye odağı ekranın içindeyken dinler; fare tıklaması (ör. kenar çubuğundan görünüm değiştirmek) odağı düşürebiliyor ve o zaman `N`, `D`… hiçbir yere gitmiyordu. Ana pencereye gelen her tuşu bir `NSEvent` yerel izleyicisi görür; olay dağıtıldıktan sonra SwiftUI tuşu görmediyse (`ActionRegistry.sawKeyPress` kalkmadıysa), bir metin alanı yazmada değilse ve katman açık değilse tuş doğrudan görünümün bağlamına (`Route.context` + `.anyView`) yönlendirilir ve `focusTick` ile odak geri alınır. Odak sağlamken izleyici hiçbir şey yapmaz → çift işleme yok.

**`esc` tuzağı:** `esc`, içteki metin alanı (`InkTextView` / `NSTextView`) odaktayken bile **önce** onu saran SwiftUI görünümlerinin `onKeyPress` dinleyicilerine gider (harfler gitmez, yalnızca `esc`). Dinleyici `.handled` dönerse metin alanının `onCancel`'ı hiç çalışmaz. `ActionRegistry.handle`, eşleşen bir aksiyon bulunca aksiyon bir şey yapmasa da `.handled` döner → **içinde metin alanı barındıran her görünümün `esc` aksiyonu yazma modlarını da kapatmalıdır** (Projeler ve Triyaj: `store.cancel()`; Notlar: `closeEditor()` / `endSearch`). Notlar'da bu eksikti: editör `esc` ile kapanmıyordu.

### Menü çubuğu ve otomatik başlama

`TaskTrackerApp` içindeki `MenuBarExtra` sahnesi; etiketi `AppState.menuBarLabel`, görünürlüğü `AppSettings.showsMenuBarItem`. Oturum kurulumu (`bootstrap`) görünümden bağımsız olarak `AppState.init` içinde başlar — pencere hiç açılmasa da (login item) sayılar ve realtime çalışır. `LoginItem.launchedAtLogin` doğruysa `AppDelegate` açılışta pencereyi kapatır.

### Triyaj

Kuyruk `GET /api/views/focus`'tur (alan filtresiz): bugüne ya da öncesine planlı, bitmemiş her şey. `TriageStore` yalnızca sırayı ve giriş modunu tutar; kararları sunucu uygular (`POST /api/triage/{id}`).

- **Modlar:** `.choose` (1–4) → `.date` / `.project` / `.confirmDelete`. Metin yazılan modlarda klavye `InkTextView`'dadır; görünüm odağı bırakır (`keyboardFocus(unless: store.isTyping)`), bu yüzden `1`–`4` yazarken tetiklenmez.
- **Tarih** istemcide çözülmez: `APIClient.resolveDate` metni `/api/quickadd/preview`'a `"x <metin>"` olarak yollar ve yalnızca metnin tamamı tek bir tarih token'ıysa sonucu kabul eder → hızlı eklemeyle aynı sözlük, tek yerde.
- **Proje** seçici bitmemiş projeleri listeler; tam eşleşme yoksa sona "+ yeni proje" satırı ekler. Uygulamada proje yaratmanın şimdilik tek yolu budur (Projeler görünümü gelene kadar).
- Realtime `tasks` olayında kuyruk yenilenir, üzerinde durulan task korunur. Kenar çubuğundaki TRİYAJ sayısı başlama günü **geçmiş** task'lardır (`TodayStore.overdue`).

### Hafta

`GET /api/views/week` (`start` verilmezse sunucunun bugününden 7 gün). Düzen: üstte **yük şeridi** (gün başına açık task sayısı; çubuk uzunluğu haftanın en yoğun gününe oranlı), altında gün gün **ajanda**. Yan yana 7 sütun bilinçli olarak seçilmedi: 1180 px pencerede sütun başına ~17 karakter kalıyor.

- Gün taşıma `PATCH scheduled_date` ile yapılır (`WeekStore.shiftDay`); gün aritmetiği `Day.adding` (Core), "bugün" yine sunucunun `today` alanı. Geçmişe taşıma engellidir.
- `TaskRow` ve `TaskDetails` Odak ekranıyla ortaktır. Görünümün adı `WeekScreen`'dir (`WeekView` Core'daki modelin adı).
- `.` / `,` haftayı 7 gün kaydırır; bu haftaya dönünce `start` yeniden `nil` olur ki gün değişince görünüm kendiliğinden ilerlesin.

### Kanban

Veri iki çağrıdan birleşir: `APIClient.openTasks()` (bitmemiş **bütün** task'lar — plansız olanlar dahil; koleksiyon REST'i, `status != 'done'`) + `focusView().done` (yalnızca **bugün** bitenler; BİTTİ sütunu sonsuza uzamasın diye). Durum değişimi `PATCH status`'tur; `completed_at` ve aktif task'ın boşalması sunucu kurallarıdır.

- Klavyede gezinme (`←` `→`) ile taşıma (`⇧←` `⇧→`) ayrıdır. `KeyBinding.matches` Shift'i **yalnızca ok tuşlarında** ayırt eder; karakter tuşlarında yok sayar (`?` zaten Shift'le üretilir).
- Sürükle-bırak: kart `.draggable(task.id)`, sütun `.dropDestination(for: String.self)`; ikisi de `KanbanStore.setStatus`'a düşer.

### Task düzenleme

`AppState.editTask(_:)` → `Overlay.editTask`. Katman her görünümde aynıdır; `E` aksiyonları "detay kapalıysa aç, açıksa düzenle" kuralını uygular (Odak, Hafta, Kanban).

- Alanlar düz metindir ve **kaydederken** doğrulanır (`TaskEditorModel.validatedPatch`): tarihler `APIClient.resolveDate` ile sunucuda çözülür (düzenleme alanı tarihi `05.09.2026` biçiminde gösterir — `Day.full` — ve sözlük bunu geri çözer), öncelik 1–4, alan `iş`/`kişisel` (önek yeter), proje tam ad ya da tekil önek. Hata varsa kayıt yapılmaz; ilk hatalı alan odaklanır ve altında `? mesaj` görünür.
- Boş bırakılan tarih / proje / alan o alanı **temizler** (`TaskPatch` boş metin yollar).
- Tek ekranda yedi `InkTextView` vardır: `focusTrigger: 0` "odak isteme" demektir, yalnızca etkin alan odaklanır; fareyle tıklanan alan `onFocus` ile modele bildirilir.
- Mini paneldeki `N` ayrı bir yoldur (`PanelController.handleNoteInput` → `ActiveTaskStore.appendNote`): metin alanı değil, süre girişindeki gibi küçük bir durum makinesi — panelde klavye odağı hiç kaybolmasın diye.

### Projeler ve Notlar

- **Projeler** şimdilik yalnızca proje + tanımdır (kullanıcı kararı): task sayısı, ilerleme ve projeye task bağlama ekranı yok. Proje verisi `ProjectStore`'da durur (satırlardaki `#ad` etiketleri de oradan okur); `ProjectsScreenStore` yalnızca seçim ve giriş modlarını tutar. Yeni proje kişisel alanla oluşur, `A` ile değişir.
- **Otomatik kayıt:** proje tanımı ve not editöründe kaydet tuşu yoktur. Metin değişince 600–700 ms sonra `PATCH` gider; `esc` ile çıkarken bekleyen kayıt hemen yazılır. Not editörü açıkken realtime yenilemesi listeyi değiştirmez (yazılan metin ezilmesin).
- **Not = tek metin:** editörde ilk dolu satır başlık, kalanı gövdedir (`Note.text` / `Note.split`, Core). Boş yeni not oluşturulmaz; ilk anlamlı kayıtta `POST` edilir. Bir proje filtresi seçiliyken açılan yeni not o projeye bağlanır.
- **Izgara gezinme:** `←` `→` bir kart, `↑` `↓` bir satır (= sütun sayısı kadar) atlar; sütun sayısını görünüm genişlikten hesaplayıp store'a bildirir.
- **Hızlı not** (`QuickNoteController`) hızlı eklemenin pencere sınıfını ve konumunu paylaşır (`QuickAddPanel.placeSpotlight`). Ayrıştırma sunucudadır: `/api/quicknote` — sözleşmesi `docs/api.md` → Hızlı not.
- `InkTextView` artık uzun metin editörü olarak da kullanılıyor: `submitsOnReturn: false` iken `↵` yeni satır açar.

### Yüzen panel

Tek pencere (`FloatingPanel`), iki biçim: `PanelController.mode` = `.mini` ya da `.list`. Liste, mini panelin **yerini alır** — aynı köşede, aynı pencerede; ikisi aynı anda görünmez.

- **Pencere:** çerçevesiz, `.nonactivatingPanel`, `.floating` seviye, tüm masaüstlerinde, gölgesiz. Sabit 320 × 560 ve saydamdır; içerik pencerenin üstüne ya da altına yaslanır (`anchorsTop` — içerik ekranın hangi yarısındaysa), kalan kısım tıklamaları geçirir. Böylece içerik büyüyüp küçülürken (mini ↔ geniş ↔ liste) pencere oynamaz ve içerik köşesinden büyür.
- **Konum = içeriğin sabit köşesi**, pencerenin değil (`AppSettings.panelAnchor` + `panelAnchorsTop`); pencere konumu her zaman ondan türetilir (`apply(anchor:)`). İlk sürümde açılışta yaslama *pencerenin* orta noktasından hesaplanıyordu — pencere içerikten ~500 pt uzun olduğu için sürüklerkenki hesapla çelişiyor ve panel ekranın ortasına kayıyordu.
- **Sürükleme elle yönetilir** (`PanelView`'daki `DragGesture` → `dragChanged` / `dragEnded`; farenin ekran konumu kullanılır). Sistemin `isMovableByWindowBackground` davranışı çalışmıyordu: içerik klavye için odaklanabilir olduğundan fare olaylarını yutuyor. Bırakınca `settle()` içeriği ekranın içine çeker, yaslamayı günceller (değişirse pencereyi aynı anda kaydırır; içerik oynamaz) ve köşeyi saklar. Ekran takılıp çıkarılınca da `settle()` çalışır; kayıtlı köşe hiçbir ekranda değilse varsayılana dönülür.
- **Dinleme durumu pencerenin anahtar (key) olmasından türer** (`didBecomeKey` / `didResignKey`); ayrı bir bayrak tutulmaz. Başka yere tıklamak = klavyeyi bırakmak: süre girişi ve geniş hal kapanır, sabitlenmemiş liste mini panele döner.
- **`release()`** klavyeyi önceki uygulamaya verir: panel bir an `orderOut` edilip anahtar olmadan yeniden gösterilir (uygulama hiç öne gelmediği için odak kendiliğinden geri döner).
- **Süre girişi** bir metin alanı değil, küçük bir durum makinesidir (`timerInput`, `handleTimerInput`): rakamlar, `⌫`, `↵`, `esc`. Panelde odaklanacak alt görünüm olmadığı için klavye odağı hiç kaybolmaz.
- **Zamanlayıcı** sunucuda tıklamaz. `ActiveState.timerFraction(at:)` (Core) kalan oranı hesaplar; çubuk `TimelineView` ile saniyede bir yeniden çizilir ama görünüşü yalnızca bir hücre (1/37) değişince değişir → kademeli azalma. Bitişi `ActiveTaskStore.scheduleExpiry` bekler: ses + bildirim, ardından `stopTimer` (diğer istemciler de sıfırlansın). Uygulama kapalıyken dolmuş eski zamanlayıcı sessizce temizlenir.
- Liste paneli `TodayStore`'u ana penceredeki Odak ekranıyla **paylaşır** (seçim dahil) ve `TaskRow(compact: true)` kullanır.

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

Arayüz için otomatik test yok. Ekranları klavyesiz açıp gözle kontrol etmek ve **klavye akışlarını ölçmek** için **yalnızca DEBUG derlemesinde** ortam değişkenleri vardır:

```sh
TT_DEBUG_ROUTE=settings \
TT_DEBUG_EDIT=1 TT_DEBUG_QUICKNOTE='Başlık #proje\ngövde' TT_DEBUG_OVERLAY=palette TT_DEBUG_DETAILS=1 TT_DEBUG_PANEL=expanded TT_DEBUG_TRIAGE=date \
TT_DEBUG_QUICKADD="Rapor yaz salı son:cuma !1 // kısa not" \
  build/Build/Products/Debug/TaskTracker.app/Contents/MacOS/TaskTracker
```

(`TT_DEBUG_TRIAGE`: `choose` | `date` | `project`. `TT_DEBUG_OVERLAY`: `palette` | `help`. `TT_DEBUG_PANEL`: `listen` | `expanded` | `timer` | `note` | `list` — yüzen panelin halini klavye odağı olmadan zorlar. Not: uygulama terminalden arka planda başlatılıp pasifleşince gerçek klavye odağı düşer; panel halleri bu yüzden zorlanarak doğrulanır.)

**Sentetik tuşlar — klavye akışını gerçekten ölçmek.** `TT_DEBUG_KEYCODES` uygulamanın *içinden* tuş olayı üretir: sistem izni gerekmez ve tuş gerçek yoldan geçer (pencere → SwiftUI → metin alanı). Her tuştan sonra durum satırı yazdırılır:

```sh
TT_DEBUG_ROUTE=notes TT_DEBUG_KEYCODES=36,53 …/TaskTracker      # ↵ notu aç, esc kapat
#   TTKEY 36 → … notlar=editing …
#   TTKEY 53 → … notlar=browse …
TT_DEBUG_ROUTE=today TT_DEBUG_KEYCODES=14,14,53,53 …/TaskTracker # E detay, E düzenle, esc, esc
```

Belirteçler: `r:<görünüm>` görünüm değiştirir, `f:` klavye odağını düşürür (tıklamanın yaptığı şeyi taklit eder), `c:<x>:<y>` pencere içine tıklama dener (düğmeleri tetiklemiyor, kartları seçiyor). Tuşlar `NSApp.sendEvent` ile gerçek yoldan gider (izleyiciler dahil). Tuş kodları: `53` esc · `36` ↵ · `48` ⇥ · `49` ␣ · `14` E · `45` N · `2` D · `15` R · `35` P · `44` / · `19` 2 · `51` ⌫. İlk satırda `anahtarPencere=false` yazıyorsa uygulama öne geçememiştir (macOS arka plandan başlatılan uygulamayı her zaman öne almaz) — ölçüm geçersizdir, yeniden çalıştır.

Ayarları sıfırlamak (çıkış + varsayılan sunucu + kısayollar): `defaults delete local.tasktracker.mac`
Pencere durumunu sıfırlamak (ör. tam ekranda takılı kaldıysa): `rm -rf ~/Library/Saved\ Application\ State/local.tasktracker.mac.savedState`

---

## Bilinçli kararlar ve tasarımdan sapmalar

| Konu | Durum | Neden |
|---|---|---|
| Token `UserDefaults`'ta | karar | Ad-hoc imzada Keychain her yeniden derlemede izin sorar. Tehdit modeli: tek kullanıcılı Mac, sunucu yalnızca tailnet içinde. Parola saklanmaz; token ~7 gün geçerli, her açılışta yenilenir. |
| `NSAllowsArbitraryLoads` | karar | Yerel sunucu düz `http`. Sunucu adresi artık `https`; yerel kullanım bırakılınca daraltılabilir. |
| API anahtarı `UserDefaults`'ta | karar | Token ile aynı gerekçe (ad-hoc imzada Keychain her derlemede izin sorar). `APIClient` anahtarı her isteğe `X-API-Key` olarak ekler — giriş ve SSE dahil. `403` oturumu kapatmaz (o `401`'dir), durum satırında mesaj olarak görünür. |
| App Sandbox kapalı | karar | Kişisel araç; global kısayol ve ileride panel davranışları için gereksiz sürtünme. |
| İyimser güncelleme yok | karar | Yukarıda — tutarlılık > milisaniyeler. |
| Yüzen panel yuvarlak + pasifken saydam | karar | Kullanıcı isteği: köşede sürekli duran panel daha yumuşak dursun. "Saydamlık yok / köşe 0" kurallarının tek istisnası; değerler `Theme.panelRadius` (10) ve `Theme.panelPassiveOpacity` (0.85). Hızlı ekleme paneli kare ve opak kalır. |
| Pencere köşeleri yuvarlak | **sapma** | macOS başlıklı pencerelerde köşeyi sistem çizer. Kare köşe için ana pencereyi de çerçevesiz `NSWindow`'a çevirmek gerekir (boyutlandırma/taşıma elle yazılır) — ertelendi. Hızlı ekleme paneli çerçevesiz olduğu için kare. |
| Blok imleç `█` yok | **sapma** | `NSTextView`'ın ekleme imleci artık sistem bileşeni; özelleştirmek kırılgan. İmleç `ink` renginde ince çizgi. |
| Kısayol kaydedici kutusu | **sapma** | `KeyboardShortcuts.Recorder` paketin kendi (yuvarlak, İngilizce "Record Shortcut") bileşeni. Tema içi bir kaydedici adım 2'de yazılabilir. |
| Pencere düğmeleri | karar | Sistemin renkli trafik ışıkları monokromu bozduğu için gizli; yerlerine `✕ – □` glif düğmeleri var (`WindowControls`, `MainView.swift`). Pencere arka plandan sürüklenir. |
| Tam ekran geçiş animasyonu | sistem | macOS'in kendi tam ekranı (ayrı masaüstü) kullanılıyor; geçiş animasyonu sisteme ait, "hareket yok" ilkesinin dışında kalıyor. |
| Menü çubuğu menüsü | sistem | Menü çubuğu ve açılan menü macOS'in kendi bileşeni; yazı tipi/renk oraya taşınamaz. Etiket yalnızca metin (`▸ 3/7`), ikon yok. |
| Oturum açılışında gizli başlama | **doğrulanmadı** | `LoginItem.launchedAtLogin` Apple Event'e bakıyor; gerçek bir oturum açılışıyla denenmedi. Yanlış çalışırsa tek etkisi pencerenin açılışta görünmesi olur. |
| Kaydırma çubuğu | sistem | Görünürlüğü macOS ayarına bağlı. |

## Sıradakiler (PLAN.md → Faz 2)

- Notu task'a bağlama (`tasks.note` ilişkisi backend'de hazır, arayüzü yok). Triyajda task düzenleme kısayolu yok (Odak'tan yapılır).
- Yüzen panelde eksik kalanlar: liste panelinde `/` filtre, `⌘↑/⌘↓` sıralama.
- Odak listesinde eksik kalanlar: `⌘↑/⌘↓` ile sıralama, `/` filtre.
