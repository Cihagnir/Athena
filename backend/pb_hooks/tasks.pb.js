// tasks kayıt hook'ları — REST, quickadd ya da triyaj; task hangi yoldan değişirse
// değişsin aynı kurallar işler.

// completed_at, status ile birlikte yürür.
onRecordCreate((e) => {
    if (e.record.getString("status") === "done") e.record.set("completed_at", new Date().toISOString())
    e.next()
}, "tasks")

onRecordUpdate((e) => {
    const was = e.record.original().getString("status")
    const now = e.record.getString("status")
    if (now === "done" && was !== "done") e.record.set("completed_at", new Date().toISOString())
    if (now !== "done" && was === "done") e.record.set("completed_at", "")
    e.next()
}, "tasks")

// Aktif task tamamlanınca ya da silinince mini panel boşalır.
onRecordAfterUpdateSuccess((e) => {
    if (e.record.getString("status") === "done") {
        require(`${__hooks}/lib/store.js`).releaseFocus(e.record.id)
    }
    e.next()
}, "tasks")

onRecordDelete((e) => {
    require(`${__hooks}/lib/store.js`).releaseFocus(e.record.id)
    e.next()
}, "tasks")
