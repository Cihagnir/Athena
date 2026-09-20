// Toplu görünümler: "bugün" otoritesi server'dadır, istemci hazır JSON'u çizer.

// GET /api/views/focus?area=work|personal
// Odak / Dashboard / Triyaj listesi: bugüne ya da öncesine planlı, bitmemiş task'lar.
routerAdd("GET", "/api/views/focus", (e) => {
    const dates = require(`${__hooks}/lib/dates.js`)
    const store = require(`${__hooks}/lib/store.js`)

    const today = dates.today()
    const area = e.request.url.query().get("area")
    if (area && area !== "work" && area !== "personal") throw new BadRequestError("area: work | personal")

    let filter = "scheduled_date != '' && scheduled_date <= {:today} && status != 'done'"
    if (area) filter += " && area = {:area}"
    const tasks = store.find("tasks", filter, "sort_order", { today: today, area: area })
    return e.json(200, { today: today, tasks: tasks })
}, $apis.requireAuth("users"))

// GET /api/views/week?start=YYYY-MM-DD   (varsayılan: bugün; 7 gün)
routerAdd("GET", "/api/views/week", (e) => {
    const dates = require(`${__hooks}/lib/dates.js`)
    const store = require(`${__hooks}/lib/store.js`)

    const today = dates.today()
    const start = e.request.url.query().get("start") || today
    if (!dates.isValid(start)) throw new BadRequestError("start: YYYY-MM-DD")
    const end = dates.addDays(start, 6)

    const days = []
    const byDate = {}
    for (let i = 0; i < 7; i++) {
        const day = { date: dates.addDays(start, i), weekday: 0, open_count: 0, done_count: 0, tasks: [] }
        day.weekday = dates.weekday(day.date)
        days.push(day)
        byDate[day.date] = day
    }

    const tasks = store.find("tasks", "scheduled_date >= {:start} && scheduled_date <= {:end}", "sort_order", { start: start, end: end })
    tasks.forEach((t) => {
        const day = byDate[t.getString("scheduled_date")]
        day.tasks.push(t)
        if (t.getString("status") === "done") day.done_count++
        else day.open_count++
    })

    const overdue = store.find("tasks", "scheduled_date != '' && scheduled_date < {:today} && status != 'done'", "scheduled_date,sort_order", { today: today })
    return e.json(200, { today: today, start: start, end: end, days: days, overdue: overdue })
}, $apis.requireAuth("users"))

// GET /api/views/projects → proje panoraması
routerAdd("GET", "/api/views/projects", (e) => {
    const store = require(`${__hooks}/lib/store.js`)

    const rows = []
    const byId = {}
    store.find("projects", "id != ''", "status,name").forEach((p) => {
        const row = { project: p, open_count: 0, done_count: 0, progress: 0, note_count: 0 }
        rows.push(row)
        byId[p.id] = row
    })
    store.find("tasks", "project != ''").forEach((t) => {
        const row = byId[t.getString("project")]
        if (t.getString("status") === "done") row.done_count++
        else row.open_count++
    })
    store.find("notes", "project != ''").forEach((n) => {
        byId[n.getString("project")].note_count++
    })
    rows.forEach((row) => {
        const total = row.open_count + row.done_count
        row.progress = total ? Math.round((row.done_count / total) * 100) / 100 : 0
    })
    return e.json(200, { projects: rows })
}, $apis.requireAuth("users"))
