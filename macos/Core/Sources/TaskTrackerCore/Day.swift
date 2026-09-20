import Foundation

/// "YYYY-MM-DD" gün metinleri için gösterim yardımcıları. "Bugün"ün ne olduğuna
/// server karar verir (yanıtlardaki `today`); burada saat/saat dilimi okunmaz.
public enum Day {
    private static let weekdays = ["Paz", "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt"]

    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private static func parts(_ ymd: String) -> (y: Int, m: Int, d: Int)? {
        let p = ymd.split(separator: "-").compactMap { Int($0) }
        return p.count == 3 ? (p[0], p[1], p[2]) : nil
    }

    /// "2026-09-20" → "20.09"
    public static func short(_ ymd: String) -> String {
        guard let p = parts(ymd) else { return ymd }
        return String(format: "%02d.%02d", p.d, p.m)
    }

    /// "2026-09-29" + 3 → "2026-10-02" (takvim aritmetiği; saat dilimi yok)
    public static func adding(_ days: Int, to ymd: String) -> String {
        guard let p = parts(ymd),
              let date = calendar.date(from: DateComponents(year: p.y, month: p.m, day: p.d)),
              let moved = calendar.date(byAdding: .day, value: days, to: date) else { return ymd }
        let c = calendar.dateComponents([.year, .month, .day], from: moved)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// "2026-09-20" → "Paz 20.09" (gün adı önde; ajanda başlıkları için)
    public static func weekdayFirst(_ ymd: String) -> String {
        let label = label(ymd).split(separator: " ")
        return label.count == 2 ? "\(label[1]) \(label[0])" : ymd
    }

    /// "2026-09-20" → "20.09 Paz"
    public static func label(_ ymd: String) -> String {
        guard let p = parts(ymd),
              let date = calendar.date(from: DateComponents(year: p.y, month: p.m, day: p.d)) else { return ymd }
        return "\(short(ymd)) \(weekdays[calendar.component(.weekday, from: date) - 1])"
    }
}
