# Tasarım Teması — "E-ink"

Bütün uygulama (macOS, ileride Android) bir **e-mürekkep ekran** gibi görünür ve davranır: kâğıt zemin, siyah mürekkep, sıfır süs. Bu doküman başlangıç kurallarıdır; ölçüler ve tonlar gerçek kullanımda birlikte ayarlanır ([PLAN.md](PLAN.md) → "Çalışma biçimi"), **ilkeler ayarlanmaz.**

Kesinleşen üç karar (2026-09-20): **açık + ters koyu mod · saf monokrom · monospace.**

Görsel taslaklar (tema, masaüstü yerleşimi, panel halleri, hızlı ekleme, Odak, Triyaj): https://claude.ai/artifact/1tH8m1Dh9RfV5EDgpGskix — özel bağlantı, yalnızca sahibi açabilir. Bu doküman ile taslak çelişirse **bu doküman geçerlidir.**

## İlkeler

1. **Mürekkep ve kâğıt.** Ekranda yalnızca iki şey vardır: zemin ve onun üzerindeki mürekkep. Renk yok — ne vurgu, ne proje rengi, ne kırmızı uyarı.
2. **Anlam biçimden gelir.** Öncelik, durum, gecikme, seçim; hepsi tipografi ağırlığı, glif, çizgi ve **ters çevirme** ile anlatılır.
3. **Derinlik yok.** Gölge, bulanıklık (vibrancy/blur), saydamlık, gradyan, parlama yok. Katmanlar 1 px çizgiyle ayrılır. *(Tek istisna: yüzen panel — aşağıda.)*
4. **Hareket yok.** E-ink kare kare yenilenir: durumlar anında değişir. Geçiş animasyonu, yaylanma, solma yok.
5. **Metin arayüzdür.** İkon yerine kelime ve glif. Görünür buton minimumda — aksiyonlar klavyededir, arayüz yalnızca durumu gösterir.
6. **Boşluk hizalamadır.** Monospace ızgara: her şey karakter hücresine oturur; sütunlar kendiliğinden hizalanır.

## Palet

Her modda 4 ton; başka renk tanımlanmaz. Kod tarafında yalnızca bu dört isim kullanılır.

| Belirteç | Rol | Açık (varsayılan) | Koyu (ters) |
|---|---|---|---|
| `paper` | zemin | `#F2F0EA` | `#0F0F0E` |
| `ink` | ana metin, çizgi, dolgu | `#111111` | `#E6E3DB` |
| `ink2` | ikincil metin (tarih, proje, ipucu) | `#5A5852` | `#9A978E` |
| `ink3` | soluk: tamamlanmış, devre dışı, ince ayraç | `#8F8C84` | `#6E6B64` |

- Koyu mod açık modun **negatifidir**; sistem görünümünü izler, ayarlardan sabitlenebilir (açık / koyu / sistem).
- Saf beyaz ve saf siyah kullanılmaz: e-ink kâğıdı hafif kırık, mürekkebi hafif mat durur.
- `ink3` ilk taslaktan (`#A9A69E` / `#55534D`) koyulaştırıldı: tamamlanmış task metni okunabilir kalsın (≈3:1).
- Ara gri gerekiyorsa (ör. yük göstergesi) yeni ton eklenmez, **desen** kullanılır: `░ ▒ ▓ █`.

## Tipografi

- Tek aile, her yerde **monospace**. macOS: sistem monospace'i (SF Mono — `Font.system(design: .monospaced)`), font paketlemek gerekmez. Android: aşamaya gelince seçilir (aday: JetBrains Mono).
- Ölçek kısa tutulur: **13** (gövde, liste) · **11** (ikincil, ipucu) · **17** (mini panelde aktif task, ekran başlığı). Başka boyut eklemeden önce ağırlıkla çözmeyi dene.
- İki ağırlık: regular ve **bold**. İtalik yok. Hiyerarşi = ağırlık + `ink`/`ink2`/`ink3`.
- Büyük harf yalnızca kısa etiketlerde (`BUGÜN`, `TRİYAJ`), harf aralığı açılmadan.
- Uzun metin (not gövdesi) de monospace; satır uzunluğu ~72 karakterde sınırlanır.

## Anlam sözlüğü

Renk olmadığı için her anlamın sabit bir biçimi vardır:

| Anlam | Biçim |
|---|---|
| Task durumu | `[ ]` todo · `[~]` doing · `[!]` blocked · `[x]` done |
| Tamamlanmış | `ink3` + üstü çizili |
| Öncelik | `!1` **bold** `ink` · `!2` regular `ink` · `!3` `ink2` · `!4` gösterilmez |
| Gecikmiş (başlama günü geçmiş) | tarihi ters çevrilmiş etiket olarak: ▐`18.09`▌ (zemin `ink`, yazı `paper`) |
| Son tarih (`due_date`) | `son 25.09`, `ink2`; **bugün ya da geçmişse** ters çevrilmiş etiket: ▐`son 25.09`▌ |
| Açıklaması var | satır sonunda `≡`, `ink2` |
| Seçili satır / klavye imleci | **tüm satır ters çevrilir** (e-ink menülerindeki gibi) |
| Aktif task ("şu an bunu çalışıyorum") | satır başında `▸` |
| Alan | `iş` / `kş` kısa etiketi, `ink2` |
| Proje | `#ad`, `ink2` — hızlı ekleme sözdizimiyle aynı |
| Panel klavyeyi dinliyor | çerçeve 1 px → **2 px** |
| Hızlı eklemede algılanan token | altı çizili; çözülemeyen `#proje` altı **noktalı**; `//` sonrası açıklama `ink2` (çizgisiz) |
| Yük / ilerleme | blok karakterler: `████░░░░` |
| Boş durum | tek satır `ink3` metin (`sıradaki ne?`) — illüstrasyon yok |

## Bileşen kuralları

- **Çizgi:** 1 px `ink` (çerçeve) ya da 1 px `ink3` (liste ayraçları). Köşe yarıçapı **0** (yüzen panel hariç).
- **Hızlı ekleme paneli:** opak `paper`, 2 px `ink` çerçeve, kare köşe, gölge kapalı, başlık çubuğu yok.
- **Yüzen panel (mini + liste) — bilinçli istisna** *(kullanıcı kararı, 2026-09-20)*: bütün gün köşede, başka uygulamaların üstünde durduğu için daha yumuşak: köşe yarıçapı **10**; **pasifken %85 opak** (arkası hafifçe görünür), klavyeyi dinlerken **tam opak** + 2 px çerçeve. Geçiş anlıktır; gölge ve blur yine yok. Değerler `Theme.panelRadius` / `Theme.panelPassiveOpacity`.
- **Zamanlayıcı:** geriye doğru azalan dolu `ink` çubuk; akıcı değil **kademeli** küçülür (e-ink yenilemesi gibi, birkaç saniyede bir adım). Rakam yok.
- **Odak halkası:** sistem mavi halkası kapatılır; odak = 2 px `ink` çerçeve ya da ters çevirme.
- **Buton:** varsa köşeli parantezli metin — `[ekle]`; basılıyken ters çevrilir. Çoğu ekranda hiç yoktur.
- **Giriş alanı:** çerçevesiz, altında 1 px çizgi; imleç blok `█`.
- **Hızlı eklemede açıklama:** kısa not satır içinde `// …`; `Tab` başlığın altında çok satırlı açıklama alanını açar (`Shift+Enter` yeni satır, `Tab` başlığa döner, `Enter` her iki alandan da ekler).
- **Kısayol ipuçları:** ekranın altında tek satır `ink2`: `D tamamla · T süre · E detay · ? tümü`.
- **Onay geri bildirimi:** tek karelik ters çevirme "flaşı" (e-ink'in tam yenilemesine gönderme) — temadaki tek "hareket"; ayarlardan kapatılabilir.
- **Pencere düğmeleri:** sistemin renkli üçlüsü gizlenir; sol üstte `ink2` gliflerle `✕ – □` (kapat · küçült · tam ekran).
- **Task detayı:** seçili satırın altında, başlık sütunuyla hizalı açılır: **bold** başlık, açıklama, 1 px çizgi, sonra `ad  değer` satırları (durum, öncelik, başla, son, proje, alan). Ayrı pencere ya da yan panel yok.
- **Projeler:** solda liste (`ad · alan · durum`; bitmiş proje `ink3`). Bu ekranda `#` öneki yoktur — ad zaten proje olduğunu söyler; `#ad` yazımı task/not satırlarında ve hızlı ekleme sözdiziminde kalır, sağda seçili projenin **tanımı**. Tanım düzenlenirken alan 2 px çerçeve alır; kaydet düğmesi yok, yazarken kendiliğinden kaydedilir.
- **Notlar (sticky düzen):** sabit yükseklikte (176) kart ızgarası; sütun sayısı genişliğe göre. Kart: **bold** başlık · `ink2` gövde · altta `tarih · #proje`. Renk yok: **sabitlenen not 2 px çerçeve + `▪ sabit`** ile ayrışır ve en başta durur; seçili kart tümüyle ters çevrilir. Editör tam alandır: ilk satır başlık.
- **Hızlı not paneli:** hızlı eklemeyle aynı konum ve çerçeve; çok satırlı alan, `↵` kaydeder (panel açık kalır), `⇧↵` yeni satır; ilk satırdaki `#proje` altı çizilir.
- **Simge:** uygulama, menü çubuğu ve dock simgeleri de tek renk, düz, glif tabanlı. SF Symbols kullanılmaz; gerekirse Unicode glif (`▸ ✕ ░ █ ↑ ↓`).

## Yerleşim

Kararlar (2026-09-20), taslaktaki "Masaüstünde konumlar" panosuna karşılık gelir:

| Öğe | Konum ve davranış |
|---|---|
| Menü çubuğu öğesi | `▸ 3/7` — `▸` aktif task varsa görünür; `3/7` bugün biten / toplam. Task adı yazılmaz. |
| Mini panel | İlk açılışta **sağ üst** köşe (menü çubuğunun altı, kenarlardan 20 px); sürüklenebilir, konumu hatırlanır. Genişlik 320 px. |
| Uzun başlık | Tek satıra sığıyorsa 17 bold. Sığmıyorsa **13 bold, en çok iki satır**; fazlası `…` ile kesilir (tamamı geniş halde görünür). |
| Liste paneli | Mini panelin **yerini alır**: aynı köşeye sabitlenir, oradan büyür (üst köşede aşağı, alt köşede yukarı doğru). İkisi aynı anda görünmez. `Esc` → mini panele döner. |
| Hızlı ekleme | Ekranın yatay ortası, üst üçte bir (Spotlight konumu); 640 px. |
| Ana pencere | Normal pencere. Sol kenar çubuğu (`⌘1`–`⌘6` görünümler) **sürekli açık**; ileride yeniden ele alınabilir. |

## Örnek — liste paneli

```
┌──────────────────────────────────────┐
│ BUGÜN · 20.09 Paz            iş  3/7 │
│ ████████░░░░░░░░░░░░                 │
├──────────────────────────────────────┤
│ ▸ [~] !1 Teklifi gönder      #acme   │
│▐  [ ] !2 Faturayı öde        #finans▌│  ← seçili satır: ters çevrilmiş
│   [ ]    Süt al                      │
│   [!]    Sunucu yedeği   ▐18.09▌     │
│   [x]    ̶T̶o̶p̶l̶a̶n̶t̶ı̶ ̶n̶o̶t̶l̶a̶r̶ı̶               │
├──────────────────────────────────────┤
│ D tamamla · ↵ aktif · Y yarına · ?   │
└──────────────────────────────────────┘
```

## Örnek — mini panel (zamanlayıcı çalışırken)

```
┌──────────────────────────────┐
│ Teklifi gönder               │
│ ██████████████░░░░░░░░░░░░░░ │
└──────────────────────────────┘
```

## Uygulama notu (macOS)

Tema tek yerde yaşar: `Theme` (dört renk belirteci, üç yazı boyutu, çizgi kalınlıkları) + az sayıda ortak görünüm (`InkRow`, `InkPanel`, `InkBar`…). Ekranlar `Color`/`Font` sabitlerini doğrudan kullanmaz → tonlar ve ölçüler kullanım sırasında tek dosyadan ayarlanır. SwiftUI varsayılanları (vurgu rengi, odak halkası, liste seçimi, buton stili, geçiş animasyonları) uygulama kökünde kapatılır/ezilir.
