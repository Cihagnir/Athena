# Deploy — `<sunucu>` + Cloudflare Tunnel

Backend sunucuda Docker ile çalışır ve internete **`https://tasks.example.com`** adresinden, Cloudflare Tunnel üzerinden açılır. İlk kurulum 2026-09-21'de yapıldı; bu doküman hem ne kurulduğunu hem de tekrar nasıl yapılacağını anlatır.

Gerekçeler: [DECISIONS.md](DECISIONS.md) madde 14.

## Şu anki durum

| | |
|---|---|
| Sunucu | `<sunucu>` — Ubuntu 26.04, x86_64 · `ssh <sunucu>` (Tailscale SSH; Mac'te Tailscale açık olmalı) |
| Konum | `~/task-tracker/` (izin 700) → `backend/` (kod) · `data/` (veri) |
| Container'lar | `task-tracker-pb` (PocketBase, `127.0.0.1:8091`) · `task-tracker-tunnel` (cloudflared) |
| Adres | `https://tasks.example.com` — tünel `task-tracker` (`<TUNNEL-UUID>`), DNS kaydı CNAME |
| Veri | **Taşındı (2026-09-21).** Asıl veri artık sunucuda; Mac uygulaması `https://tasks.example.com`'a bağlı. Yereldeki PocketBase container'ı durduruldu (silinmedi) — yalnızca geliştirme/test için: `cd backend && docker compose start`. |

Sunucuda başka projelere ait container'lar da çalışır (`balls_of_cerberus…` → 8090, `marketplace-distribution…` + Gitea → 8080). Onlara dokunulmaz; task_tracker bu yüzden **8091** portunu kullanır. Gitea'nın kendi tüneli (`git.example.com`) ayrıdır ve bu kurulumdan etkilenmez.

## Mimari

```
Mac / Android ──https──▶ Cloudflare ──tünel──▶ task-tracker-tunnel ──▶ task-tracker-pb:8090
   X-API-Key + oturum token'ı              (cloudflared container)      (PocketBase)
                                                                              │
                                              ~/task-tracker/data  ◀──────────┘  (SQLite dosyaları)
```

- **Veri imajdan bağımsızdır.** İmajda yalnızca PocketBase binary'si vardır. Veritabanı `PB_DATA` ile bağlanan `~/task-tracker/data` klasöründe düz dosyalardır (`data.db`, `auxiliary.db`, `backups/`). Şema ve iş mantığı (`pb_migrations/`, `pb_hooks/`) koddan bağlanır. İmajı silmek, yeniden derlemek ya da sürüm yükseltmek veriye dokunmaz.
- **Tünel compose'un içindedir** (`tunnel` servisi, `--profile tunnel`): systemd ya da `sudo` gerekmez, PocketBase'e compose ağı üzerinden ulaşır (`http://pocketbase:8090`). Sunucudaki `cloudflared` CLI yalnızca tüneli ve DNS kaydını oluşturmak için kullanıldı.
- Sunucunun saat dilimi UTC'dir; container kendi `TZ=Europe/Istanbul` ayarını taşır ("bugün" doğru hesaplanır).

## Güvenlik katmanları

Servis internete açıktır. Dıştan içe:

1. **Cloudflare** — TLS, DDoS koruması; sunucunun IP'si ve hiçbir portu dışarıya açık değildir (tünel içeriden dışarıya bağlanır, PocketBase portu yalnızca `127.0.0.1`'de).
2. **Yönetim paneli kapalı** — tünel kuralı `^/_/` yolunu `404` ile keser (anahtarla bile). Panele erişim: aşağıda.
3. **API anahtarı** — `TT_API_KEYS` doluysa tünelden gelen **her** istek (giriş ve realtime dahil) `X-API-Key` başlığında geçerli bir anahtar taşımalıdır; yoksa `403`. Kontrol diğer her şeyden önce çalışan bir ara katmandadır (`pb_hooks/main.pb.js`), sabit süreli karşılaştırma yapar. Tünelden geçmeyen istekler (sunucunun kendi `127.0.0.1`'i, SSH tüneli) anahtarsız çalışır — o yola yalnızca makineye erişimi olan ulaşır.
4. **Oturum** — anahtar tek başına veri açmaz; ayrıca kullanıcı girişi gerekir (`401`). Kayıt (sign-up) kapalıdır, tek kullanıcı vardır.
5. **Hız sınırlayıcı** (`TT_PUBLIC=1`) — giriş uç noktası 3 sn'de 2 deneme, genel API 10 sn'de 300 istek; gerçek istemci IP'si `CF-Connecting-IP` başlığından okunur.

Bilinen sınır: anahtarsız istekler Cloudflare'de değil **bizim kodumuzda** reddedilir, yani PocketBase sürecine ulaşırlar. Daha sıkı bir kapı istenirse önüne Cloudflare Access konabilir (uygulama zaten her isteğe özel başlık ekleyebiliyor).

**Anahtar yönetimi:** anahtarlar `~/task-tracker/backend/.env` → `TT_API_KEYS` içinde, virgülle ayrılmış. Cihaz başına ayrı anahtar önerilir (Mac, telefon): biri kaybolursa yalnızca o satırdan silinir. Yeni anahtar: `openssl rand -hex 32` → `.env`'e ekle → `docker compose up -d` (env değişikliği için `restart` yetmez).

## Mac uygulamasını sunucuya bağlamak

Ayarlar (`⌘,`) → Sunucu:

- **Adres:** `https://tasks.example.com`
- **API anahtarı:** sunucudaki `.env` → `TT_API_KEYS`
- `bağlan` → giriş ekranı gelir: e-posta / parola sunucudaki `.env` → `TT_USER_*` (veri taşındıktan sonra: **yereldeki** parola — aşağıya bak).

```sh
ssh <sunucu> 'grep -E "^(TT_API_KEYS|TT_USER_)" ~/task-tracker/backend/.env'
```

Yerele dönmek: adres `http://127.0.0.1:8090`, anahtar boş.

## Güncelleme göndermek

```sh
scripts/deploy.sh
```

`backend/`'i `rsync` ile gönderir (sunucudaki `.env`, `tunnel/` ve veri klasörüne **dokunmaz**), imajı gerekiyorsa yeniden derler, PocketBase'i yeniden başlatır (hook/migration değişiklikleri yüklensin diye) ve sağlık kontrolü yapar. Kod şimdilik yalnızca bu Mac'teki git deposundadır; uzak depo eklenince akış değişmez.

Doğrulama (internete açık adrese karşı, API anahtarıyla):

```sh
cd macos/Core
TT_URL=https://tasks.example.com TT_API_KEY=… TT_EMAIL=… TT_PASSWORD=… swift test
```

19 test; giriş tek kez yapılır (hız sınırlayıcı). Testler kendi kayıtlarını siler.

## Veriyi taşımak (2026-09-21'de yapıldı)

Yerelde yeniden veri birikirse ya da başka bir sunucuya geçilirse aynı betik kullanılır. **Dikkat:** betik sunucudaki veriyi yereldekiyle *değiştirir*; asıl veri sunucudayken çalıştırmak sunucudaki yeni kayıtları kenara alır (`data.before-…`).


```sh
scripts/migrate-data.sh --dry-run    # arşivi üretir, sunucuya yollar, içeriğini listeler, siler
scripts/migrate-data.sh              # gerçek taşıma
```

Yerel PocketBase birkaç saniye durdurulur (tutarlı kopya), veri arşivlenip sunucuya gönderilir. Arşiv önce ayrı bir klasöre açılır, yer değiştirme yalnızca açma başarılıysa yapılır; sunucudaki mevcut veri silinmez, `~/task-tracker/data.before-<zaman>` olarak kenara alınır. **Kullanıcı kaydı da taşınır:** sunucuda giriş parolası yereldeki parola (`backend/.env` → `TT_USER_PASSWORD`) olur. API anahtarı ve yönetici (superuser) hesabı sunucunun `.env`'inden gelir, değişmez. Taşımadan sonra Mac uygulamasının adresini değiştir; yerel kurulum yedek olarak kalabilir.

## Yedekler

- **Otomatik:** her gün 04:00'te PocketBase yedeği, son 14 tanesi tutulur → `~/task-tracker/data/backups/*.zip` (`TT_PUBLIC=1` iken açılışta ayarlanır).
- **Bu yedekler sunucuyla aynı disktedir.** Sunucu dışı kopya henüz kurulmadı. En basit yol, Mac'ten ara sıra çekmek:

  ```sh
  rsync -az <sunucu>:task-tracker/data/backups/ ~/Backups/task-tracker/
  ```

- Taşımadan kalan `~/task-tracker/data.before-*` klasörleri sorun çıkmadıysa silinebilir (ilki boş ilk kurulum, ikincisi taşınan verinin kopyası).
- Geri yükleme: PocketBase'i durdur → zip'i boş bir `data/` klasörüne aç → başlat. (Ya da yönetim panelinden Backups → Restore.)

## Yönetim paneli

İnternetten kapalıdır. Mac'ten SSH tüneliyle:

```sh
ssh -N -L 8091:127.0.0.1:8091 <sunucu>     # açık kalsın
open http://127.0.0.1:8091/_/                   # giriş: sunucudaki .env → PB_SUPERUSER_*
```

## Sorun giderme

```sh
ssh <sunucu> 'cd ~/task-tracker/backend && docker compose --profile tunnel ps && docker compose logs --tail 30'
ssh <sunucu> 'docker logs --tail 20 task-tracker-tunnel'
```

| Belirti | Bakılacak yer |
|---|---|
| `403` | API anahtarı eksik/yanlış; `.env` değiştiyse `docker compose up -d` yapıldı mı? |
| `429` | Hız sınırlayıcı — kısa sürede çok giriş denemesi |
| `502` / `530` | Tünel ya da PocketBase container'ı ayakta mı? |
| Uygulama "sunucuya ulaşılamadı" | Adres `https://` ile mi; Cloudflare durumu |

## Sıfırdan kurulum (başka bir sunucuda tekrarlamak için)

1. Sunucuda Docker + Compose, `cloudflared` CLI ve `cloudflared tunnel login` (→ `~/.cloudflared/cert.pem`).
2. `scripts/deploy.sh` dosyaları gönderir ve `.env yok` diye durur. Sunucuda `backend/.env.example`'dan `.env` oluştur: `PB_PORT` (boş bir port), `PB_DATA=/home/<kullanıcı>/task-tracker/data`, `TT_PUBLIC=1`, parolalar ve anahtar için `openssl rand -hex 16/32`; `chmod 600 .env`.
3. Tünel:
   ```sh
   cloudflared tunnel create task-tracker
   cloudflared tunnel route dns task-tracker tasks.<alan-adı>
   mkdir -p ~/task-tracker/backend/tunnel
   cp ~/.cloudflared/<UUID>.json ~/task-tracker/backend/tunnel/credentials.json && chmod 644 …/credentials.json
   # tunnel/config.yml ← backend/tunnel/config.example.yml (UUID ve alan adını yaz)
   cloudflared tunnel --config tunnel/config.yml ingress validate
   ```
   Kimlik dosyası 644'tür çünkü cloudflared container'ı root değildir; üst klasör (`~/task-tracker`) 700 olduğu için sunucudaki diğer kullanıcılar okuyamaz.
4. `scripts/deploy.sh` → `tunnel/config.yml` varsa tüneli de başlatır.

## Sunucuda fark edilen, bu projeyle ilgisiz bir sorun

`cloudflared.service` adlı systemd birimi birkaç saniyede bir çöküp yeniden başlıyor (`/etc/cloudflared/token` dosyası yok). Çalışan tünellerle ilgisi yok, zararsız ama logları dolduruyor. Dokunulmadı; kapatmak için: `sudo systemctl disable --now cloudflared`.
