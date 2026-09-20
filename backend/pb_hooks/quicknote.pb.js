// POST /api/quicknote/preview  { text } → ayrıştırma sonucu (kayıt oluşturmaz)
routerAdd("POST", "/api/quicknote/preview", (e) => {
    const notes = require(`${__hooks}/lib/notes.js`)
    const store = require(`${__hooks}/lib/store.js`)

    const text = String(e.requestInfo().body.text || "")
    if (text.length > 100000) throw new BadRequestError("Not en fazla 100000 karakter olabilir.")
    return e.json(200, notes.parseNote(text, { projects: store.projectIndex() }))
}, $apis.requireAuth("users"))

// POST /api/quicknote  { text } → { note, parsed }
routerAdd("POST", "/api/quicknote", (e) => {
    const notes = require(`${__hooks}/lib/notes.js`)
    const store = require(`${__hooks}/lib/store.js`)

    const text = String(e.requestInfo().body.text || "")
    if (text.length > 100000) throw new BadRequestError("Not en fazla 100000 karakter olabilir.")
    const parsed = notes.parseNote(text, { projects: store.projectIndex() })
    if (!parsed.valid) throw new BadRequestError("Not boş.")

    const note = new Record($app.findCollectionByNameOrId("notes"))
    note.set("title", parsed.title)
    note.set("body", parsed.body)
    note.set("project", parsed.project ? parsed.project.id : "")
    note.set("pinned", false)
    $app.save(note)

    return e.json(200, { note: note, parsed: parsed })
}, $apis.requireAuth("users"))
