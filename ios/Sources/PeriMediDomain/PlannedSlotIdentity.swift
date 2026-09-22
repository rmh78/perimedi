import Foundation

public struct PlannedSlotIdentity: Hashable, Codable, Sendable {
    public var medicationId: String
    public var scheduleId: String
    public var date: String
    public var timeOfDay: String

    public init(medicationId: String, scheduleId: String, date: String, timeOfDay: String) {
        self.medicationId = medicationId
        self.scheduleId = scheduleId
        self.date = date
        self.timeOfDay = timeOfDay
    }
}

extension PlannedDose {
    public var identity: PlannedSlotIdentity {
        PlannedSlotIdentity(
            medicationId: medication.id,
            scheduleId: schedule.id,
            date: date,
            timeOfDay: timeOfDay
        )
    }
}

extension ReminderSlot {
    public var identity: PlannedSlotIdentity {
        PlannedSlotIdentity(
            medicationId: medicationId,
            scheduleId: scheduleId,
            date: date,
            timeOfDay: timeOfDay
        )
    }
}
