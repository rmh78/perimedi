import XCTest

final class MedicationReminderHonestyTests: PeriMediUITestCase {
    func testTurnOnKeepsTheDraftAndEnablesAppReminders() {
        robot.launch(arguments: ["-en", "-clear", "-uiTesting", "-today=\(UITestDate.deviceToday)"])
        turnAppRemindersOff()

        robot.tap("tab.cycle")
        robot.tap("cycle.action.med")
        robot.waitFor(id: "sheet.med")
        robot.clearAndType("med.name", "Estradiol")
        robot.clearAndType("med.dose", "1 mg")
        let addTime = robot.app.buttons["+ Another dose time"]
        XCTAssertTrue(addTime.waitForExistence(timeout: 4))
        addTime.tap()

        XCTAssertEqual(robot.element("med.remind.appOff").label, "App reminders are off.")
        robot.waitFor(id: "med.remind.turnOn")
        XCTAssertEqual(robot.element("med.remind.turnOn").label, "Turn on")
        XCTAssertFalse(robot.exists("med.remind.iosDenied"))
        XCTAssertTrue(robot.app.buttons["20:00"].exists)
        XCTAssertTrue(robot.app.buttons["08:00"].exists)

        tapTurnOnAboveCancel()

        robot.waitFor(id: "sheet.med")
        robot.waitGone(id: "med.remind.appOff")
        XCTAssertEqual(robot.element("med.name").value as? String, "Estradiol")
        XCTAssertEqual(robot.element("med.dose").value as? String, "1 mg")
        XCTAssertTrue(robot.app.buttons["20:00"].exists)
        XCTAssertTrue(robot.app.buttons["08:00"].exists)
        XCTAssertFalse(robot.exists("med.remind.iosDenied"))

        let cancel = robot.app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 4))
        cancel.tap()
        robot.waitGone(id: "sheet.med")
        robot.tap("tab.more")
        robot.waitFor(id: "more.reminders")
        XCTAssertTrue(switchIsOn("more.reminders"))
    }

    /// A second take time lays Turn on across the pinned Cancel button.
    /// scrollTo does not move it. The sheet placement inset is 24pt, so that
    /// overlap still counts as on screen, and a center tap presses Cancel.
    private func tapTurnOnAboveCancel() {
        let turnOn = robot.app.buttons["med.remind.turnOn"]
        let cancel = robot.app.buttons["Cancel"]
        XCTAssertTrue(turnOn.waitForExistence(timeout: 4))
        XCTAssertTrue(cancel.waitForExistence(timeout: 4))
        for _ in 0..<4 where turnOn.frame.midY >= cancel.frame.minY - 12 {
            let start = robot.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.58))
            let end = robot.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.40))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertLessThan(
            turnOn.frame.midY,
            cancel.frame.minY,
            "turn on \(turnOn.frame) overlaps cancel \(cancel.frame)"
        )
        robot.tap("med.remind.turnOn")
    }

    private func turnAppRemindersOff() {
        robot.tap("tab.more")
        robot.waitFor(id: "more.reminders")
        robot.tap("more.reminders")
        XCTAssertFalse(switchIsOn("more.reminders"), "more.reminders \(String(describing: robot.app.switches["more.reminders"].value))")
    }

    private func switchIsOn(_ id: String) -> Bool {
        let value = robot.app.switches[id].value
        return (value as? String) == "1" || (value as? NSNumber)?.intValue == 1
    }
}
