// Hızlı not ayrıştırıcısı. Saf fonksiyon (parser.js gibi): hem JSVM'de hem Node'da çalışır.
//
//   parseNote("Yedek fikri #sunucu\nrestic + B2", { projects })
//   → başlık "Yedek fikri", proje Sunucu altyapısı, gövde "restic + B2"
//
// İlk dolu satır başlıktır; o satırdaki ilk #proje notu projeye bağlar. Gövdeye dokunulmaz.

const { matchProject } = require("./parser.js")

const TITLE_MAX = 120

function parseNote(text, options) {
    const projects = options.projects || []
    const result = { valid: false, title: "", body: "", project: null, tokens: [], warnings: [] }

    // İlk dolu satırın özgün metindeki yeri
    const lineRe = /[^\n]*/g
    let lineStart = -1, line = ""
    let m
    while ((m = lineRe.exec(text)) !== null) {
        if (m[0].trim()) { lineStart = m.index; line = m[0]; break }
        if (m.index >= text.length) break
        lineRe.lastIndex = m.index + m[0].length + 1
    }
    if (lineStart < 0) return result

    const titleWords = []
    const wordRe = /\S+/g
    let seenProject = false
    while ((m = wordRe.exec(line)) !== null) {
        const word = m[0]
        if (!seenProject && word[0] === "#" && word.length > 1) {
            seenProject = true
            const project = matchProject(word.slice(1), projects)
            result.tokens.push({ type: "project", raw: word, start: lineStart + m.index, end: lineStart + m.index + word.length, value: project })
            if (project) { result.project = project; continue }
            result.warnings.push("project_not_found")
        }
        titleWords.push(word)
    }

    const title = titleWords.join(" ")
    const rest = text.slice(lineStart + line.length).replace(/^\n/, "").replace(/\s+$/, "")
    if (title.length > TITLE_MAX) {
        result.title = title.slice(0, TITLE_MAX - 1) + "…"
        result.body = (title + (rest ? "\n" + rest : ""))
    } else {
        result.title = title
        result.body = rest
    }
    // yalnızca çözülmüş bir #proje'den ibaret satır başlıksız sayılır
    result.valid = result.title.length > 0
    return result
}

module.exports = { parseNote }
