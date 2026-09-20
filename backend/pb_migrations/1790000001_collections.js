// projects · notes · tasks · focus_state
// Tek kullanıcılı sistem: kayıtlarda sahip alanı yok, tüm kurallar "giriş yapılmış olsun".

migrate((app) => {
    const AUTHED = '@request.auth.id != ""'
    const rules = { listRule: AUTHED, viewRule: AUTHED, createRule: AUTHED, updateRule: AUTHED, deleteRule: AUTHED }
    const timestamps = [
        { name: "created", type: "autodate", onCreate: true, onUpdate: false },
        { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
    ]
    const ymd = (name) => ({ name: name, type: "text", pattern: "^\\d{4}-\\d{2}-\\d{2}$" })

    const projects = new Collection({
        type: "base",
        name: "projects",
        ...rules,
        fields: [
            { name: "name", type: "text", required: true, max: 120 },
            { name: "area", type: "select", required: true, maxSelect: 1, values: ["work", "personal"] },
            { name: "status", type: "select", required: true, maxSelect: 1, values: ["active", "on_hold", "done"] },
            { name: "description", type: "text", max: 20000 },
            ...timestamps,
        ],
        indexes: ["CREATE UNIQUE INDEX idx_projects_name ON projects (name)"],
    })
    app.save(projects)

    const notes = new Collection({
        type: "base",
        name: "notes",
        ...rules,
        fields: [
            { name: "title", type: "text", required: true, max: 300 },
            { name: "body", type: "text", max: 1000000 },
            { name: "project", type: "relation", collectionId: projects.id, maxSelect: 1, cascadeDelete: false },
            { name: "tags", type: "json", maxSize: 20000 },
            { name: "pinned", type: "bool" },
            ...timestamps,
        ],
        indexes: ["CREATE INDEX idx_notes_project ON notes (project)"],
    })
    app.save(notes)

    const tasks = new Collection({
        type: "base",
        name: "tasks",
        ...rules,
        fields: [
            { name: "title", type: "text", required: true, max: 500 },
            { name: "notes", type: "text", max: 100000 },
            { name: "area", type: "select", maxSelect: 1, values: ["work", "personal"] },
            { name: "project", type: "relation", collectionId: projects.id, maxSelect: 1, cascadeDelete: false },
            { name: "status", type: "select", required: true, maxSelect: 1, values: ["todo", "doing", "blocked", "done"] },
            { name: "priority", type: "number", required: true, onlyInt: true, min: 1, max: 4 },
            // Gün kavramı saat dilimsiz "YYYY-MM-DD" metni olarak tutulur (boş = planlanmamış).
            ymd("scheduled_date"),
            ymd("due_date"),
            { name: "sort_order", type: "number" },
            { name: "completed_at", type: "date" },
            { name: "note", type: "relation", collectionId: notes.id, maxSelect: 1, cascadeDelete: false },
            ...timestamps,
        ],
        indexes: [
            "CREATE INDEX idx_tasks_scheduled ON tasks (scheduled_date, status)",
            "CREATE INDEX idx_tasks_project ON tasks (project)",
        ],
    })
    app.save(tasks)

    // Tek kayıt; yalnızca /api/focus/* endpoint'leri yazar, istemciler okur + realtime dinler.
    const focus = new Collection({
        type: "base",
        name: "focus_state",
        listRule: AUTHED,
        viewRule: AUTHED,
        createRule: null,
        updateRule: null,
        deleteRule: null,
        fields: [
            { name: "current_task", type: "relation", collectionId: tasks.id, maxSelect: 1, cascadeDelete: false },
            { name: "timer_started_at", type: "date" },
            { name: "timer_duration", type: "number", onlyInt: true, min: 0 },
            ...timestamps,
        ],
    })
    app.save(focus)

    const state = new Record(focus)
    state.set("id", "focusstate00001")
    app.save(state)

    // Kayıt kapalı: kullanıcı yalnızca açılışta .env'den oluşturulur.
    const users = app.findCollectionByNameOrId("users")
    users.createRule = null
    app.save(users)
}, (app) => {
    for (const name of ["focus_state", "tasks", "notes", "projects"]) {
        app.delete(app.findCollectionByNameOrId(name))
    }
    const users = app.findCollectionByNameOrId("users")
    users.createRule = ""
    app.save(users)
})
