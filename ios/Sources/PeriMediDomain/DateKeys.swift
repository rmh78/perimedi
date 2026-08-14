import Foundation

public enum DateKeys {
    public static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US_POSIX")
        cal.timeZone = .current
        cal.firstWeekday = 1 // Sunday
        return cal
    }

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public static func toDateKey(_ date: Date) -> String {
        keyFormatter.string(from: calendar.startOfDay(for: date))
    }

    public static func toDateKey(_ value: String) -> String {
        if let date = parseDateKey(String(value.prefix(10))) {
            return toDateKey(date)
        }
        return String(value.prefix(10))
    }

    public static func parseDateKey(_ key: String) -> Date? {
        keyFormatter.date(from: String(key.prefix(10)))
    }

    public static func todayKey(_ now: Date = Date()) -> String {
        toDateKey(now)
    }

    public static func addDays(_ date: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: date)) ?? date
    }

    public static func addDaysKey(_ dateKey: String, _ days: Int) -> String {
        guard let date = parseDateKey(dateKey) else { return dateKey }
        return toDateKey(addDays(date, days))
    }

    public static func differenceInCalendarDays(from: Date, to: Date) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: from),
            to: calendar.startOfDay(for: to)
        ).day ?? 0
    }

    public static func differenceInCalendarDays(fromKey: String, toKey: String) -> Int {
        guard let from = parseDateKey(fromKey), let to = parseDateKey(toKey) else { return 0 }
        return differenceInCalendarDays(from: from, to: to)
    }

    public static func weekdaySundayZero(_ date: Date) -> Int {
        calendar.component(.weekday, from: date) - 1
    }

    public static func eachDay(from: String, to: String) -> [Date] {
        guard let start = parseDateKey(from), let end = parseDateKey(to) else { return [] }
        if start > end { return [] }
        var days: [Date] = []
        var cursor = start
        while cursor <= end {
            days.append(cursor)
            cursor = addDays(cursor, 1)
        }
        return days
    }

    public static func combineDateAndTime(dateKey: String, timeOfDay: String) -> String {
        let parts = timeOfDay.split(separator: ":")
        let hh = parts.count > 0 ? String(parts[0]).paddingLeft(to: 2) : "08"
        let mm = parts.count > 1 ? String(parts[1].prefix(2)) : "00"
        return "\(dateKey)T\(hh):\(mm):00"
    }

    public static func monthGridDays(anchor: Date) -> [Date] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: anchor)) ?? anchor
        let range = calendar.range(of: .day, in: .month, for: startOfMonth) ?? 1..<31
        let endOfMonth = addDays(startOfMonth, range.count - 1)
        let gridStart = startOfWeek(startOfMonth)
        let gridEnd = endOfWeek(endOfMonth)
        return eachDay(from: toDateKey(gridStart), to: toDateKey(gridEnd))
    }

    public static func startOfWeek(_ date: Date) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        return addDays(date, -(weekday - calendar.firstWeekday))
    }

    public static func endOfWeek(_ date: Date) -> Date {
        addDays(startOfWeek(date), 6)
    }

    public static func addMonths(_ date: Date, _ months: Int) -> Date {
        calendar.date(byAdding: .month, value: months, to: date) ?? date
    }
}

private extension String {
    func paddingLeft(to width: Int) -> String {
        if count >= width { return self }
        return String(repeating: "0", count: width - count) + self
    }
}
