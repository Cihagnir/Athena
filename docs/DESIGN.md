# Tasarım Teması — "E-ink"

Bütün uygulama (macOS, ileride Android) bir **e-mürekkep ekran** gibi görünür ve davranır: kâğıt zemin, siyah mürekkep, sıfır süs. Bu doküman başlangıç kurallarıdır; ölçüler ve tonlar gerçek kullanımda birlikte ayarlanır ([PLAN.md](PLAN.md) → "Çalışma biçimi"), **ilkeler ayarlanmaz.**

Kesinleşen üç karar (2026-09-20): **açık + ters koyu mod · saf monokrom · monospace.**

## İlkeler

1. **Mürekkep ve kâğıt.** Ekranda yalnızca iki şey vardır: zemin ve onun üzerindeki mürekkep. Renk yok — ne vurgu, ne proje rengi, ne kırmızı uyarı.
2. **Anlam biçimden gelir.** Öncelik, durum, gecikme, seçim; hepsi tipografi ağırlığı, glif, çizgi ve **ters çevirme** ile anlatılır.
3. **Derinlik yok.** Gölge, bulanıklık (vibrancy/blur), saydamlık, gradyan, parlama yok. Katmanlar 1 px çizgiyle ayrılır.
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
| `ink3` | soluk: tamamlanmış, devre dışı, ince ayraç | `#A9A69E` | `#55534D` |

- Koyu mod açık modun **negatifidir**; sistem görünümünü izler, ayarlardan sabitlenebilir (açık / koyu / sistem).
- Saf beyaz ve saf siyah kullanılmaz: e-ink kâğıdı hafif kırık, mürekkebi hafif mat durur.
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

- **Çizgi:** 1 px `ink` (çerçeve) ya da 1 px `ink3` (liste ayraçları). Köşe yarıçapı **0**; pencere/panel dış köşesi de kare.
- **Paneller (`NSPanel`):** opak `paper`, 1 px `ink` çerçeve, gölge kapalı (`hasShadow = false`), başlık çubuğu yok.
- **Zamanlayıcı:** geriye doğru azalan dolu `ink` çubuk; akıcı değil **kademeli** küçülür (e-ink yenilemesi gibi, birkaç saniyede bir adım). Rakam yok.
- **Odak halkası:** sistem mavi halkası kapatılır; odak = 2 px `ink` çerçeve ya da ters çevirme.
- **Buton:** varsa köşeli parantezli metin — `[ekle]`; basılıyken ters çevrilir. Çoğu ekranda hiç yoktur.
- **Giriş alanı:** çerçevesiz, altında 1 px çizgi; imleç blok `█`.
- **Hızlı eklemede açıklama:** kısa not satır içinde `// …`; `Tab` başlığın altında çok satırlı açıklama alanını açar (`Shift+Enter` yeni satır, `Tab` başlığa döner, `Enter` her iki alandan da ekler).
- **Kısayol ipuçları:** ekranın altında tek satır `ink2`: `D tamamla · T süre · E detay · ? tümü`.
- **Onay geri bildirimi:** tek karelik ters çevirme "flaşı" (e-ink'in tam yenilemesine gönderme) — temadaki tek "hareket"; ayarlardan kapatılabilir.
- **Simge:** uygulama, menü çubuğu ve dock simgeleri de tek renk, düz, glif tabanlı. SF Symbols kullanılmaz; gerekirse Unicode glif (`▸ ✕ ░ █ ↑ ↓`).

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
