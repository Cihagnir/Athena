// Hızlı ekleme parser'ı. Saf fonksiyon: DB'ye ve saate dokunmaz, hem PocketBase
// JSVM'inde hem Node'da (tests/unit) çalışır.
//
//   parse("Faturayı öde yarın !1 #finans @kişisel", { today, projects })
//
// Her token türünden yalnızca ilki tüketilir; tanınmayan her şey başlıkta kalır.

const dates = require("./dates.js")

const DATE_WORDS = { bugun: 0, yarin: 1 }

const WEEKDAYS = {
    paz: 0, pazar: 0,
    pzt: 1, pazartesi: 1,
    sal: 2, sali: 2,
    car: 3, carsamba: 3,
    per: 4, persembe: 4,
    cum: 5, cuma: 5,
    cmt: 6, cumartesi: 6,
}

const AREAS = { is: "work", kisisel: "personal" }

const QUOTES = [['"', '"'], ["“", "”"]]

// Türkçe'ye duyarlı küçük harf + ASCII'ye katlama: "İŞ" → "is", "Salı" → "sali"
function fold(s) {
    return s
        .replace(/İ/g, "i")
        .replace(/I/g, "i")
        .toLowerCase()
        .replace(/ı/g, "i")
        .replace(/ş/g, "s")
        .replace(/ğ/g, "g")
        .replace(/ü/g, "u")
        .replace(/ö/g, "o")
        .replace(/ç/g, "c")
}

function projectKey(name) {
    return fold(name.trim()).replace(/\s+/g, "-")
}

// Tam ad eşleşmesi, yoksa tekil önek eşleşmesi.
function matchProject(raw, projects) {
    const key = projectKey(raw)
    if (!key) return null
    const prefixed = []
    for (let i = 0; i < projects.length; i++) {
        const k = projectKey(projects[i].name)
        if (k === key) return projects[i]
        if (k.indexOf(key) === 0) prefixed.push(projects[i])
    }
    return prefixed.length === 1 ? prefixed[0] : null
}

function parseDate(word, today) {
    const key = fold(word)
    if (DATE_WORDS.hasOwnProperty(key)) return dates.addDays(today, DATE_WORDS[key])
    if (WEEKDAYS.hasOwnProperty(key)) {
        const ahead = (WEEKDAYS[key] - dates.weekday(today) + 7) % 7
        return dates.addDays(today, ahead === 0 ? 7 : ahead)
    }
    const m = /^(\d{1,2})[./](\d{1,2})(?:[./](\d{4}))?$/.exec(word)
    if (!m) return null
    if (m[3]) {
        const full = dates.format(+m[3], +m[2], +m[1])
        return dates.isValid(full) ? full : null
    }
    const year = +today.slice(0, 4)
    const thisYear = dates.format(year, +m[2], +m[1])
    if (dates.isValid(thisYear) && thisYear >= today) return thisYear
    const nextYear = dates.format(year + 1, +m[2], +m[1])
    if (dates.isValid(thisYear) && dates.isValid(nextYear)) return nextYear
    return null
}

function unquote(text) {
    for (let i = 0; i < QUOTES.length; i++) {
        const open = QUOTES[i][0], close = QUOTES[i][1]
        if (text.length >= 2 && text[0] === open && text[text.length - 1] === close) {
            return text.slice(1, -1).trim()
        }
    }
    return null
}

function parse(text, options) {
    const today = options.today
    const projects = options.projects || []
    const result = {
        literal: false,
        valid: false,
        title: "",
        scheduled_date: null,
        priority: null,
        project: null,
        area: null,
        tokens: [],
        warnings: [],
    }

    const literal = unquote(text.trim())
    if (literal !== null) {
        result.literal = true
        result.title = literal
        result.valid = literal.length > 0
        return result
    }

    const titleWords = []
    const seen = {}
    const re = /\S+/g
    let m
    while ((m = re.exec(text)) !== null) {
        const word = m[0]
        const token = { type: null, raw: word, start: m.index, end: m.index + word.length, value: null }

        if (!seen.priority && /^![1-4]$/.test(word)) {
            token.type = "priority"
            token.value = +word[1]
            result.priority = token.value
        } else if (!seen.project && word[0] === "#" && word.length > 1) {
            token.type = "project"
            token.value = matchProject(word.slice(1), projects)
            result.project = token.value
            if (!token.value) {
                result.warnings.push("project_not_found")
                titleWords.push(word)
            }
        } else if (!seen.area && word[0] === "@" && AREAS.hasOwnProperty(fold(word.slice(1)))) {
            token.type = "area"
            token.value = AREAS[fold(word.slice(1))]
            result.area = token.value
        } else if (!seen.date && parseDate(word, today)) {
            token.type = "date"
            token.value = parseDate(word, today)
            result.scheduled_date = token.value
        }

        if (token.type) {
            seen[token.type] = true
            result.tokens.push(token)
        } else {
            titleWords.push(word)
        }
    }

    if (!result.area && result.project && result.project.area) result.area = result.project.area
    result.title = titleWords.join(" ")
    result.valid = result.title.length > 0
    return result
}

module.exports = { parse, matchProject, fold }
