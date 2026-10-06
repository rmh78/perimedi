import XCTest

final class PeriodHistoryTests: PeriMediUITestCase {
    func testEditAndDeletePeriod() {
        robot.launch()
        robot.addPeriod()

        robot.tap("cycle.action.period")
        robot.waitFor(id: "sheet.period")
        let created = revealHistory()
        created.tap()

        let start = robot.element("period.start")
        let startShown = ((start.value as? String) ?? "") + start.label
        XCTAssertTrue(startShown.contains("2026-03-07"), startShown)
        XCTAssertTrue(robot.exists("period.delete"))
        robot.setDateKey("period.end", "2026-03-12")
        robot.tap("period.save")

        let edited = revealHistory()
        XCTAssertEqual(edited.label, "7–12 Mar 2026")

        robot.closeSheet(id: "sheet.period")
        robot.setLanguage("de")
        robot.tap("tab.cycle")
        robot.tap("cycle.action.period")
        robot.waitFor(id: "sheet.period")
        let german = revealHistory()
        XCTAssertEqual(german.label, "7.–12. März 2026")

        robot.tap("period.add")
        XCTAssertEqual(robot.element("period.end").label, "TT.MM.JJJJ")
        let cancel = robot.app.buttons["Abbrechen"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 2))
        cancel.tap()
        robot.waitGone(id: "period.end")

        revealHistory().tap()
        let germanStart = robot.element("period.start")
        XCTAssertEqual(germanStart.label, "07.03.2026")
        XCTAssertTrue(((germanStart.value as? String) ?? "").contains("2026-03-07"))
        XCTAssertEqual(robot.element("period.end").label, "12.03.2026")

        robot.tap("period.delete")
        let question = "7.–12. März 2026 löschen?"
        XCTAssertTrue(robot.app.staticTexts[question].waitForExistence(timeout: 2))
        robot.tap("confirm.delete")

        let leftover = robot.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "period.history.")
        )
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline, leftover.count > 0 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertEqual(leftover.count, 0)

        robot.closeSheet(id: "sheet.period")
        robot.waitFor(id: "cycle.intro")
        robot.waitFor(id: "cycle.empty.meds")
        XCTAssertTrue(robot.value(of: "cycle.empty.meds").contains("need-period"))
        XCTAssertFalse(robot.exists("cycle.strip.day.2026-03-07"))
    }

    private func revealHistory() -> XCUIElement {
        var row = historyRow()
        for _ in 0..<8 {
            if row.exists, row.isHittable { return row }
            robot.app.swipeUp()
            row = historyRow()
        }
        XCTAssertTrue(row.waitForExistence(timeout: 2))
        return row
    }

    private func historyRow() -> XCUIElement {
        robot.app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "period.history.")
        ).firstMatch
    }
}
