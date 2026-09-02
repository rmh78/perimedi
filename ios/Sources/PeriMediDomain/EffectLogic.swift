import Foundation

public struct SymptomShift: Equatable, Sendable {
    public enum Direction: Equatable, Sendable {
        case improved
        case worse
    }

    public var id: String
    public var direction: Direction
    public var magnitude: Double

    public init(id: String, direction: Direction, magnitude: Double) {
        self.id = id
        self.direction = direction
        self.magnitude = magnitude
    }
}

public struct EffectResult: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case hidden
        case noPreviousCycle
        case notEnoughDays
        case similar
        case changed([SymptomShift])
    }

    public var kind: Kind
    public var context: MedicationChange?

    public init(kind: Kind, context: MedicationChange? = nil) {
        self.kind = kind
        self.context = context
    }
}

public enum EffectLogic {
    public static let meanThreshold = 0.5
    public static let maxShifts = 3

    public static func summarize(
        today: String,
        periods: [Period],
        settings: CycleSettings,
        scores: [SymptomScore],
        changes: [MedicationChange]
    ) -> EffectResult {
        guard settings.tracksPeriods else {
            return EffectResult(kind: .hidden)
        }
        let today = DateKeys.toDateKey(today)
        let starts = Array(Set(periods.map { DateKeys.toDateKey($0.startDate) })).sorted()
        guard let currentStart = starts.last(where: { $0 <= today }) else {
            return EffectResult(kind: .hidden)
        }
        guard let currentIndex = starts.lastIndex(of: currentStart), currentIndex > 0 else {
            return EffectResult(kind: .noPreviousCycle)
        }
        let previousStart = starts[currentIndex - 1]
        let nextStart = currentIndex + 1 < starts.count ? starts[currentIndex + 1] : nil
        let previousEnd = DateKeys.addDaysKey(currentStart, -1)
        let currentEnd = nextStart.map { DateKeys.addDaysKey($0, -1) } ?? today
        let todayInCycle = min(today, currentEnd)

        let n = DateKeys.differenceInCalendarDays(fromKey: currentStart, toKey: todayInCycle) + 1
        let previousLength = DateKeys.differenceInCalendarDays(fromKey: previousStart, toKey: previousEnd) + 1
        let overlap = min(n, previousLength)
        guard overlap >= 1 else {
            return EffectResult(kind: .notEnoughDays)
        }

        let currentDates = dateKeys(from: currentStart, count: overlap)
        let previousDates = dateKeys(from: previousStart, count: overlap)
        let currentSet = Set(currentDates)
        let previousSet = Set(previousDates)

        var shifts: [SymptomShift] = []
        var overlappingIds = 0
        for id in SymptomId.allCases {
            let currentMean = mean(scores, id: id.rawValue, dates: currentSet)
            let previousMean = mean(scores, id: id.rawValue, dates: previousSet)
            guard let currentMean, let previousMean else { continue }
            overlappingIds += 1
            let delta = currentMean - previousMean
            if delta >= meanThreshold {
                shifts.append(SymptomShift(id: id.rawValue, direction: .worse, magnitude: delta))
            } else if delta <= -meanThreshold {
                shifts.append(SymptomShift(id: id.rawValue, direction: .improved, magnitude: -delta))
            }
        }

        let spanStart = previousStart
        let spanEnd = todayInCycle
        let context = contextChange(in: changes, from: spanStart, to: spanEnd)

        if overlappingIds == 0 {
            return EffectResult(kind: .notEnoughDays)
        }
        if shifts.isEmpty {
            return EffectResult(kind: .similar, context: context)
        }
        let top = Array(shifts.sorted { $0.magnitude > $1.magnitude }.prefix(maxShifts))
        let ordered = SymptomId.allCases.compactMap { id in top.first { $0.id == id.rawValue } }
        return EffectResult(kind: .changed(ordered), context: context)
    }

    private static func dateKeys(from start: String, count: Int) -> [String] {
        (0..<count).map { DateKeys.addDaysKey(start, $0) }
    }

    private static func mean(_ scores: [SymptomScore], id: String, dates: Set<String>) -> Double? {
        let vals = scores.compactMap { row -> Int? in
            guard row.id == id, dates.contains(DateKeys.toDateKey(row.date)) else { return nil }
            return row.severity
        }
        guard !vals.isEmpty else { return nil }
        return Double(vals.reduce(0, +)) / Double(vals.count)
    }

    private static func contextChange(
        in changes: [MedicationChange],
        from: String,
        to: String
    ) -> MedicationChange? {
        let inSpan = changes.filter { change in
            let day = DateKeys.toDateKey(change.effectiveDate)
            return day >= from && day <= to
        }
        guard !inSpan.isEmpty else { return nil }
        let doses = inSpan.filter { $0.field == .dose }
        let pool = doses.isEmpty ? inSpan : doses
        return pool.max { a, b in
            if a.effectiveDate != b.effectiveDate { return a.effectiveDate < b.effectiveDate }
            return a.loggedAt < b.loggedAt
        }
    }
}
