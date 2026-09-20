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
