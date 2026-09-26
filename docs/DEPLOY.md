# Deploy — kendi sunucun + Cloudflare Tunnel

Backend sunucuda Docker ile çalışır ve internete `https://tasks.<alan-adı>` gibi bir adresten, Cloudflare Tunnel üzerinden açılır. Bu doküman kurulumu sıfırdan anlatır; yalnızca yerelde kullanacaksan gerekmez ([../README.md](../README.md) → `local-dev`).

Gerekçeler: [DECISIONS.md](DECISIONS.md) madde 14.

Bu dokümanda `<sunucu>` = `ssh <sunucu>` ile eriştiğin makine adı (Tailscale, `~/.ssh/config` ya da IP), `<alan-adı>` = Cloudflare'de yönettiğin alan adı.

## Mimari

```
Mac / Android ──https──▶ Cloudflare ──tünel──▶ task-tracker-tunnel ──▶ task-tracker-pb:8090
   X-API-Key + oturum token'ı              (cloudflared container)      (PocketBase)
                                                                              │
                                              ~/task-tracker/data  ◀──────────┘  (SQLite dosyaları)
```

- **Veri imajdan bağımsızdır.** İmajda yalnızca PocketBase binary'si vardır. Veritabanı `PB_DATA` ile bağlanan `~/task-tracker/data` klasöründe düz dosyalardır (`data.db`, `auxiliary.db`, `backups/`). Şema ve iş mantığı (`pb_migrations/`, `pb_hooks/`) koddan bağlanır. İmajı silmek, yeniden derlemek ya da sürüm yükseltmek veriye dokunmaz.
- **Tünel compose'un içindedir** (`tunnel` servisi, `--profile tunnel`): systemd ya da `sudo` gerekmez, PocketBase'e compose ağı üzerinden ulaşır (`http://pocketbase:8090`). Sunucudaki `cloudflared` CLI yalnızca tüneli ve DNS kaydını oluşturmak için kullanılır.
- PocketBase portu yalnızca `127.0.0.1`'e bağlanır; sunucuda başka servisler varsa `PB_PORT` ile boş bir port seçilir.
- Container kendi `TZ` ayarını taşır; sunucunun saat dilimi UTC olsa da "bugün" doğru hesaplanır.

## Güvenlik katmanları

Servis internete açıktır. Dıştan içe:

1. **Cloudflare** — TLS, DDoS koruması; sunucunun IP'si ve hiçbir portu dışarıya açık değildir (tünel içeriden dışarıya bağlanır).
2. **Yönetim paneli kapalı** — tünel kuralı `^/_/` yolunu `404` ile keser (anahtarla bile). Panele erişim: aşağıda.
3. **API anahtarı** — `TT_API_KEYS` doluysa tünelden gelen **her** istek (giriş ve realtime dahil) `X-API-Key` başlığında geçerli bir anahtar taşımalıdır; yoksa `403`. Kontrol diğer her şeyden önce çalışan bir ara katmandadır (`pb_hooks/main.pb.js`), sabit süreli karşılaştırma yapar. Tünelden geçmeyen istekler (sunucunun kendi `127.0.0.1`'i, SSH tüneli) anahtarsız çalışır — o yola yalnızca makineye erişimi olan ulaşır.
4. **Oturum** — anahtar tek başına veri açmaz; ayrıca kullanıcı girişi gerekir (`401`). Kayıt (sign-up) kapalıdır, tek kullanıcı vardır.
5. **Hız sınırlayıcı** (`TT_PUBLIC=1`) — giriş uç noktası 3 sn'de 2 deneme, genel API 10 sn'de 300 istek; gerçek istemci IP'si `CF-Connecting-IP` başlığından okunur.

Bilinen sınır: anahtarsız istekler Cloudflare'de değil **bizim kodumuzda** reddedilir, yani PocketBase sürecine ulaşırlar. Daha sıkı bir kapı istenirse önüne Cloudflare Access konabilir (uygulama zaten her isteğe özel başlık ekleyebiliyor).

**Anahtar yönetimi:** anahtarlar sunucudaki `~/task-tracker/backend/.env` → `TT_API_KEYS` içinde, virgülle ayrılmış. Cihaz başına ayrı anahtar önerilir (Mac, telefon): biri kaybolursa yalnızca o satırdan silinir. Yeni anahtar: `openssl rand -hex 32` → `.env`'e ekle → `docker compose up -d` (env değişikliği için `restart` yetmez).

## Sıfırdan kurulum

1. Sunucuda Docker + Compose, `cloudflared` CLI ve `cloudflared tunnel login` (→ `~/.cloudflared/cert.pem`).
2. Mac'te sunucu adını ver ve dosyaları gönder:
   ```sh
   export TT_DEPLOY_HOST=<sunucu>        # her deploy.sh / migrate-data.sh çağrısı bunu ister
   scripts/deploy.sh                     # dosyaları gönderir, `.env yok` diye durur
   ```
3. Sunucuda `backend/.env.example`'dan `.env` oluştur: `PB_PORT` (boş bir port), `PB_DATA=/home/<kullanıcı>/task-tracker/data`, `TT_PUBLIC=1`, parolalar ve anahtar için `openssl rand -hex 16/32`; `chmod 600 .env`.
4. Tünel (sunucuda):
   ```sh
   cloudflared tunnel create task-tracker
   cloudflared tunnel route dns task-tracker tasks.<alan-adı>
   mkdir -p ~/task-tracker/backend/tunnel
   cp ~/.cloudflared/<UUID>.json ~/task-tracker/backend/tunnel/credentials.json && chmod 644 ~/task-tracker/backend/tunnel/credentials.json
   # tunnel/config.yml ← backend/tunnel/config.example.yml (UUID ve alan adını yaz)
   cloudflared tunnel --config tunnel/config.yml ingress validate
   ```
   Kimlik dosyası 644'tür çünkü cloudflared container'ı root değildir; üst klasör (`~/task-tracker`, izin 700) diğer kullanıcılardan korur.
5. `scripts/deploy.sh` → `tunnel/config.yml` varsa tüneli de başlatır ve sağlık kontrolü yapar.

## Mac uygulamasını sunucuya bağlamak

Ayarlar (`⌘,`) → Sunucu:

- **Adres:** `https://tasks.<alan-adı>`
- **API anahtarı:** sunucudaki `.env` → `TT_API_KEYS`
- `bağlan` → giriş ekranı gelir: e-posta / parola sunucudaki `.env` → `TT_USER_*` (veri taşındıysa **yereldeki** parola — aşağıya bak).

```sh
ssh <sunucu> 'grep -E "^(TT_API_KEYS|TT_USER_)" ~/task-tracker/backend/.env'
```

Yerele dönmek: adres `http://127.0.0.1:8090`, anahtar boş.

## Güncelleme göndermek

```sh
TT_DEPLOY_HOST=<sunucu> scripts/deploy.sh
```

`backend/`'i `rsync` ile gönderir (sunucudaki `.env`, `tunnel/` ve veri klasörüne **dokunmaz**), imajı gerekiyorsa yeniden derler, PocketBase'i yeniden başlatır (hook/migration değişiklikleri yüklensin diye) ve sağlık kontrolü yapar.

Doğrulama (internete açık adrese karşı, API anahtarıyla):

```sh
cd macos/Core
TT_URL=https://tasks.<alan-adı> TT_API_KEY=… TT_EMAIL=… TT_PASSWORD=… swift test
```

19 test; giriş tek kez yapılır (hız sınırlayıcı). Testler kendi kayıtlarını siler.

## Yerel veriyi sunucuya taşımak

Önce yerelde kullanıp sonra sunucuya geçiyorsan, ya da başka bir sunucuya taşınıyorsan. **Dikkat:** betik sunucudaki veriyi yereldekiyle *değiştirir*; asıl veri sunucudayken çalıştırmak sunucudaki yeni kayıtları kenara alır (`data.before-…`).

```sh
TT_DEPLOY_HOST=<sunucu> scripts/migrate-data.sh --dry-run    # arşivi üretir, sunucuya yollar, içeriğini listeler, siler
TT_DEPLOY_HOST=<sunucu> scripts/migrate-data.sh              # gerçek taşıma
```

Yerel PocketBase birkaç saniye durdurulur (tutarlı kopya), veri arşivlenip sunucuya gönderilir. Arşiv önce ayrı bir klasöre açılır, yer değiştirme yalnızca açma başarılıysa yapılır; sunucudaki mevcut veri silinmez, `~/task-tracker/data.before-<zaman>` olarak kenara alınır. **Kullanıcı kaydı da taşınır:** sunucuda giriş parolası yereldeki parola (`backend/.env` → `TT_USER_PASSWORD`) olur. API anahtarı ve yönetici (superuser) hesabı sunucunun `.env`'inden gelir, değişmez. Taşımadan sonra Mac uygulamasının adresini değiştir; yerel kurulum yedek olarak kalabilir.

## Yedekler

- **Otomatik:** her gün 04:00'te PocketBase yedeği, son 14 tanesi tutulur → `~/task-tracker/data/backups/*.zip` (`TT_PUBLIC=1` iken açılışta ayarlanır).
- **Bu yedekler sunucuyla aynı disktedir.** Sunucu dışı kopya için en basit yol, ara sıra çekmek:

  ```sh
  rsync -az <sunucu>:task-tracker/data/backups/ ~/Backups/task-tracker/
  ```

- Taşımadan kalan `~/task-tracker/data.before-*` klasörleri sorun çıkmadıysa silinebilir.
- Geri yükleme: PocketBase'i durdur → zip'i boş bir `data/` klasörüne aç → başlat. (Ya da yönetim panelinden Backups → Restore.)

## Yönetim paneli

İnternetten kapalıdır. SSH tüneliyle (`PB_PORT` 8090 varsayıldı):

```sh
ssh -N -L 8090:127.0.0.1:8090 <sunucu>     # açık kalsın
open http://127.0.0.1:8090/_/               # giriş: sunucudaki .env → PB_SUPERUSER_*
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
