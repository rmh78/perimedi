import Foundation

public struct SymptomTrendPoint: Equatable, Sendable {
    public var cycleStart: String
    public var cycleEnd: String
    /// Days scored that cycle for this id. Missing days are omitted, not 0.
    public var dayCount: Int
    /// Mean of logged 1–4 severities that cycle. Not the sum.
    public var meanIntensity: Double

    public init(cycleStart: String, cycleEnd: String, dayCount: Int, meanIntensity: Double) {
        self.cycleStart = cycleStart
        self.cycleEnd = cycleEnd
        self.dayCount = dayCount
        self.meanIntensity = meanIntensity
    }
}

public struct SymptomTrendSeries: Equatable, Sendable {
    public var id: String
    public var points: [SymptomTrendPoint]

    public init(id: String, points: [SymptomTrendPoint]) {
        self.id = id
        self.points = points
    }
}

public struct CycleChangeTick: Equatable, Sendable {
    public var cycleStart: String
    public var effectiveDate: String
    public var nameSnapshot: String
    public var newValue: String
    public var field: MedicationChangeField

    public init(
        cycleStart: String,
        effectiveDate: String,
        nameSnapshot: String,
        newValue: String,
        field: MedicationChangeField
    ) {
        self.cycleStart = cycleStart
        self.effectiveDate = effectiveDate
        self.nameSnapshot = nameSnapshot
        self.newValue = newValue
        self.field = field
    }
}

public struct SymptomTrendChart: Equatable, Sendable {
    public var cycles: [LoggedCycle]
    public var series: [SymptomTrendSeries]
    public var ticks: [CycleChangeTick]
    public var defaultIds: [String]

    public init(
        cycles: [LoggedCycle],
        series: [SymptomTrendSeries],
        ticks: [CycleChangeTick],
        defaultIds: [String]
    ) {
        self.cycles = cycles
        self.series = series
        self.ticks = ticks
        self.defaultIds = defaultIds
    }
}

public enum SymptomTrendKind: Equatable, Sendable {
    case hidden
    case needCycles
    case noScores
    case chart(SymptomTrendChart)
}

public struct SymptomTrendResult: Equatable, Sendable {
    public var kind: SymptomTrendKind

    public init(kind: SymptomTrendKind) {
        self.kind = kind
    }
}

public enum SymptomTrendLogic {
    public static let maxSeries = 3
    public static let preferredCycleCount = 6

    public static func summarize(
        today: String,
        periods: [Period],
        settings: CycleSettings,
        scores: [SymptomScore],
        changes: [MedicationChange],
        selectedIds: [String]? = nil
    ) -> SymptomTrendResult {
        guard settings.tracksPeriods else {
            return SymptomTrendResult(kind: .hidden)
        }
        let today = DateKeys.toDateKey(today)
        let windows = CycleLogic.loggedCycleWindows(periods: periods, today: today)
        guard !windows.isEmpty else {
            return SymptomTrendResult(kind: .needCycles)
        }

        let scored = windows.filter { cycle in
            scores.contains { score in
                inCycle(score, cycle) && score.severity >= 1
            }
        }
        guard !scored.isEmpty else {
            return SymptomTrendResult(kind: .noScores)
        }

        let cycles = Array(scored.suffix(preferredCycleCount))
        let spanStart = cycles.first!.start
        let spanEnd = cycles.last!.end
        let dayCounts = dayCountsById(scores, from: spanStart, to: spanEnd)
        let ranked = SymptomId.allCases
            .map(\.rawValue)
            .filter { dayCounts[$0, default: 0] > 0 }
            .sorted { a, b in
                let ca = dayCounts[a, default: 0]
                let cb = dayCounts[b, default: 0]
                if ca != cb { return ca > cb }
                return catalogIndex(a) < catalogIndex(b)
            }
        let defaultIds = Array(ranked.prefix(maxSeries))

        var selected: [String]
        if let selectedIds {
            selected = selectedIds.filter { SymptomLog.isCatalogId($0) }
            if selected.count > maxSeries {
                selected = Array(selected.prefix(maxSeries))
            }
        } else {
            selected = Array(defaultIds)
        }
        selected.sort { catalogIndex($0) < catalogIndex($1) }

        let series = selected.map { id in
            SymptomTrendSeries(
                id: id,
                points: cycles.compactMap { cycle in point(scores, id: id, cycle: cycle) }
            )
        }
        let ticks = ticks(in: changes, cycles: cycles)
        return SymptomTrendResult(
            kind: .chart(
                SymptomTrendChart(
                    cycles: cycles,
                    series: series,
                    ticks: ticks,
                    defaultIds: defaultIds
                )
            )
        )
    }

    /// Toggle a catalog id in the current selection. At most `maxSeries` stay
    /// selected; a new pick replaces the least-logged of the current set.
    public static func toggling(_ id: String, in current: [String], ranked: [String]) -> [String] {
        guard SymptomLog.isCatalogId(id) else { return current }
        var next = current.filter { SymptomLog.isCatalogId($0) }
        if let index = next.firstIndex(of: id) {
            next.remove(at: index)
            return next
        }
        if next.count >= maxSeries {
            let drop = next.max { a, b in
                rank(a, in: ranked) < rank(b, in: ranked)
            }
            if let drop {
                next.removeAll { $0 == drop }
            }
        }
        next.append(id)
        return next
    }

    private static func rank(_ id: String, in ranked: [String]) -> Int {
        ranked.firstIndex(of: id) ?? ranked.count
    }

    private static func inCycle(_ score: SymptomScore, _ cycle: LoggedCycle) -> Bool {
        let day = DateKeys.toDateKey(score.date)
        return day >= cycle.start && day <= cycle.end
    }

    private static func point(
        _ scores: [SymptomScore],
        id: String,
        cycle: LoggedCycle
    ) -> SymptomTrendPoint? {
        var byDay: [String: Int] = [:]
        for row in scores where row.id == id && inCycle(row, cycle) && row.severity >= 1 {
            byDay[DateKeys.toDateKey(row.date)] = row.severity
        }
        guard !byDay.isEmpty else { return nil }
        let vals = Array(byDay.values)
        let mean = Double(vals.reduce(0, +)) / Double(vals.count)
        return SymptomTrendPoint(
            cycleStart: cycle.start,
            cycleEnd: cycle.end,
            dayCount: vals.count,
            meanIntensity: mean
        )
    }

    private static func dayCountsById(
        _ scores: [SymptomScore],
        from: String,
        to: String
    ) -> [String: Int] {
        var days: [String: Set<String>] = [:]
        for row in scores where row.severity >= 1 {
            let day = DateKeys.toDateKey(row.date)
            if day < from || day > to { continue }
            days[row.id, default: []].insert(day)
        }
        return days.mapValues(\.count)
    }

    private static func catalogIndex(_ id: String) -> Int {
        SymptomId.allCases.firstIndex { $0.rawValue == id } ?? Int.max
    }

    private static func ticks(
        in changes: [MedicationChange],
        cycles: [LoggedCycle]
    ) -> [CycleChangeTick] {
        var out: [CycleChangeTick] = []
        for cycle in cycles {
            let inCycle = changes.filter { change in
                let day = DateKeys.toDateKey(change.effectiveDate)
                return day >= cycle.start && day <= cycle.end
            }
            let doses = inCycle.filter { $0.field == .dose }
            let pool = doses.isEmpty ? inCycle : doses
            guard let chosen = pool.max(by: { a, b in
                if a.effectiveDate != b.effectiveDate { return a.effectiveDate < b.effectiveDate }
                return a.loggedAt < b.loggedAt
            }) else { continue }
            out.append(
                CycleChangeTick(
                    cycleStart: cycle.start,
                    effectiveDate: DateKeys.toDateKey(chosen.effectiveDate),
                    nameSnapshot: chosen.nameSnapshot,
                    newValue: chosen.newValue,
                    field: chosen.field
                )
            )
        }
        return out
    }
}
