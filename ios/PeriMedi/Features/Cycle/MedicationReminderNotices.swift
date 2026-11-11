import Foundation

enum MedicationReminderNotice: Equatable, Hashable, Sendable {
    case appRemindersOff
    case notificationsDenied

    struct Row: Equatable, Sendable {
        let messageKey: String
        let actionKey: String
        let messageID: String
        let actionID: String
    }

    var row: Row {
        switch self {
        case .appRemindersOff:
            Row(
                messageKey: "med.remind.appOff",
                actionKey: "med.remind.turnOn",
                messageID: A11yID.medRemindAppOff,
                actionID: A11yID.medRemindTurnOn
            )
        case .notificationsDenied:
            Row(
                messageKey: "med.remind.iosDenied",
                actionKey: "med.remind.iosSettings",
                messageID: A11yID.medRemindIosDenied,
                actionID: A11yID.medRemindIosSettings
            )
        }
    }
}

enum MedicationReminderNotices {
    static func notices(
        medicationRemindersOn: Bool,
        appRemindersOn: Bool,
        iosDenied: Bool
    ) -> [MedicationReminderNotice] {
        guard medicationRemindersOn else { return [] }
        var notices: [MedicationReminderNotice] = []
        if !appRemindersOn {
            notices.append(.appRemindersOff)
        }
        if iosDenied {
            notices.append(.notificationsDenied)
        }
        return notices
    }
}
