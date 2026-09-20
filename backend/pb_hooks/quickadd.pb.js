// POST /api/quickadd/preview  { text } → parse sonucu (yazarken canlı önizleme)
routerAdd("POST", "/api/quickadd/preview", (e) => {
    const parser = require(`${__hooks}/lib/parser.js`)
    const dates = require(`${__hooks}/lib/dates.js`)
    const store = require(`${__hooks}/lib/store.js`)

    const text = String(e.requestInfo().body.text || "")
    if (text.length > 500) throw new BadRequestError("Metin en fazla 500 karakter olabilir.")
    return e.json(200, parser.parse(text, { today: dates.today(), projects: store.projectIndex() }))
}, $apis.requireAuth("users"))

// POST /api/quickadd  { text } → { task, parsed }
routerAdd("POST", "/api/quickadd", (e) => {
    const parser = require(`${__hooks}/lib/parser.js`)
    const dates = require(`${__hooks}/lib/dates.js`)
    const store = require(`${__hooks}/lib/store.js`)

    const text = String(e.requestInfo().body.text || "")
    if (text.length > 500) throw new BadRequestError("Metin en fazla 500 karakter olabilir.")
    const today = dates.today()
    const parsed = parser.parse(text, { today: today, projects: store.projectIndex() })
    if (!parsed.valid) throw new BadRequestError("Task başlığı boş.")

    const task = new Record($app.findCollectionByNameOrId("tasks"))
    task.set("title", parsed.title)
    task.set("status", "todo")
    task.set("priority", parsed.priority || 4)
    task.set("area", parsed.area || "")
    task.set("project", parsed.project ? parsed.project.id : "")
    // Tarihsiz + projesiz = geçici günlük task → bugüne. Projeli ve tarihsiz → proje birikimi.
    task.set("scheduled_date", parsed.scheduled_date || (parsed.project ? "" : today))
    task.set("sort_order", Date.now())
    $app.save(task)

    return e.json(200, { task: task, parsed: parsed })
}, $apis.requireAuth("users"))
