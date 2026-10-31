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

    public static func followUpId(scheduleId: String, date: String, timeOfDay: String, step: Int) -> String {
        "follow.\(scheduleId).\(date).\(timeOfDay).\(step)"
    }

    public static func followUpIds(scheduleId: String, date: String, timeOfDay: String) -> [String] {
        (1...3).map { followUpId(scheduleId: scheduleId, date: date, timeOfDay: timeOfDay, step: $0) }
    }

    public static func ids(scheduleId: String, date: String, timeOfDay: String) -> [String] {
        [
            doseId(scheduleId: scheduleId, date: date, timeOfDay: timeOfDay),
            snoozeId(scheduleId: scheduleId, date: date, timeOfDay: timeOfDay),
        ] + followUpIds(scheduleId: scheduleId, date: date, timeOfDay: timeOfDay)
    }
}

public enum FollowUpCount: Int, Sendable, Equatable {
    case off = 0
    case two = 2
    case three = 3

    public static let storageKey = "perimedi.reminderFollowUps"

    public static func parsed(_ raw: Int?) -> FollowUpCount {
        guard let raw, let count = FollowUpCount(rawValue: raw) else { return .off }
        return count
    }
}

public struct ReminderChainStop: Hashable, Codable, Sendable {
    public var scheduleId: String
    public var date: String
    public var timeOfDay: String

    public init(scheduleId: String, date: String, timeOfDay: String) {
        self.scheduleId = scheduleId
        self.date = date
        self.timeOfDay = timeOfDay
    }
}

public struct FollowUpRequest: Equatable, Sendable {
    public var id: String
    public var fireAt: Date
    public var medicationId: String
    public var scheduleId: String
    public var date: String
    public var timeOfDay: String
    public var medicationName: String
    public var doseLabel: String

    public init(
        id: String,
        fireAt: Date,
        medicationId: String,
        scheduleId: String,
        date: String,
        timeOfDay: String,
        medicationName: String,
        doseLabel: String
    ) {
        self.id = id
        self.fireAt = fireAt
        self.medicationId = medicationId
        self.scheduleId = scheduleId
        self.date = date
        self.timeOfDay = timeOfDay
        self.medicationName = medicationName
        self.doseLabel = doseLabel
    }
}

public struct FollowUpPlan: Equatable, Sendable {
    public var doses: [ReminderSlot]
    public var followUps: [FollowUpRequest]
    public var stops: Set<ReminderChainStop>

    public init(doses: [ReminderSlot], followUps: [FollowUpRequest], stops: Set<ReminderChainStop>) {
        self.doses = doses
        self.followUps = followUps
        self.stops = stops
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
    private static let chainedSlotCap = 4

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

    public static func followUpPlan(
        now: Date,
        count: FollowUpCount,
        stops: Set<ReminderChainStop>,
        medications: [Medication],
        schedules: [Schedule],
        doseLogs: [DoseLog],
        periods: [Period],
        settings: CycleSettings,
        horizonDays: Int = horizonDays
    ) -> FollowUpPlan {
        let doses = upcoming(
            now: now,
            medications: medications,
            schedules: schedules,
            doseLogs: doseLogs,
            periods: periods,
            settings: settings,
            horizonDays: horizonDays,
            limit: doseLimit(for: count)
        )
        let today = DateKeys.toDateKey(now)
        let to = DateKeys.addDaysKey(today, horizonDays)
        let pending = slots(
            from: today,
            to: to,
            medications: medications,
            schedules: schedules,
            doseLogs: doseLogs,
            periods: periods,
            settings: settings
        )
        let live = Set(pending.map {
            ReminderChainStop(scheduleId: $0.scheduleId, date: $0.date, timeOfDay: $0.timeOfDay)
        })
        let pruned = stops.intersection(live)
        guard count != .off else {
            return FollowUpPlan(doses: doses, followUps: [], stops: pruned)
        }
        let stepCount = count.rawValue
        let interval = TimeInterval(snoozeMinutes * 60)
        let eligible = pending
            .filter { slot in
                let stop = ReminderChainStop(
                    scheduleId: slot.scheduleId,
                    date: slot.date,
                    timeOfDay: slot.timeOfDay
                )
                guard !pruned.contains(stop) else { return false }
                return (1...stepCount).contains { step in
                    slot.fireAt.addingTimeInterval(interval * TimeInterval(step)) > now
                }
            }
            .sorted { lhs, rhs in
                if lhs.fireAt != rhs.fireAt { return lhs.fireAt < rhs.fireAt }
                if lhs.scheduleId != rhs.scheduleId { return lhs.scheduleId < rhs.scheduleId }
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                return lhs.timeOfDay < rhs.timeOfDay
            }
        var followUps: [FollowUpRequest] = []
        for slot in eligible.prefix(chainedSlotCap) {
            for step in 1...stepCount {
                let fireAt = slot.fireAt.addingTimeInterval(interval * TimeInterval(step))
                guard fireAt > now else { continue }
                followUps.append(
                    FollowUpRequest(
                        id: ReminderSlot.followUpId(
                            scheduleId: slot.scheduleId,
                            date: slot.date,
                            timeOfDay: slot.timeOfDay,
                            step: step
                        ),
                        fireAt: fireAt,
                        medicationId: slot.medicationId,
                        scheduleId: slot.scheduleId,
                        date: slot.date,
                        timeOfDay: slot.timeOfDay,
                        medicationName: slot.medicationName,
                        doseLabel: slot.doseLabel
                    )
                )
            }
        }
        return FollowUpPlan(doses: doses, followUps: followUps, stops: pruned)
    }

    private static func doseLimit(for count: FollowUpCount) -> Int {
        switch count {
        case .off:
            return maxPending
        case .two, .three:
            return maxPending - chainedSlotCap * count.rawValue
        }
    }

    /// Snooze ids for pending reminder slots in the horizon, including overdue times today.
    public static func pendingSnoozeIds(
        now: Date,
        medications: [Medication],
        schedules: [Schedule],
        doseLogs: [DoseLog],
        periods: [Period],
        settings: CycleSettings,
        horizonDays: Int = horizonDays
    ) -> Set<String> {
        let today = DateKeys.toDateKey(now)
        let to = DateKeys.addDaysKey(today, horizonDays)
        return Set(
            slots(
                from: today,
                to: to,
                medications: medications,
                schedules: schedules,
                doseLogs: doseLogs,
                periods: periods,
                settings: settings
            ).map(\.snoozeId)
        )
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
