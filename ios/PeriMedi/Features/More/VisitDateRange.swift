import Foundation
import PeriMediDomain

enum VisitDateRange {
    static func day(_ key: String, locale: Locale) -> String {
        guard let date = DateKeys.parseDateKey(key) else { return key }
        var calendar = DateKeys.calendar
        calendar.locale = locale
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("yMMMd")
        return formatter.string(from: date)
    }

    static func closed(startKey: String, endKey: String, locale: Locale) -> String {
        "\(day(startKey, locale: locale)) \u{2013} \(day(endKey, locale: locale))"
    }

    static func periodHistory(startKey: String, endKey: String?, locale: Locale) -> String {
        guard DateKeys.parseDateKey(startKey) != nil else { return startKey }
        if let endKey, DateKeys.parseDateKey(endKey) != nil {
            return closed(startKey: startKey, endKey: endKey, locale: locale)
        }
        return "\(day(startKey, locale: locale)) \u{2192} \u{2026}"
    }
}
