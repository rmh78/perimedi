import Foundation

public enum NextPendingDoseResolution: Equatable, Sendable {
    case pending(PlannedDose)
    case alreadyTaken(PlannedDose)
    case missing
}

/// Next pending planned dose, including overdue times today.
/// Does not honor per-med remindersEnabled or the master notification switch.
public enum NextPendingDose {
    public static let horizonDays = 14

    public static func select(
        now: Date,
        medications: [Medication],
        schedules: [Schedule],
        doseLogs: [DoseLog],
        periods: [Period],
        settings: CycleSettings,
        horizonDays: Int = horizonDays
    ) -> PlannedDose? {
        let today = DateKeys.toDateKey(now)
        let to = DateKeys.addDaysKey(today, horizonDays)
        let planned = ScheduleLogic.expandPlannedDoses(
            from: today,
            to: to,
            medications: medications,
            schedules: schedules,
            doseLogs: doseLogs,
            periods: periods,
            settings: settings
        )
        return planned
            .filter { $0.status == .pending }
            .sorted(by: Self.isOrderedBefore)
            .first
    }

    public static func resolve(
        identity: PlannedSlotIdentity,
        medications: [Medication],
        schedules: [Schedule],
        doseLogs: [DoseLog],
        periods: [Period],
        settings: CycleSettings
    ) -> NextPendingDoseResolution {
        let planned = ScheduleLogic.expandPlannedDoses(
            from: identity.date,
            to: identity.date,
            medications: medications,
            schedules: schedules,
            doseLogs: doseLogs,
            periods: periods,
            settings: settings
        )
        guard let dose = planned.first(where: { $0.identity == identity }) else {
            return .missing
        }
        if dose.status == .taken {
            return .alreadyTaken(dose)
        }
        return .pending(dose)
    }

    private static func isOrderedBefore(_ a: PlannedDose, _ b: PlannedDose) -> Bool {
        let fireA = DateKeys.date(dateKey: a.date, timeOfDay: a.timeOfDay) ?? .distantPast
        let fireB = DateKeys.date(dateKey: b.date, timeOfDay: b.timeOfDay) ?? .distantPast
        if fireA != fireB {
            return fireA < fireB
        }
        return a.medication.name < b.medication.name
    }
}
