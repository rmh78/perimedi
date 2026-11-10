import XCTest
@testable import PeriMedi

final class MedicationReminderNoticesTests: XCTestCase {
    func testAppOffAloneShowsTheAppNotice() {
        XCTAssertEqual(
            MedicationReminderNotices.notices(
                medicationRemindersOn: true,
                appRemindersOn: false,
                iosDenied: false
            ),
            [.appRemindersOff]
        )
    }

    func testDeniedShowsTheIOSNoticeOnly() {
        XCTAssertEqual(
            MedicationReminderNotices.notices(
                medicationRemindersOn: true,
                appRemindersOn: true,
                iosDenied: true
            ),
            [.notificationsDenied]
        )
    }

    func testNotDeterminedShowsNothing() {
        XCTAssertEqual(
            MedicationReminderNotices.notices(
                medicationRemindersOn: true,
                appRemindersOn: true,
                iosDenied: false
            ),
            []
        )
    }

    func testBothBlockedPutsTheAppLineFirst() {
        XCTAssertEqual(
            MedicationReminderNotices.notices(
                medicationRemindersOn: true,
                appRemindersOn: false,
                iosDenied: true
            ),
            [.appRemindersOff, .notificationsDenied]
        )
        XCTAssertEqual(
            MedicationReminderNotice.appRemindersOff.row,
            MedicationReminderNotice.Row(
                messageKey: "med.remind.appOff",
                actionKey: "med.remind.turnOn",
                messageID: "med.remind.appOff",
                actionID: "med.remind.turnOn"
            )
        )
        XCTAssertEqual(
            MedicationReminderNotice.notificationsDenied.row,
            MedicationReminderNotice.Row(
                messageKey: "med.remind.iosDenied",
                actionKey: "med.remind.iosSettings",
                messageID: "med.remind.iosDenied",
                actionID: "med.remind.iosSettings"
            )
        )
    }

    func testMedicationSwitchOffShowsNothing() {
        XCTAssertEqual(
            MedicationReminderNotices.notices(
                medicationRemindersOn: false,
                appRemindersOn: false,
                iosDenied: true
            ),
            []
        )
    }
}
