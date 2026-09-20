// Çalışan PocketBase'e karşı uçtan uca testler:  docker compose up -d && pnpm test:api
// Oluşturduğu her kaydı siler; proje adları "zz-test-" önekiyle ayrışır.

const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")

const env = {}
for (const line of fs.readFileSync(path.join(__dirname, "../../.env"), "utf8").split("\n")) {
    const m = /^([A-Z_]+)=(.*)$/.exec(line.trim())
    if (m) env[m[1]] = m[2]
}
const BASE = process.env.PB_URL || `http://127.0.0.1:${env.PB_PORT || 8090}`

let token = ""
const created = { tasks: [], projects: [] }

async function api(method, url, body, auth = true) {
    const res = await fetch(BASE + url, {
        method,
        headers: { "Content-Type": "application/json", ...(auth ? { Authorization: token } : {}) },
        body: body ? JSON.stringify(body) : undefined,
    })
    const text = await res.text()
    return { status: res.status, body: text ? JSON.parse(text) : null }
}

function localToday() {
    return new Intl.DateTimeFormat("en-CA", { timeZone: env.TZ || "Europe/Istanbul" }).format(new Date())
}

function addDays(ymd, n) {
    return new Date(Date.parse(ymd + "T00:00:00Z") + n * 86400000).toISOString().slice(0, 10)
}

async function quickadd(text) {
    const r = await api("POST", "/api/quickadd", { text })
    assert.equal(r.status, 200, JSON.stringify(r.body))
    created.tasks.push(r.body.task.id)
    return r.body
}

test.before(async () => {
    const r = await api("POST", "/api/collections/users/auth-with-password",
        { identity: env.TT_USER_EMAIL, password: env.TT_USER_PASSWORD }, false)
    assert.equal(r.status, 200, "giriş başarısız — .env ile çalışan sunucu uyuşuyor mu?")
    token = r.body.token

    const p = await api("POST", "/api/collections/projects/records",
        { name: "zz-test-Ev İşleri", area: "work", status: "active" })
    assert.equal(p.status, 200, JSON.stringify(p.body))
    created.projects.push(p.body.id)
})

test.after(async () => {
    await api("POST", "/api/focus/clear")
    for (const id of created.tasks) await api("DELETE", `/api/collections/tasks/records/${id}`)
    for (const id of created.projects) await api("DELETE", `/api/collections/projects/records/${id}`)
})

test("girişsiz her endpoint 401 döner", async () => {
    const calls = [
        ["POST", "/api/quickadd"], ["POST", "/api/quickadd/preview"],
        ["GET", "/api/views/focus"], ["GET", "/api/views/week"], ["GET", "/api/views/projects"],
        ["POST", "/api/triage/x"],
        ["GET", "/api/focus"], ["POST", "/api/focus/x"], ["POST", "/api/focus/clear"], ["POST", "/api/focus/timer"],
        ["GET", "/api/collections/tasks/records"], ["GET", "/api/collections/projects/records"],
        ["GET", "/api/collections/notes/records"], ["GET", "/api/collections/focus_state/records"],
        ["POST", "/api/collections/tasks/records"],
    ]
    for (const [method, url] of calls) {
        const r = await api(method, url, method === "POST" ? { text: "x", title: "x" } : null, false)
        assert.equal(r.status, 401, `${method} ${url} → ${r.status}`)
    }
})

test("API anahtarı: tünelden gelen istek anahtarsız 403, anahtarla geçer; yerel istek etkilenmez", { skip: !env.TT_API_KEYS }, async () => {
    const key = env.TT_API_KEYS.split(",")[0].trim()
    const viaTunnel = (headers) => fetch(BASE + "/api/health", { headers: { "CF-Connecting-IP": "203.0.113.7", ...headers } })

    assert.equal((await viaTunnel({})).status, 403)
    assert.equal((await viaTunnel({ "X-API-Key": "yanlis-anahtar" })).status, 403)
    assert.equal((await viaTunnel({ "X-API-Key": key.slice(0, -1) })).status, 403)
    assert.equal((await viaTunnel({ "X-API-Key": key })).status, 200)
    // giriş uç noktası da kapının arkasında
    const login = await fetch(BASE + "/api/collections/users/auth-with-password", {
        method: "POST", headers: { "Content-Type": "application/json", "CF-Connecting-IP": "203.0.113.7" },
        body: JSON.stringify({ identity: env.TT_USER_EMAIL, password: env.TT_USER_PASSWORD }),
    })
    assert.equal(login.status, 403)
    // tünelden geçmeyen (yerel) istek anahtarsız çalışır
    assert.equal((await fetch(BASE + "/api/health")).status, 200)
})

test("kayıt (sign-up) kapalı", async () => {
    const r = await api("POST", "/api/collections/users/records",
        { email: "x@example.com", password: "12345678ab", passwordConfirm: "12345678ab" }, false)
    assert.ok(r.status === 400 || r.status === 403, `→ ${r.status}`)
})

test("preview: Türkçe token'lar JSVM içinde de çözülüyor, kayıt oluşmuyor", async () => {
    const r = await api("POST", "/api/quickadd/preview", { text: "Faturayı öde YARIN !1 #zz-test-ev @kişisel" })
    assert.equal(r.status, 200)
    assert.equal(r.body.title, "Faturayı öde")
    assert.equal(r.body.scheduled_date, addDays(localToday(), 1))
    assert.equal(r.body.priority, 1)
    assert.equal(r.body.project.name, "zz-test-Ev İşleri")
    assert.equal(r.body.area, "personal")
    assert.deepEqual(r.body.tokens.map((t) => t.type), ["date", "priority", "project", "area"])
})

test("quickadd: projesiz + tarihsiz → bugüne planlı geçici task", async () => {
    const { task } = await quickadd("zz-test süt al")
    assert.equal(task.title, "zz-test süt al")
    assert.equal(task.scheduled_date, localToday())
    assert.equal(task.status, "todo")
    assert.equal(task.priority, 4)
    assert.equal(task.project, "")
})

test("quickadd: projeli + tarihsiz → plansız, alan projeden", async () => {
    const { task } = await quickadd("zz-test rapor #zz-test-ev !2")
    assert.equal(task.project, created.projects[0])
    assert.equal(task.scheduled_date, "")
    assert.equal(task.area, "work")
    assert.equal(task.priority, 2)
})

test("quickadd: bilinmeyen proje girdiyi kaybetmez", async () => {
    const { task, parsed } = await quickadd("zz-test ara #zz-olmayan")
    assert.equal(task.title, "zz-test ara #zz-olmayan")
    assert.deepEqual(parsed.warnings, ["project_not_found"])
})

test("quickadd: son: → due_date, // → description, gövdedeki description eklenir", async () => {
    const today = localToday()
    const a = await quickadd("zz-test teklif yarın son:" + addDays(today, 5).split("-").reverse().join(".") + " // fiyat tablosunu ekle")
    assert.equal(a.task.title, "zz-test teklif")
    assert.equal(a.task.scheduled_date, addDays(today, 1))
    assert.equal(a.task.due_date, addDays(today, 5))
    assert.equal(a.task.description, "fiyat tablosunu ekle")

    const r = await api("POST", "/api/quickadd", { text: "zz-test çok satır // kısa not", description: "1. satır\n2. satır" })
    created.tasks.push(r.body.task.id)
    assert.equal(r.body.task.description, "kısa not\n\n1. satır\n2. satır")
    assert.equal(r.body.task.due_date, "")

    const c = await quickadd("zz-test yalnız bitiş son:yarın")
    assert.equal(c.task.due_date, addDays(today, 1))
    assert.equal(c.task.scheduled_date, today, "projesiz + başlangıçsız → bugün")
})

test("quicknote: ilk satır başlık, #proje bağlar, gövde korunur; boş not 400", async () => {
    const preview = await api("POST", "/api/quicknote/preview", { text: "zz-test not #zz-test-ev\nsatır 1\nsatır 2" })
    assert.equal(preview.body.title, "zz-test not")
    assert.equal(preview.body.project.name, "zz-test-Ev İşleri")
    assert.equal(preview.body.body, "satır 1\nsatır 2")

    const r = await api("POST", "/api/quicknote", { text: "zz-test not #zz-test-ev\nsatır 1\nsatır 2" })
    assert.equal(r.status, 200, JSON.stringify(r.body))
    assert.equal(r.body.note.title, "zz-test not")
    assert.equal(r.body.note.project, created.projects[0])
    assert.equal(r.body.note.body, "satır 1\nsatır 2")
    assert.equal(r.body.note.pinned, false)

    assert.equal((await api("POST", "/api/quicknote", { text: "  \n " })).status, 400)
    assert.equal((await api("POST", "/api/quicknote", { text: "x" }, false)).status, 401)
    assert.equal((await api("DELETE", `/api/collections/notes/records/${r.body.note.id}`)).status, 204)
})

test("quickadd: boş başlık 400", async () => {
    assert.equal((await api("POST", "/api/quickadd", { text: "yarın !1" })).status, 400)
    assert.equal((await api("POST", "/api/quickadd", {})).status, 400)
})

test("views/focus: bugünün task'ı listede, alan filtresi çalışıyor", async () => {
    const { task } = await quickadd("zz-test odak @iş")
    const all = await api("GET", "/api/views/focus")
    assert.equal(all.body.today, localToday())
    assert.ok(all.body.tasks.some((t) => t.id === task.id))
    const personal = await api("GET", "/api/views/focus?area=personal")
    assert.ok(!personal.body.tasks.some((t) => t.id === task.id))
    assert.equal((await api("GET", "/api/views/focus?area=x")).status, 400)
})

test("views/focus: bugün tamamlananlar done listesinde; geri alınınca çıkar", async () => {
    const { task } = await quickadd("zz-test biten")
    await api("PATCH", `/api/collections/tasks/records/${task.id}`, { status: "done" })
    let r = await api("GET", "/api/views/focus")
    assert.ok(!r.body.tasks.some((t) => t.id === task.id))
    assert.ok(r.body.done.some((t) => t.id === task.id))
    await api("PATCH", `/api/collections/tasks/records/${task.id}`, { status: "todo" })
    r = await api("GET", "/api/views/focus")
    assert.ok(!r.body.done.some((t) => t.id === task.id))
})

test("views/week: 7 gün, task doğru günde sayılıyor", async () => {
    const { task } = await quickadd("zz-test hafta yarın")
    const r = await api("GET", "/api/views/week")
    assert.equal(r.body.days.length, 7)
    assert.equal(r.body.days[0].date, localToday())
    const tomorrow = r.body.days[1]
    assert.ok(tomorrow.tasks.some((t) => t.id === task.id))
    assert.ok(tomorrow.open_count >= 1)
    assert.equal((await api("GET", "/api/views/week?start=2026-13-40")).status, 400)
})

test("views/projects: açık/biten sayıları ve ilerleme", async () => {
    const a = await quickadd("zz-test p-a #zz-test-ev")
    await quickadd("zz-test p-b #zz-test-ev")
    await api("PATCH", `/api/collections/tasks/records/${a.task.id}`, { status: "done" })
    const r = await api("GET", "/api/views/projects")
    const row = r.body.projects.find((p) => p.project.id === created.projects[0])
    assert.ok(row.done_count >= 1 && row.open_count >= 1)
    assert.equal(row.progress, Math.round((row.done_count / (row.done_count + row.open_count)) * 100) / 100)
})

test("triyaj: dünden kalan task odakta çıkıyor; tomorrow / date / to_project / delete", async () => {
    const today = localToday()
    const { task } = await quickadd("zz-test triyaj")
    await api("PATCH", `/api/collections/tasks/records/${task.id}`, { scheduled_date: addDays(today, -1) })
    let focus = await api("GET", "/api/views/focus")
    assert.ok(focus.body.tasks.some((t) => t.id === task.id), "gecikmiş task odakta olmalı")

    let r = await api("POST", `/api/triage/${task.id}`, { action: "tomorrow" })
    assert.equal(r.body.task.scheduled_date, addDays(today, 1))
    focus = await api("GET", "/api/views/focus")
    assert.ok(!focus.body.tasks.some((t) => t.id === task.id))

    r = await api("POST", `/api/triage/${task.id}`, { action: "date", date: "2027-01-15" })
    assert.equal(r.body.task.scheduled_date, "2027-01-15")
    assert.equal((await api("POST", `/api/triage/${task.id}`, { action: "date", date: "15.01.2027" })).status, 400)

    r = await api("POST", `/api/triage/${task.id}`, { action: "to_project", project: created.projects[0] })
    assert.equal(r.body.task.project, created.projects[0])
    assert.equal(r.body.task.scheduled_date, "")
    assert.equal(r.body.task.area, "work")

    assert.equal((await api("POST", `/api/triage/${task.id}`, { action: "nope" })).status, 400)
    r = await api("POST", `/api/triage/${task.id}`, { action: "delete" })
    assert.equal(r.body.task, null)
    assert.equal((await api("GET", `/api/collections/tasks/records/${task.id}`)).status, 404)
    assert.equal((await api("POST", `/api/triage/${task.id}`, { action: "tomorrow" })).status, 404)
})

test("focus: aktif task, zamanlayıcı, tamamlanınca boşalma, completed_at", async () => {
    const { task } = await quickadd("zz-test aktif")
    assert.equal((await api("POST", "/api/focus/clear")).body.task, null)
    assert.equal((await api("POST", "/api/focus/timer", { action: "start", duration: 1500 })).status, 400, "aktif task yokken zamanlayıcı başlamaz")

    let r = await api("POST", `/api/focus/${task.id}`)
    assert.equal(r.body.task.id, task.id)
    assert.equal(r.body.state.current_task, task.id)

    assert.equal((await api("POST", "/api/focus/timer", { action: "start", duration: 0 })).status, 400)
    r = await api("POST", "/api/focus/timer", { action: "start", duration: 1500 })
    assert.equal(r.body.state.timer_duration, 1500)
    assert.ok(Math.abs(Date.parse(r.body.state.timer_started_at.replace(" ", "T")) - Date.now()) < 10000)

    r = await api("POST", "/api/focus/timer", { action: "stop" })
    assert.equal(r.body.state.timer_duration, 0)
    assert.equal(r.body.state.timer_started_at, "")

    await api("POST", "/api/focus/timer", { action: "start", duration: 60 })
    const done = await api("PATCH", `/api/collections/tasks/records/${task.id}`, { status: "done" })
    assert.notEqual(done.body.completed_at, "")
    r = await api("GET", "/api/focus")
    assert.equal(r.body.task, null, "tamamlanan aktif task paneli boşaltır")
    assert.equal(r.body.state.timer_duration, 0)

    assert.equal((await api("POST", `/api/focus/${task.id}`)).status, 400, "biten task aktif yapılamaz")
    const undone = await api("PATCH", `/api/collections/tasks/records/${task.id}`, { status: "todo" })
    assert.equal(undone.body.completed_at, "")
})

test("focus: aktif task silinince boşalır", async () => {
    const { task } = await quickadd("zz-test silinecek")
    await api("POST", `/api/focus/${task.id}`)
    await api("POST", `/api/triage/${task.id}`, { action: "delete" })
    const r = await api("GET", "/api/focus")
    assert.equal(r.body.task, null)
    assert.equal(r.body.state.current_task, "")
})

test("focus_state REST üzerinden yazılamaz", async () => {
    const r = await api("PATCH", "/api/collections/focus_state/records/focusstate00001", { timer_duration: 5 })
    assert.ok(r.status === 403 || r.status === 404, `→ ${r.status}`)
})

test("realtime: quickadd ile eklenen task SSE aboneliğine düşüyor", async () => {
    const ctrl = new AbortController()
    const res = await fetch(BASE + "/api/realtime", { signal: ctrl.signal })
    const reader = res.body.getReader()
    const decoder = new TextDecoder()
    let buffer = ""
    async function nextEvent(name) {
        const deadline = Date.now() + 5000
        while (Date.now() < deadline) {
            const end = buffer.indexOf("\n\n")
            if (end >= 0) {
                const block = buffer.slice(0, end)
                buffer = buffer.slice(end + 2)
                const event = /^event:(.*)$/m.exec(block)
                const data = /^data:(.*)$/m.exec(block)
                if (event && event[1].trim() === name) return JSON.parse(data[1])
                continue
            }
            const { value, done } = await reader.read()
            if (done) break
            buffer += decoder.decode(value, { stream: true })
        }
        throw new Error("SSE olayı gelmedi: " + name)
    }

    try {
        const { clientId } = await nextEvent("PB_CONNECT")
        const sub = await api("POST", "/api/realtime", { clientId, subscriptions: ["tasks"] })
        assert.equal(sub.status, 204)
        const { task } = await quickadd("zz-test canlı")
        const event = await nextEvent("tasks")
        assert.equal(event.action, "create")
        assert.equal(event.record.id, task.id)
    } finally {
        ctrl.abort()
    }
})
