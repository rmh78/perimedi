import Foundation

public enum DateCopy {
    public static func day(_ key: String, locale: Locale) -> String {
        render(key, template: "yMMMd", locale: locale)
    }

    public static func longDay(_ key: String, locale: Locale) -> String {
        render(key, template: "MMMMd yyyy", locale: locale)
    }

    public static func shortDay(_ key: String, locale: Locale) -> String {
        render(key, template: "d MMM", locale: locale)
    }

    public static func weekdayMonth(_ key: String, locale: Locale) -> String {
        render(key, template: "EEE MMMd", locale: locale)
    }

    public static func monthYear(_ date: Date, locale: Locale) -> String {
        render(date, template: "MMMM yyyy", locale: locale)
    }

    public static func field(_ key: String, locale: Locale) -> String {
        guard DateKeys.parseDateKey(key) != nil else { return key }
        guard locale.language.languageCode == .german else { return key }
        return render(key, format: "dd.MM.yyyy", locale: locale)
    }

    public static func closed(startKey: String, endKey: String, locale: Locale) -> String {
        "\(day(startKey, locale: locale)) \u{2013} \(day(endKey, locale: locale))"
    }

    public static func periodHistory(startKey: String, endKey: String?, locale: Locale) -> String {
        guard DateKeys.parseDateKey(startKey) != nil else { return startKey }
        if let endKey, DateKeys.parseDateKey(endKey) != nil {
            return closed(startKey: startKey, endKey: endKey, locale: locale)
        }
        return "\(day(startKey, locale: locale)) \u{2192} \u{2026}"
    }

    private static func render(_ key: String, template: String, locale: Locale) -> String {
        guard let date = DateKeys.parseDateKey(key) else { return key }
        return render(date, template: template, locale: locale)
    }

    private static func render(_ key: String, format: String, locale: Locale) -> String {
        guard let date = DateKeys.parseDateKey(key) else { return key }
        return render(date, format: format, locale: locale)
    }

    private static func render(_ date: Date, template: String, locale: Locale) -> String {
        cache.string(from: date, locale: locale, template: template, format: nil)
    }

    private static func render(_ date: Date, format: String, locale: Locale) -> String {
        cache.string(from: date, locale: locale, template: nil, format: format)
    }

    private static let cache = FormatterCache()
}

private final class FormatterCache: @unchecked Sendable {
    private let lock = NSLock()
    private var formatters: [String: DateFormatter] = [:]

    func string(from date: Date, locale: Locale, template: String?, format: String?) -> String {
        let cacheKey = "\(locale.identifier)|\(template ?? "")|\(format ?? "")"
        lock.lock()
        defer { lock.unlock() }
        let formatter: DateFormatter
        if let existing = formatters[cacheKey] {
            formatter = existing
        } else {
            let created = DateFormatter()
            var calendar = DateKeys.calendar
            calendar.locale = locale
            created.calendar = calendar
            created.locale = locale
            created.timeZone = calendar.timeZone
            if let template {
                created.setLocalizedDateFormatFromTemplate(template)
            }
            if let format {
                created.dateFormat = format
            }
            formatters[cacheKey] = created
            formatter = created
        }
        return formatter.string(from: date)
    }
}
