import Foundation

public enum NextPendingDoseResolution: Equatable, Sendable {
    case pending(PlannedDose)
    case alreadyTaken(PlannedDose)
    case missing
}

/// Resolve one planned slot for reminder Taken.
public enum NextPendingDose {
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
}
