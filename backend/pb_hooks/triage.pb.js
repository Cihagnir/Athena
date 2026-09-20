// POST /api/triage/{id}  { action: tomorrow | date | to_project | delete, date?, project? }
routerAdd("POST", "/api/triage/{id}", (e) => {
    const dates = require(`${__hooks}/lib/dates.js`)
    const store = require(`${__hooks}/lib/store.js`)

    const body = e.requestInfo().body
    const action = String(body.action || "")
    const date = String(body.date || "")
    const task = store.findById("tasks", e.request.pathValue("id"))

    if (action === "delete") {
        $app.delete(task)
        return e.json(200, { action: action, task: null })
    }

    if (action === "tomorrow") {
        task.set("scheduled_date", dates.addDays(dates.today(), 1))
    } else if (action === "date") {
        if (!dates.isValid(date)) throw new BadRequestError("date: YYYY-MM-DD")
        task.set("scheduled_date", date)
    } else if (action === "to_project") {
        const project = store.findById("projects", String(body.project || ""))
        if (date && !dates.isValid(date)) throw new BadRequestError("date: YYYY-MM-DD")
        task.set("project", project.id)
        task.set("area", project.getString("area"))
        // Projeye taşınan task günlük akıştan çıkar; tarih verilirse o güne planlanır.
        task.set("scheduled_date", date)
    } else {
        throw new BadRequestError("action: tomorrow | date | to_project | delete")
    }

    $app.save(task)
    return e.json(200, { action: action, task: task })
}, $apis.requireAuth("users"))
