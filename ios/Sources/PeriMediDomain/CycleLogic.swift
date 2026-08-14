import Foundation

public enum CycleLogic {
    public static func periodCoversDate(
        _ period: Period,
        dateKey: String,
        defaultPeriodLength: Int
    ) -> Bool {
        let start = DateKeys.toDateKey(period.startDate)
        if dateKey < start { return false }
        if let endDate = period.endDate {
            return dateKey <= DateKeys.toDateKey(endDate)
        }
        let end = DateKeys.addDaysKey(start, defaultPeriodLength - 1)
        return dateKey <= end
    }

    public static func sortPeriods(_ periods: [Period]) -> [Period] {
        periods.sorted { $0.startDate > $1.startDate }
    }

    public static func lastPeriodStart(_ periods: [Period]) -> String? {
        sortPeriods(periods).first.map { DateKeys.toDateKey($0.startDate) }
    }

    public static func periodStartOnOrBefore(dateKey: String, periods: [Period]) -> String? {
        periods
            .map { DateKeys.toDateKey($0.startDate) }
            .filter { $0 <= dateKey }
            .sorted()
            .last
    }

    public static func cycleWindowForDate(
        dateKey: String,
        periods: [Period],
        settings: CycleSettings
    ) -> (start: String, length: Int) {
        let baseLen = max(2, settings.averagePeriodLength + 2, settings.averageCycleLength)
        if let start = periodStartOnOrBefore(dateKey: dateKey, periods: periods) {
            let dayIndex = DateKeys.differenceInCalendarDays(fromKey: start, toKey: dateKey) + 1
            let length = min(90, max(baseLen, dayIndex > 0 ? dayIndex : baseLen))
            return (start, length)
        }
        return (dateKey, baseLen)
    }

    public static func getCycleDay(dateKey: String, periods: [Period]) -> Int? {
        guard let last = periodStartOnOrBefore(dateKey: dateKey, periods: periods) else {
            return nil
        }
        return DateKeys.differenceInCalendarDays(fromKey: last, toKey: dateKey) + 1
    }

    public static func getDayCycleInfo(
        dateKey: String,
        periods: [Period],
        settings: CycleSettings
    ) -> DayCycleInfo {
        let isLoggedPeriod = periods.contains {
            periodCoversDate($0, dateKey: dateKey, defaultPeriodLength: settings.averagePeriodLength)
        }
        let cycleDay = getCycleDay(dateKey: dateKey, periods: periods)
        var isPredictedPeriod = false

        if let lastStart = lastPeriodStart(periods), let lastDate = DateKeys.parseDateKey(lastStart) {
            let cycleLen = max(2, settings.averageCycleLength)
            let periodLen = max(1, settings.averagePeriodLength)
            let horizon = DateKeys.addDaysKey(dateKey, cycleLen * 3)
            var cycleStart = lastDate
            for i in 0..<24 {
                let cs = DateKeys.toDateKey(cycleStart)
                if cs > horizon { break }
                if i > 0 {
                    let pe = DateKeys.toDateKey(DateKeys.addDays(cycleStart, periodLen - 1))
                    if dateKey >= cs && dateKey <= pe {
                        isPredictedPeriod = true
                    }
                }
                cycleStart = DateKeys.addDays(cycleStart, cycleLen)
            }
        }

        if isLoggedPeriod {
            isPredictedPeriod = false
        }

        return DayCycleInfo(
            date: dateKey,
            isLoggedPeriod: isLoggedPeriod,
            isPredictedPeriod: isPredictedPeriod,
            cycleDay: cycleDay
        )
    }

    public static func matchesCycleRule(
        _ info: DayCycleInfo,
        cycleRule: CycleRule,
        cycleDayFrom: Int?,
        cycleDayTo: Int?
    ) -> Bool {
        switch cycleRule {
        case .none:
            return true
        case .period_only:
            return info.isLoggedPeriod || info.isPredictedPeriod
        case .cycle_day_range:
            guard let cycleDay = info.cycleDay else { return false }
            let from = cycleDayFrom ?? 1
            let to = cycleDayTo ?? from
            return cycleDay >= from && cycleDay <= to
        }
    }

    public static func nextPredictedPeriodStart(
        periods: [Period],
        settings: CycleSettings
    ) -> String? {
        guard let last = lastPeriodStart(periods) else { return nil }
        return DateKeys.addDaysKey(last, settings.averageCycleLength)
    }

    public static func periodLengthDays(_ period: Period, defaultLen: Int) -> Int {
        guard let end = period.endDate,
              DateKeys.parseDateKey(end) != nil,
              DateKeys.parseDateKey(period.startDate) != nil
        else {
            return defaultLen
        }
        return DateKeys.differenceInCalendarDays(
            fromKey: DateKeys.toDateKey(period.startDate),
            toKey: DateKeys.toDateKey(end)
        ) + 1
    }

    public static func cycleBoundaryMarkers(
        from: String,
        to: String,
        periods: [Period],
        settings: CycleSettings
    ) -> [String: CycleBoundaryMark] {
        let cycleLen = max(2, settings.averageCycleLength)
        let periodLen = max(1, settings.averagePeriodLength)
        var starts = Set<String>()

        for p in periods {
            starts.insert(DateKeys.toDateKey(p.startDate))
        }

        if let last = lastPeriodStart(periods), let lastDate = DateKeys.parseDateKey(last) {
            var predictedStart = DateKeys.addDays(lastDate, cycleLen)
            for i in 0..<36 {
                let key = DateKeys.toDateKey(predictedStart)
                if key > to && i > 0 { break }
                let insideLoggedBleed = periods.contains { p in
                    DateKeys.toDateKey(p.startDate) != key
                        && periodCoversDate(p, dateKey: key, defaultPeriodLength: periodLen)
                }
                if !insideLoggedBleed {
                    starts.insert(key)
                }
                predictedStart = DateKeys.addDays(predictedStart, cycleLen)
            }
        }

        let sortedStarts = starts.sorted()
        var ends = Set<String>()
        for (i, s) in sortedStarts.enumerated() {
            if i + 1 < sortedStarts.count, let nextDate = DateKeys.parseDateKey(sortedStarts[i + 1]) {
                ends.insert(DateKeys.toDateKey(DateKeys.addDays(nextDate, -1)))
            } else if let sDate = DateKeys.parseDateKey(s) {
                ends.insert(DateKeys.toDateKey(DateKeys.addDays(sDate, cycleLen - 1)))
            }
        }

        var map: [String: CycleBoundaryMark] = [:]
        for s in sortedStarts where s >= from && s <= to {
            map[s] = CycleBoundaryMark(isStart: true, isEnd: ends.contains(s))
        }
        for e in ends where e >= from && e <= to {
            let prev = map[e] ?? CycleBoundaryMark(isStart: false, isEnd: false)
            map[e] = CycleBoundaryMark(isStart: prev.isStart, isEnd: true)
        }
        return map
    }
}
