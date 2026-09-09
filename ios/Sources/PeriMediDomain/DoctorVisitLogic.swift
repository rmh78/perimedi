import Foundation

public enum DoctorVisitRangeKind: Equatable, Sendable {
    case completedCycles(Int)
    case fourWeeks
    case twelveWeeks
}

public struct DoctorVisitMedRow: Equatable, Sendable {
    public var medicationId: String
    public var name: String
    public var doseLabel: String
    public var planned: Int
    public var taken: Int

    public init(medicationId: String, name: String, doseLabel: String, planned: Int, taken: Int) {
        self.medicationId = medicationId
        self.name = name
        self.doseLabel = doseLabel
        self.planned = planned
        self.taken = taken
    }

    public var percent: Int {
        guard planned > 0 else { return 0 }
        return Int((Double(taken) / Double(planned) * 100).rounded())
    }
}

public struct DoctorVisitSymptomRow: Equatable, Sendable {
    public var id: String
    public var dayCount: Int
    public var meanIntensity: Double

    public init(id: String, dayCount: Int, meanIntensity: Double) {
        self.id = id
        self.dayCount = dayCount
        self.meanIntensity = meanIntensity
    }
}

public struct DoctorVisitPeriodRow: Equatable, Sendable {
    public var start: String
    public var end: String

    public init(start: String, end: String) {
        self.start = start
        self.end = end
    }
}

public struct DoctorVisitReport: Equatable, Sendable {
    public var generatedOn: String
    public var rangeStart: String
    public var rangeEnd: String
    public var rangeKind: DoctorVisitRangeKind
    public var medications: [DoctorVisitMedRow]
    public var changes: [MedicationChange]
    public var periods: [DoctorVisitPeriodRow]
    public var symptoms: [DoctorVisitSymptomRow]
    public var effect: EffectResult

    public init(
        generatedOn: String,
        rangeStart: String,
        rangeEnd: String,
        rangeKind: DoctorVisitRangeKind,
        medications: [DoctorVisitMedRow],
        changes: [MedicationChange],
        periods: [DoctorVisitPeriodRow],
        symptoms: [DoctorVisitSymptomRow],
        effect: EffectResult
    ) {
        self.generatedOn = generatedOn
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.rangeKind = rangeKind
        self.medications = medications
        self.changes = changes
        self.periods = periods
        self.symptoms = symptoms
        self.effect = effect
    }
}

public enum DoctorVisitLogic {
    public static let fourWeekDays = 28
    public static let twelveWeekDays = 84

    /// Completed cycles only (drops the open window that ends today).
    public static func completedCycles(
        today: String,
        periods: [Period],
        settings: CycleSettings
    ) -> [LoggedCycle] {
        guard settings.tracksPeriods else { return [] }
        let windows = CycleLogic.loggedCycleWindows(
            periods: periods,
            today: DateKeys.toDateKey(today)
        )
        return Array(windows.dropLast())
    }

    public static func report(
        today: String,
        medications: [Medication],
        schedules: [Schedule],
        doseLogs: [DoseLog],
        periods: [Period],
        settings: CycleSettings,
        scores: [SymptomScore],
        changes: [MedicationChange],
        selectedCycles: [LoggedCycle] = []
    ) -> DoctorVisitReport {
        let today = DateKeys.toDateKey(today)
        let from: String
        let to: String
        let kind: DoctorVisitRangeKind
        if !selectedCycles.isEmpty {
            let ordered = selectedCycles.sorted { $0.start < $1.start }
            from = ordered[0].start
            to = ordered[ordered.count - 1].end
            kind = .completedCycles(ordered.count)
        } else {
            (from, to, kind) = range(today: today, periods: periods, settings: settings)
        }
        let rawEffect = EffectLogic.summarize(
            today: today,
            periods: periods,
            settings: settings,
            scores: scores,
            changes: changes
        )
        return DoctorVisitReport(
            generatedOn: today,
            rangeStart: from,
            rangeEnd: to,
            rangeKind: kind,
            medications: medRows(
                from: from,
                to: to,
                medications: medications,
                schedules: schedules,
                doseLogs: doseLogs,
                periods: periods,
                settings: settings
            ),
            changes: changesInRange(changes, from: from, to: to),
            periods: periodRows(periods, from: from, to: to, settings: settings),
            symptoms: symptomRows(scores, from: from, to: to),
            effect: effectInRange(rawEffect, from: from, to: to)
        )
    }

    /// Drop the Cycle Effect sentence when it names a change outside this PDF range.
    static func effectInRange(_ effect: EffectResult, from: String, to: String) -> EffectResult {
        guard let ctx = effect.context else { return effect }
        let day = DateKeys.toDateKey(ctx.effectiveDate)
        if day < from || day > to {
            return EffectResult(kind: .hidden)
        }
        return effect
    }

    static func range(
        today: String,
        periods: [Period],
        settings: CycleSettings
    ) -> (String, String, DoctorVisitRangeKind) {
        if !settings.tracksPeriods {
            return calendarRange(today: today, days: twelveWeekDays, kind: .twelveWeeks)
        }
        let windows = CycleLogic.loggedCycleWindows(periods: periods, today: today)
        let completed = Array(windows.dropLast())
        if completed.count >= 2 {
            let slice = Array(completed.suffix(2))
            return (slice[0].start, slice[1].end, .completedCycles(2))
        }
        if let only = completed.first {
            return (only.start, only.end, .completedCycles(1))
        }
        if !windows.isEmpty {
            return calendarRange(today: today, days: fourWeekDays, kind: .fourWeeks)
        }
        return calendarRange(today: today, days: twelveWeekDays, kind: .twelveWeeks)
    }

    private static func calendarRange(
        today: String,
        days: Int,
        kind: DoctorVisitRangeKind
    ) -> (String, String, DoctorVisitRangeKind) {
        (DateKeys.addDaysKey(today, -(days - 1)), today, kind)
    }

    private static func medRows(
        from: String,
        to: String,
        medications: [Medication],
        schedules: [Schedule],
        doseLogs: [DoseLog],
        periods: [Period],
        settings: CycleSettings
    ) -> [DoctorVisitMedRow] {
        let planned = ScheduleLogic.expandPlannedDoses(
            from: from,
            to: to,
            medications: medications,
            schedules: schedules,
            doseLogs: doseLogs,
            periods: periods,
            settings: settings
        )
        var byId: [String: (name: String, dose: String, planned: Int, taken: Int)] = [:]
        for dose in planned {
            var row = byId[dose.medication.id] ?? (
                name: dose.medication.name,
                dose: dose.medication.doseLabel,
                planned: 0,
                taken: 0
            )
            row.planned += 1
            if dose.status == .taken { row.taken += 1 }
            byId[dose.medication.id] = row
        }
        return byId.keys.sorted { a, b in
            byId[a]!.name < byId[b]!.name
        }.compactMap { id in
            guard let row = byId[id], row.planned > 0 else { return nil }
            return DoctorVisitMedRow(
                medicationId: id,
                name: row.name,
                doseLabel: row.dose,
                planned: row.planned,
                taken: row.taken
            )
        }
    }

    private static func changesInRange(
        _ changes: [MedicationChange],
        from: String,
        to: String
    ) -> [MedicationChange] {
        changes.filter { change in
            let day = DateKeys.toDateKey(change.effectiveDate)
            return day >= from && day <= to
        }
        .sorted { a, b in
            if a.effectiveDate != b.effectiveDate { return a.effectiveDate < b.effectiveDate }
            return a.loggedAt < b.loggedAt
        }
    }

    private static func periodRows(
        _ periods: [Period],
        from: String,
        to: String,
        settings: CycleSettings
    ) -> [DoctorVisitPeriodRow] {
        let defaultLen = max(1, settings.averagePeriodLength)
        return periods.compactMap { period in
            let start = DateKeys.toDateKey(period.startDate)
            let end = period.endDate.map(DateKeys.toDateKey)
                ?? DateKeys.addDaysKey(start, defaultLen - 1)
            guard start <= to, end >= from else { return nil }
            return DoctorVisitPeriodRow(start: start, end: end)
        }
        .sorted { $0.start < $1.start }
    }

    /// Days scored + mean. Missing days omitted. `hot_flash` count field ignored.
    private static func symptomRows(
        _ scores: [SymptomScore],
        from: String,
        to: String
    ) -> [DoctorVisitSymptomRow] {
        SymptomId.allCases.compactMap { id in
            var byDay: [String: Int] = [:]
            for row in scores where row.id == id.rawValue && row.severity >= 1 {
                let day = DateKeys.toDateKey(row.date)
                if day < from || day > to { continue }
                byDay[day] = row.severity
            }
            guard !byDay.isEmpty else { return nil }
            let vals = Array(byDay.values)
            let mean = Double(vals.reduce(0, +)) / Double(vals.count)
            return DoctorVisitSymptomRow(
                id: id.rawValue,
                dayCount: vals.count,
                meanIntensity: mean
            )
        }
    }
}
