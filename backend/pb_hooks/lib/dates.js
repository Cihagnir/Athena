// "YYYY-MM-DD" metinleri üzerinde saf tarih aritmetiği. Saat dilimi kaymasın diye
// hesaplar UTC üzerinden yapılır; "bugün" ise sürecin yerel saatinden (TZ) okunur.

function pad(n) {
    return (n < 10 ? "0" : "") + n
}

function format(y, m, d) {
    return y + "-" + pad(m) + "-" + pad(d)
}

function toUTC(ymd) {
    const parts = ymd.split("-")
    return Date.UTC(+parts[0], +parts[1] - 1, +parts[2])
}

function isValid(ymd) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(ymd)) return false
    const d = new Date(toUTC(ymd))
    return format(d.getUTCFullYear(), d.getUTCMonth() + 1, d.getUTCDate()) === ymd
}

function addDays(ymd, days) {
    const d = new Date(toUTC(ymd) + days * 86400000)
    return format(d.getUTCFullYear(), d.getUTCMonth() + 1, d.getUTCDate())
}

// 0 = Pazar … 6 = Cumartesi
function weekday(ymd) {
    return new Date(toUTC(ymd)).getUTCDay()
}

function today() {
    const d = new Date()
    return format(d.getFullYear(), d.getMonth() + 1, d.getDate())
}

module.exports = { format, isValid, addDays, weekday, today }
