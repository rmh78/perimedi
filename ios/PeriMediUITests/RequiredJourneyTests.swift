import XCTest

final class RequiredJourneyTests: PeriMediUITestCase {
    override func setUp() {
        super.setUp()
        executionTimeAllowance = 900
        if name.contains("testEnglishWidgetJourney") {
            WidgetShell.prepare()
        }
    }

    override func tearDown() {
        if name.contains("testEnglishWidgetJourney") {
            WidgetShell.finish()
        }
        super.tearDown()
    }

    func testEnglishAppJourney() {
        executionTimeAllowance = 900
        AppProof(robot: robot).run()
    }

    func testEnglishWidgetJourney() {
        executionTimeAllowance = 900
        WidgetProof(robot: robot).run()
    }

    func testPeriodCardAtLargestText() {
        let hintByLanguage = [
            "-en": "Leave empty if still ongoing",
            "-de": "Leer lassen, wenn noch andauernd",
        ]
        for language in ["-en", "-de"] {
            robot.launch(arguments: [
                "-uiTesting",
                "-clear",
                "-today=2026-03-15",
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL",
                language,
            ])
            robot.tap("cycle.action.period")
            robot.waitFor(id: "sheet.period")
            robot.scrollTo("period.add")
            robot.tap("period.add")
            robot.waitFor(id: "period.start")
            robot.setDateKey("period.start", "2026-03-07")
            robot.setDateKey("period.end", "2026-03-11")
            let start = robot.element("period.start").frame
            let end = robot.element("period.end").frame
            XCTAssertGreaterThanOrEqual(end.minY, start.maxY - 1)
            let window = robot.app.windows.firstMatch.frame
            for frame in [start, end] {
                XCTAssertGreaterThanOrEqual(frame.minX, window.minX - 1)
                XCTAssertGreaterThanOrEqual(frame.minY, window.minY - 1)
                XCTAssertLessThanOrEqual(frame.maxX, window.maxX + 1)
                XCTAssertLessThanOrEqual(frame.maxY, window.maxY + 1)
            }
            let hint = hintByLanguage[language] ?? ""
            let hintText = robot.app.staticTexts[hint]
            XCTAssertTrue(hintText.waitForExistence(timeout: 2), hint)
            XCTAssertEqual(hintText.label, hint)
            XCTAssertGreaterThan(hintText.frame.height, 40, hint)
            XCTAssertGreaterThanOrEqual(hintText.frame.minX, window.minX - 1)
            XCTAssertGreaterThanOrEqual(hintText.frame.minY, window.minY - 1)
            XCTAssertLessThanOrEqual(hintText.frame.maxX, window.maxX + 1)
            XCTAssertLessThanOrEqual(hintText.frame.maxY, window.maxY + 1)
        }
    }
}
