// Aktif task + zamanlayıcı. Durum tek kayıtta (focus_state) tutulur; istemciler
// focus_state koleksiyonunu realtime dinleyerek eşzamanlı kalır.

// GET /api/focus → { state, task }
routerAdd("GET", "/api/focus", (e) => {
    const store = require(`${__hooks}/lib/store.js`)
    return e.json(200, store.focusPayload())
}, $apis.requireAuth("users"))

// POST /api/focus/clear
routerAdd("POST", "/api/focus/clear", (e) => {
    const store = require(`${__hooks}/lib/store.js`)

    const state = store.focusState()
    state.set("current_task", "")
    store.clearTimer(state)
    $app.save(state)
    return e.json(200, store.focusPayload())
}, $apis.requireAuth("users"))

// POST /api/focus/timer  { action: "start", duration: <saniye> } | { action: "stop" }
routerAdd("POST", "/api/focus/timer", (e) => {
    const store = require(`${__hooks}/lib/store.js`)

    const body = e.requestInfo().body
    const state = store.focusState()
    if (body.action === "start") {
        const duration = Number(body.duration)
        if (!(duration >= 1 && duration <= 86400) || Math.floor(duration) !== duration) {
            throw new BadRequestError("duration: 1–86400 arası tam sayı (saniye)")
        }
        if (!state.getString("current_task")) throw new BadRequestError("Aktif task yok.")
        state.set("timer_started_at", new Date().toISOString())
        state.set("timer_duration", duration)
    } else if (body.action === "stop") {
        store.clearTimer(state)
    } else {
        throw new BadRequestError("action: start | stop")
    }
    $app.save(state)
    return e.json(200, store.focusPayload())
}, $apis.requireAuth("users"))

// POST /api/focus/{id} → task'ı aktif yap (çalışan zamanlayıcı sıfırlanır)
routerAdd("POST", "/api/focus/{id}", (e) => {
    const store = require(`${__hooks}/lib/store.js`)

    const task = store.findById("tasks", e.request.pathValue("id"))
    if (task.getString("status") === "done") throw new BadRequestError("Tamamlanmış task aktif yapılamaz.")
    const state = store.focusState()
    if (state.getString("current_task") !== task.id) {
        state.set("current_task", task.id)
        store.clearTimer(state)
        $app.save(state)
    }
    return e.json(200, store.focusPayload())
}, $apis.requireAuth("users"))
