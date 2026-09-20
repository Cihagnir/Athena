const test = require("node:test")
const assert = require("node:assert/strict")
const { parseNote } = require("../../pb_hooks/lib/notes.js")

const PROJECTS = [
    { id: "p1", name: "Sunucu altyapısı", area: "work" },
    { id: "p2", name: "Task Tracker", area: "personal" },
]
const p = (text) => parseNote(text, { projects: PROJECTS })

test("ilk satır başlık, kalanı gövde", () => {
    const r = p("Sunucu yedeği fikri\npb_data'yı restic ile at.\n\nAyda bir dene.")
    assert.equal(r.title, "Sunucu yedeği fikri")
    assert.equal(r.body, "pb_data'yı restic ile at.\n\nAyda bir dene.")
    assert.equal(r.project, null)
    assert.equal(r.valid, true)
    assert.deepEqual(r.tokens, [])
})

test("tek satırlık not: gövde boş", () => {
    const r = p("  Balkon ölçüsü 3,40 × 1,25  ")
    assert.equal(r.title, "Balkon ölçüsü 3,40 × 1,25")
    assert.equal(r.body, "")
})

test("baştaki boş satırlar atlanır", () => {
    const r = p("\n\n  Başlık\ngövde")
    assert.equal(r.title, "Başlık")
    assert.equal(r.body, "gövde")
})

test("ilk satırdaki #proje notu bağlar ve başlıktan çıkar (önek yeterli)", () => {
    const text = "Yedek fikri #sunucu\nrestic + B2"
    const r = p(text)
    assert.equal(r.title, "Yedek fikri")
    assert.deepEqual(r.project, PROJECTS[0])
    assert.equal(r.body, "restic + B2")
    assert.deepEqual(r.tokens.map((t) => [t.type, text.slice(t.start, t.end)]), [["project", "#sunucu"]])
})

test("token konumu baştaki boşluk ve boş satırlarla birlikte özgün metne göredir", () => {
    const text = "\n  Not #task-tr"
    const r = p(text)
    assert.equal(text.slice(r.tokens[0].start, r.tokens[0].end), "#task-tr")
    assert.equal(r.project.id, "p2")
})

test("gövdedeki # bağ sayılmaz", () => {
    const r = p("Başlık\n#sunucu ile ilgili")
    assert.equal(r.project, null)
    assert.equal(r.body, "#sunucu ile ilgili")
})

test("bilinmeyen proje başlıkta kalır + uyarı", () => {
    const r = p("Fikir #yok")
    assert.equal(r.title, "Fikir #yok")
    assert.equal(r.project, null)
    assert.deepEqual(r.warnings, ["project_not_found"])
    assert.equal(r.tokens[0].value, null)
})

test("boş ya da yalnızca #proje olan not geçersiz", () => {
    assert.equal(p("").valid, false)
    assert.equal(p("  \n ").valid, false)
    assert.equal(p("#sunucu").valid, false)
})

test("çok uzun ilk satır: başlık kısaltılır, tam metin gövdede kalır", () => {
    const long = "a".repeat(150)
    const r = p(long + "\nikinci")
    assert.equal(r.title.length, 120)
    assert.ok(r.title.endsWith("…"))
    assert.equal(r.body, long + "\nikinci")
})
