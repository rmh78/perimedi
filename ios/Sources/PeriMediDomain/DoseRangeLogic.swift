import Foundation

public enum DoseRangeLogic {
    public static func doseExpansionRange(
        today: String,
        selectedDate: String,
        periods: [Period],
        settings: CycleSettings,
        extraFrom: [String] = [],
        extraTo: [String] = []
    ) -> (from: String, to: String) {
        let selectedWindow = CycleLogic.cycleWindowForDate(
            dateKey: selectedDate,
            periods: periods,
            settings: settings
        )
        let selectedWindowEnd = DateKeys.addDaysKey(selectedWindow.start, selectedWindow.length - 1)
        let latestCycleStart = CycleLogic.lastPeriodStart(periods)
        let latestCycleLen = max(settings.averagePeriodLength + 2, settings.averageCycleLength)
        let latestCycleEnd = latestCycleStart.map { DateKeys.addDaysKey($0, latestCycleLen - 1) }

        var fromKeys = [today, selectedDate, selectedWindow.start] + extraFrom
        if let latestCycleStart { fromKeys.append(latestCycleStart) }
        var toKeys = [today, selectedDate, selectedWindowEnd] + extraTo
        if let latestCycleEnd { toKeys.append(latestCycleEnd) }

        fromKeys.sort()
        toKeys.sort()
        return (fromKeys.first ?? today, toKeys.last ?? today)
    }
}
