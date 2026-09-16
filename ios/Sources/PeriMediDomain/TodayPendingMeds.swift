import Foundation

public struct TodayPendingMedication: Equatable, Sendable {
    public var medication: Medication
    public var pending: [PlannedDose]

    public var date: String { pending[0].date }
    public var earliestTimeOfDay: String { pending[0].timeOfDay }
    public var doseLabel: String { pending[0].doseLabel }

    public init?(medication: Medication, pending: [PlannedDose]) {
        let valid = pending
            .filter { $0.status == .pending && $0.medication.id == medication.id }
            .sorted { a, b in
                if a.timeOfDay != b.timeOfDay { return a.timeOfDay < b.timeOfDay }
                return a.key < b.key
            }
        guard let first = valid.first else { return nil }
        let sameDay = valid.filter { $0.date == first.date }
        guard sameDay.count == valid.count, !sameDay.isEmpty else { return nil }
        self.medication = medication
        self.pending = sameDay
    }
}

public enum TodayPendingMeds {
    public static func list(
        now: Date,
        medications: [Medication],
        schedules: [Schedule],
        doseLogs: [DoseLog],
        periods: [Period],
        settings: CycleSettings
    ) -> [TodayPendingMedication] {
        let dateKey = DateKeys.toDateKey(now)
        let planned = ScheduleLogic.expandPlannedDoses(
            from: dateKey,
            to: dateKey,
            medications: medications,
            schedules: schedules,
            doseLogs: doseLogs,
            periods: periods,
            settings: settings
        )
        let pending = planned.filter { $0.status == .pending }
        let grouped = Dictionary(grouping: pending, by: { $0.medication.id })
        return grouped.values.compactMap { slots in
            guard let medication = slots.first?.medication else { return nil }
            return TodayPendingMedication(medication: medication, pending: slots)
        }
        .sorted(by: isOrderedBefore)
    }

    private static func isOrderedBefore(_ a: TodayPendingMedication, _ b: TodayPendingMedication) -> Bool {
        let fireA = DateKeys.date(dateKey: a.date, timeOfDay: a.earliestTimeOfDay) ?? .distantPast
        let fireB = DateKeys.date(dateKey: b.date, timeOfDay: b.earliestTimeOfDay) ?? .distantPast
        if fireA != fireB {
            return fireA < fireB
        }
        return a.medication.name < b.medication.name
    }
}
