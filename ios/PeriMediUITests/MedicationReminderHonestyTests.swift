import XCTest

final class MedicationReminderHonestyTests: PeriMediUITestCase {
    func testAppRemindersOffShowsTheLineAndOpensMore() {
        robot.launch(arguments: ["-en", "-clear", "-uiTesting", "-today=\(UITestDate.deviceToday)"])
        robot.tap("tab.more")
        robot.waitFor(id: "more.reminders")
        robot.tap("more.reminders")
        let offValue = robot.app.switches["more.reminders"].value
        let off = (offValue as? String) == "0" || (offValue as? NSNumber)?.intValue == 0
        XCTAssertTrue(off, "more.reminders \(String(describing: offValue))")

        robot.tap("tab.cycle")
        robot.tap("cycle.action.med")
        robot.waitFor(id: "sheet.med")
        robot.scrollTo("med.remind.appOff")
        XCTAssertEqual(robot.element("med.remind.appOff").label, "Reminders are off for the app.")
        robot.waitFor(id: "med.remind.turnOn")
        XCTAssertEqual(robot.element("med.remind.turnOn").label, "Turn on")
        XCTAssertFalse(robot.exists("med.remind.iosDenied"))

        robot.tap("med.remind.turnOn")
        robot.waitGone(id: "sheet.med")
        robot.waitFor(id: "more.reminders")
        let stillValue = robot.app.switches["more.reminders"].value
        let stillOff = (stillValue as? String) == "0" || (stillValue as? NSNumber)?.intValue == 0
        XCTAssertTrue(stillOff, "more.reminders \(String(describing: stillValue))")
    }
}
