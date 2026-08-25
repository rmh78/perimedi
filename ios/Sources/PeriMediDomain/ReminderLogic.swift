import Foundation

public struct ReminderSlot: Equatable, Sendable, Identifiable {
    public var medicationId: String
    public var scheduleId: String
    public var date: String
    public var timeOfDay: String
    public var medicationName: String
    public var doseLabel: String
    public var fireAt: Date

    public init(
        medicationId: String,
        scheduleId: String,
        date: String,
        timeOfDay: String,
        medicationName: String,
        doseLabel: String,
        fireAt: Date
    ) {
        self.medicationId = medicationId
        self.scheduleId = scheduleId
        self.date = date
        self.timeOfDay = timeOfDay
        self.medicationName = medicationName
        self.doseLabel = doseLabel
        self.fireAt = fireAt
    }

    public var id: String { Self.doseId(scheduleId: scheduleId, date: date, timeOfDay: timeOfDay) }
    public var snoozeId: String { Self.snoozeId(scheduleId: scheduleId, date: date, timeOfDay: timeOfDay) }

    public static func doseId(scheduleId: String, date: String, timeOfDay: String) -> String {
        "dose.\(scheduleId).\(date).\(timeOfDay)"
    }

    public static func snoozeId(scheduleId: String, date: String, timeOfDay: String) -> String {
        "snooze.\(scheduleId).\(date).\(timeOfDay)"
    }
}

public enum ReminderLogic {
    public static let horizonDays = 14
    public static let maxPending = 60
    public static let snoozeMinutes = 10

    public static func upcoming(
        now: Date,
        medications: [Medication],
        schedules: [Schedule],
        doseLogs: [DoseLog],
        periods: [Period],
        settings: CycleSettings,
        horizonDays: Int = horizonDays,
        limit: Int = maxPending
    ) -> [ReminderSlot] {
        let today = DateKeys.toDateKey(now)
        let to = DateKeys.addDaysKey(today, horizonDays)
        var slots = slots(
            from: today,
            to: to,
            medications: medications,
            schedules: schedules,
            doseLogs: doseLogs,
            periods: periods,
            settings: settings
        )
        slots.removeAll { $0.fireAt <= now }
        slots.sort { $0.fireAt < $1.fireAt }
        if slots.count > limit {
            return Array(slots.prefix(limit))
        }
        return slots
    }

    /// Pending slots on one calendar day, including times that have already passed.
    public static func pending(
        on dateKey: String,
        medications: [Medication],
        schedules: [Schedule],
        doseLogs: [DoseLog],
        periods: [Period],
        settings: CycleSettings
    ) -> [ReminderSlot] {
        slots(
            from: dateKey,
            to: dateKey,
            medications: medications,
            schedules: schedules,
            doseLogs: doseLogs,
            periods: periods,
            settings: settings
        )
    }

    private static func slots(
        from: String,
        to: String,
        medications: [Medication],
        schedules: [Schedule],
        doseLogs: [DoseLog],
        periods: [Period],
        settings: CycleSettings
    ) -> [ReminderSlot] {
        let planned = ScheduleLogic.expandPlannedDoses(
            from: from,
            to: to,
            medications: medications,
            schedules: schedules,
            doseLogs: doseLogs,
            periods: periods,
            settings: settings
        )
        return planned.compactMap { dose in
            guard dose.medication.remindersEnabled, dose.status == .pending else { return nil }
            guard let fireAt = DateKeys.date(dateKey: dose.date, timeOfDay: dose.timeOfDay) else { return nil }
            return ReminderSlot(
                medicationId: dose.medication.id,
                scheduleId: dose.schedule.id,
                date: dose.date,
                timeOfDay: dose.timeOfDay,
                medicationName: dose.medication.name,
                doseLabel: dose.doseLabel,
                fireAt: fireAt
            )
        }
    }
}
