// API anahtarı — internete açık kurulumun ilk kapısı. Diğer her şeyden önce çalışır.
//
// TT_API_KEYS (virgülle ayrılmış) doluysa, Cloudflare Tunnel üzerinden gelen her istek
// (`CF-Connecting-IP` başlığı taşır) `X-API-Key` başlığında bu anahtarlardan birini
// göstermek zorundadır; yoksa 403. Tünelden geçmeyen istekler (sunucunun kendi
// 127.0.0.1'i, SSH tüneli, yerel geliştirme) anahtarsız çalışır — port yalnızca
// loopback'e açık olduğu için o yola zaten yalnızca makineye erişimi olan ulaşır.
// Başlığı elle eklemek yalnızca kuralı sıkılaştırır, gevşetemez.
routerUse(new Middleware((e) => {
    const keys = String($os.getenv("TT_API_KEYS") || "").split(",").map((k) => k.trim()).filter((k) => k.length > 0)
    if (keys.length === 0 || !e.request.header.get("Cf-Connecting-Ip")) return e.next()

    // Sabit süreli karşılaştırma: uzunluk ve içerik farkı zamanlamadan okunmasın.
    const safeEqual = (a, b) => {
        let diff = a.length ^ b.length
        for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i % Math.max(b.length, 1))
        return diff === 0
    }
    const given = String(e.request.header.get("X-Api-Key") || "")
    let allowed = false
    for (let i = 0; i < keys.length; i++) if (safeEqual(keys[i], given)) allowed = true
    if (!allowed) throw new ForbiddenError("Geçerli bir API anahtarı gerekli.")
    return e.next()
}, -10000))

// Uygulama koleksiyonlarına girişsiz istek 401 alır. (PocketBase varsayılanında kural
// tutmayan liste isteği 200 + boş liste döner; sözleşme basit kalsın diye burada kesilir.)
routerUse((e) => {
    const guarded = /^\/api\/collections\/(projects|tasks|notes|focus_state)\//
    if (guarded.test(e.request.url.path) && !e.auth) {
        throw new UnauthorizedError("Giriş gerekli.")
    }
    return e.next()
})

// Tek uygulama kullanıcısı .env'den; yoksa oluşturulur. Kayıt (sign-up) kapalıdır.
// (JSVM'de onServe yok; bootstrap tamamlandıktan sonra çalışır. entrypoint önce
// `superuser upsert` koştuğu için bu noktada migration'lar uygulanmış olur.)
onBootstrap((e) => {
    e.next()

    // İnternete açık kurulum (TT_PUBLIC=1): gerçek istemci IP'si Cloudflare başlığından
    // okunur ve PocketBase'in yerleşik hız sınırlayıcısı açılır.
    if ($os.getenv("TT_PUBLIC") === "1") {
        try {
            const settings = $app.settings()
            settings.trustedProxy.headers = ["CF-Connecting-IP"]
            settings.rateLimits.enabled = true
            // Günlük otomatik yedek (04:00, son 14 tanesi) → pb_data/backups. Aynı diskte durur;
            // sunucu dışı kopya için docs/DEPLOY.md → Yedekler.
            settings.backups.cron = "0 4 * * *"
            settings.backups.cronMaxKeep = 14
            $app.save(settings)
        } catch (err) {
            console.log("public ayarları uygulanamadı:", err)
        }
    }

    const email = $os.getenv("TT_USER_EMAIL")
    const password = $os.getenv("TT_USER_PASSWORD")
    if (!email || !password) return
    try {
        $app.findAuthRecordByEmail("users", email)
        return
    } catch (_) {}
    try {
        const user = new Record($app.findCollectionByNameOrId("users"))
        user.set("email", email)
        user.set("password", password)
        user.set("verified", true)
        $app.save(user)
        console.log("kullanıcı oluşturuldu:", email)
    } catch (err) {
        console.log("kullanıcı oluşturulamadı:", err)
    }
})
