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

    /// "2026-09-20" → "20.09 Paz"
    public static func label(_ ymd: String) -> String {
        guard let p = parts(ymd),
              let date = calendar.date(from: DateComponents(year: p.y, month: p.m, day: p.d)) else { return ymd }
        return "\(short(ymd)) \(weekdays[calendar.component(.weekday, from: date) - 1])"
    }
}
