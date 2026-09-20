// Hook'ların ortak DB yardımcıları. PocketBase JSVM global'lerini ($app, Record…)
// kullanır; her handler kendi içinde require eder (handler'lar izole çalışır).

const FOCUS_ID = "focusstate00001"

// Go slice'ı → düz JS dizisi
function toArray(list) {
    const out = []
    for (let i = 0; i < list.length; i++) out.push(list[i])
    return out
}

function find(collection, filter, sort, params) {
    return toArray($app.findRecordsByFilter(collection, filter, sort || "", 0, 0, params || {}))
}

function findById(collection, id) {
    try {
        return $app.findRecordById(collection, id)
    } catch (_) {
        throw new NotFoundError("Kayıt bulunamadı: " + collection + "/" + id)
    }
}

// Parser'ın beklediği yalın proje listesi (bitmiş projeler hızlı eklemede eşleşmez).
function projectIndex() {
    return find("projects", "status != 'done'", "name").map((p) => ({
        id: p.id,
        name: p.getString("name"),
        area: p.getString("area"),
    }))
}

function focusState() {
    return $app.findRecordById("focus_state", FOCUS_ID)
}

function clearTimer(state) {
    state.set("timer_started_at", "")
    state.set("timer_duration", 0)
}

// Task tamamlanınca / silinince aktif task boşalır — otomatik yenisi atanmaz.
function releaseFocus(taskId) {
    const state = focusState()
    if (state.getString("current_task") !== taskId) return
    state.set("current_task", "")
    clearTimer(state)
    $app.save(state)
}

function focusPayload() {
    const state = focusState()
    const taskId = state.getString("current_task")
    return { state: state, task: taskId ? findById("tasks", taskId) : null }
}

module.exports = { find, findById, projectIndex, focusState, clearTimer, releaseFocus, focusPayload }
