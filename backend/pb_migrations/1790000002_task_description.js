// tasks.notes → tasks.description
// "notes" adı hem notes koleksiyonuyla hem tasks.note ilişkisiyle karışıyordu.

migrate((app) => {
    const tasks = app.findCollectionByNameOrId("tasks")
    tasks.fields.getByName("notes").name = "description"
    app.save(tasks)
}, (app) => {
    const tasks = app.findCollectionByNameOrId("tasks")
    tasks.fields.getByName("description").name = "notes"
    app.save(tasks)
})
