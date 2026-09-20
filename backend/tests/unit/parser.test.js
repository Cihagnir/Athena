const test = require("node:test")
const assert = require("node:assert/strict")
const { parse, matchProject, fold } = require("../../pb_hooks/lib/parser.js")

// 2026-09-23 = Çarşamba
const TODAY = "2026-09-23"
const PROJECTS = [
    { id: "p1", name: "Finans", area: "personal" },
    { id: "p2", name: "Ev İşleri", area: "personal" },
    { id: "p3", name: "Evrak", area: "work" },
]
const p = (text, today) => parse(text, { today: today || TODAY, projects: PROJECTS })

test("plandaki örnek satır", () => {
    const r = p("Faturayı öde yarın !1 #finans @kişisel")
    assert.equal(r.title, "Faturayı öde")
    assert.equal(r.scheduled_date, "2026-09-24")
    assert.equal(r.priority, 1)
    assert.deepEqual(r.project, { id: "p1", name: "Finans", area: "personal" })
    assert.equal(r.area, "personal")
    assert.equal(r.valid, true)
    assert.deepEqual(r.warnings, [])
})

test("token'sız düz metin: başlık aynen kalır, alanlar boş", () => {
    const r = p("Süt al")
    assert.equal(r.title, "Süt al")
    assert.equal(r.scheduled_date, null)
    assert.equal(r.priority, null)
    assert.equal(r.project, null)
    assert.equal(r.area, null)
    assert.deepEqual(r.tokens, [])
})

test("bugün / yarın, ASCII ve büyük harf varyantları", () => {
    assert.equal(p("x bugün").scheduled_date, "2026-09-23")
    assert.equal(p("x bugun").scheduled_date, "2026-09-23")
    assert.equal(p("x YARIN").scheduled_date, "2026-09-24")
    assert.equal(p("x yarin").scheduled_date, "2026-09-24")
})

test("gün adları bir sonraki o güne gider", () => {
    assert.equal(p("x pzt").scheduled_date, "2026-09-28")
    assert.equal(p("x pazartesi").scheduled_date, "2026-09-28")
    assert.equal(p("x salı").scheduled_date, "2026-09-29")
    assert.equal(p("x per").scheduled_date, "2026-09-24")
    assert.equal(p("x cuma").scheduled_date, "2026-09-25")
    assert.equal(p("x cmt").scheduled_date, "2026-09-26")
    assert.equal(p("x paz").scheduled_date, "2026-09-27")
    assert.equal(p("x PAZARTESİ").scheduled_date, "2026-09-28")
})

test("bugünün gün adı haftaya aynı güne gider (bugün için 'bugün' var)", () => {
    assert.equal(p("x çar").scheduled_date, "2026-09-30")
    assert.equal(p("x carsamba").scheduled_date, "2026-09-30")
})

test("ay ve yıl sınırı", () => {
    assert.equal(p("x cuma", "2026-09-29").scheduled_date, "2026-10-02")
    assert.equal(p("x yarın", "2026-12-31").scheduled_date, "2027-01-01")
})

test("sayısal tarih: GG.AA ve GG.AA.YYYY", () => {
    assert.equal(p("x 25.09").scheduled_date, "2026-09-25")
    assert.equal(p("x 5.10").scheduled_date, "2026-10-05")
    assert.equal(p("x 25/09").scheduled_date, "2026-09-25")
    assert.equal(p("x 25.09.2027").scheduled_date, "2027-09-25")
    assert.equal(p("x 23.09").scheduled_date, "2026-09-23")
})

test("yılsız geçmiş tarih gelecek yıla yuvarlanır", () => {
    assert.equal(p("x 01.03").scheduled_date, "2027-03-01")
})

test("geçersiz tarih token sayılmaz, başlıkta kalır", () => {
    const r = p("Sürüm 31.02 notları")
    assert.equal(r.scheduled_date, null)
    assert.equal(r.title, "Sürüm 31.02 notları")
})

test("öncelik yalnızca !1–!4", () => {
    assert.equal(p("x !4").priority, 4)
    const r = p("x !5 !")
    assert.equal(r.priority, null)
    assert.equal(r.title, "x !5 !")
})

test("alan: Türkçe, ASCII, büyük harf", () => {
    assert.equal(p("x @iş").area, "work")
    assert.equal(p("x @is").area, "work")
    assert.equal(p("x @İŞ").area, "work")
    assert.equal(p("x @kisisel").area, "personal")
    const r = p("x @ahmet")
    assert.equal(r.area, null)
    assert.equal(r.title, "x @ahmet")
})

test("alan verilmezse projeden miras alınır; verilirse ezilmez", () => {
    assert.equal(p("x #evrak").area, "work")
    assert.equal(p("x #evrak @kişisel").area, "personal")
})

test("proje eşleşmesi: tam ad, boşluk yerine tire, tekil önek", () => {
    assert.equal(p("x #ev-işleri").project.id, "p2")
    assert.equal(p("x #ev-isleri").project.id, "p2")
    assert.equal(p("x #fin").project.id, "p1")
    assert.equal(p("x #evr").project.id, "p3")
})

test("belirsiz önek ve bilinmeyen proje: başlıkta kalır + uyarı", () => {
    for (const raw of ["#ev", "#yok"]) {
        const r = p("Rapor yaz " + raw)
        assert.equal(r.project, null)
        assert.equal(r.title, "Rapor yaz " + raw)
        assert.deepEqual(r.warnings, ["project_not_found"])
        const t = r.tokens.find((t) => t.type === "project")
        assert.equal(t.value, null)
    }
})

test("her türden yalnızca ilk token tüketilir", () => {
    const r = p("x yarın cuma !1 !2")
    assert.equal(r.scheduled_date, "2026-09-24")
    assert.equal(r.priority, 1)
    assert.equal(r.title, "x cuma !2")
})

test("token'lar satırın her yerinde olabilir; boşluklar toparlanır", () => {
    const r = p("  !2   yarın   Raporu    gönder  ")
    assert.equal(r.title, "Raporu gönder")
    assert.equal(r.priority, 2)
})

test("token konumları özgün metne göre (UTF-16 ofset)", () => {
    const text = "Öde yarın !1"
    const r = p(text)
    assert.deepEqual(
        r.tokens.map((t) => [t.type, text.slice(t.start, t.end)]),
        [["date", "yarın"], ["priority", "!1"]],
    )
})

test("tüm satır tırnak içindeyse parse kapalı", () => {
    for (const text of ['"Ara: yarın !1 #finans"', "“Ara: yarın !1 #finans”"]) {
        const r = p(text)
        assert.equal(r.literal, true)
        assert.equal(r.title, "Ara: yarın !1 #finans")
        assert.equal(r.scheduled_date, null)
        assert.equal(r.priority, null)
        assert.deepEqual(r.tokens, [])
    }
})

test("yalnızca token'lardan oluşan ya da boş satır geçersiz", () => {
    assert.equal(p("yarın !1").valid, false)
    assert.equal(p("   ").valid, false)
    assert.equal(p('""').valid, false)
})

test("fold: Türkçe karakterleri katlar", () => {
    assert.equal(fold("İŞ ÇĞÖÜ ıI"), "is cgou ii")
})

test("matchProject doğrudan", () => {
    assert.equal(matchProject("FINANS", PROJECTS).id, "p1")
    assert.equal(matchProject("e", PROJECTS), null)
    assert.equal(matchProject("", PROJECTS), null)
})

test("son: → due_date; scheduled_date'ten bağımsız", () => {
    const r = p("Raporu yaz salı son:cuma")
    assert.equal(r.title, "Raporu yaz")
    assert.equal(r.scheduled_date, "2026-09-29")
    assert.equal(r.due_date, "2026-09-25")
    assert.deepEqual(r.tokens.map((t) => t.type), ["date", "due"])
})

test("son: tüm tarih biçimlerini kabul eder; büyük harf ve sıra serbest", () => {
    assert.equal(p("x son:yarın").due_date, "2026-09-24")
    assert.equal(p("x son:bugun").due_date, "2026-09-23")
    assert.equal(p("x SON:25.09").due_date, "2026-09-25")
    assert.equal(p("x son:1.10.2027").due_date, "2027-10-01")
    const r = p("son:cuma x yarın")
    assert.equal(r.due_date, "2026-09-25")
    assert.equal(r.scheduled_date, "2026-09-24")
    assert.equal(r.title, "x")
})

test("son: tek başına başlama tarihi vermez", () => {
    const r = p("x son:cuma")
    assert.equal(r.scheduled_date, null)
    assert.equal(r.due_date, "2026-09-25")
})

test("geçersiz son: başlıkta kalır", () => {
    for (const raw of ["son:", "son:31.02", "son:birgün"]) {
        const r = p("x " + raw)
        assert.equal(r.due_date, null)
        assert.equal(r.title, "x " + raw)
    }
})

test("bitiş başlangıçtan önceyse uyarı", () => {
    const r = p("x cuma son:yarın")
    assert.deepEqual(r.warnings, ["due_before_scheduled"])
    assert.deepEqual(p("x yarın son:yarın").warnings, [])
})

test("// sonrası açıklamadır ve parse edilmez", () => {
    const text = "Faturayı öde yarın !1 // IBAN gelen kutusunda, yarın !2 #finans"
    const r = p(text)
    assert.equal(r.title, "Faturayı öde")
    assert.equal(r.description, "IBAN gelen kutusunda, yarın !2 #finans")
    assert.equal(r.priority, 1)
    assert.equal(r.project, null)
    const d = r.tokens.find((t) => t.type === "description")
    assert.equal(text.slice(d.start, d.end), "// IBAN gelen kutusunda, yarın !2 #finans")
    assert.deepEqual(r.tokens.map((t) => t.type), ["date", "priority", "description"])
})

test("// yalnızca tek başına kelimeyken ayraçtır", () => {
    const r = p("Oku https://example.com/a//b yarın")
    assert.equal(r.description, null)
    assert.equal(r.title, "Oku https://example.com/a//b")
    assert.equal(p("x //").description, null)
    assert.equal(p("x //").title, "x")
    assert.equal(p("x // a // b").description, "a // b")
})

test("açıklama var ama başlık yoksa geçersiz; tırnaklı satırda // düz metin", () => {
    assert.equal(p("// yalnızca açıklama").valid, false)
    const r = p('"a // b"')
    assert.equal(r.title, "a // b")
    assert.equal(r.description, null)
})

test("token'sız satırda yeni alanlar null", () => {
    const r = p("Süt al")
    assert.equal(r.due_date, null)
    assert.equal(r.description, null)
})
