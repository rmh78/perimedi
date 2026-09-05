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

/// Device notification permission, without importing UserNotifications into domain.
public enum ReminderAuthStatus: String, Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
}

public enum ReminderPermissionPolicy {
    /// Ask once while reminders are on and iOS has not decided. Never from UI tests.
    public static func shouldRequestAuthorization(
        masterEnabled: Bool,
        status: ReminderAuthStatus,
        uiTesting: Bool
    ) -> Bool {
        !uiTesting && masterEnabled && status == .notDetermined
    }

    public static func shouldScheduleDoseReminders(
        masterEnabled: Bool,
        status: ReminderAuthStatus
    ) -> Bool {
        guard masterEnabled else { return false }
        switch status {
        case .authorized, .provisional, .ephemeral: return true
        case .notDetermined, .denied: return false
        }
    }
}

/// Calendar pieces for a local notification, with an explicit time zone so
/// TestFlight/device alarms are not interpreted as GMT.
public struct ReminderFireComponents: Equatable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int
    public var hour: Int
    public var minute: Int
    public var second: Int
    public var timeZoneIdentifier: String

    public init(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int,
        timeZoneIdentifier: String
    ) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    public static func from(
        fireAt: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ReminderFireComponents? {
        guard fireAt > now else { return nil }
        var cal = calendar
        let tz = calendar.timeZone
        cal.timeZone = tz
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireAt)
        guard
            let year = c.year,
            let month = c.month,
            let day = c.day,
            let hour = c.hour,
            let minute = c.minute
        else { return nil }
        return ReminderFireComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: c.second ?? 0,
            timeZoneIdentifier: tz.identifier
        )
    }

    public var dateComponents: DateComponents {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        var c = DateComponents()
        c.calendar = cal
        c.timeZone = cal.timeZone
        c.year = year
        c.month = month
        c.day = day
        c.hour = hour
        c.minute = minute
        c.second = second
        return c
    }
}

public enum ReminderTriggerKind: Equatable, Sendable {
    case timeInterval(TimeInterval)
    case calendar(ReminderFireComponents)
}

public enum ReminderLogic {
    public static let horizonDays = 14
    public static let maxPending = 60
    public static let snoozeMinutes = 10

    /// How to fire a local notification so it is not dropped as “already past”
    /// (calendar components without a time zone can be read as GMT on device).
    public static func triggerKind(fireAt: Date, now: Date = Date(), calendar: Calendar = .current) -> ReminderTriggerKind? {
        let remaining = fireAt.timeIntervalSince(now)
        guard remaining > 0 else { return nil }
        if remaining < 90 {
            return .timeInterval(max(1, remaining))
        }
        guard let comps = ReminderFireComponents.from(fireAt: fireAt, now: now, calendar: calendar) else {
            return nil
        }
        return .calendar(comps)
    }

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
