import XCTest

final class RequiredJourneyTests: PeriMediUITestCase {
    override func setUp() {
        super.setUp()
        executionTimeAllowance = name.contains("testEnglishSmoke") ? 120 : 900
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

    func testEnglishSmoke() {
        executionTimeAllowance = 120
        robot.launch(.widgetToday)
        let alert = robot.app.alerts.firstMatch
        if alert.waitForExistence(timeout: 2) {
            alert.buttons.firstMatch.tap()
        }
        robot.waitFor(id: "tab.cycle")
        robot.waitFor(id: "cycle.action.med")
        robot.waitFor(id: "cycle.empty.meds")
        XCTAssertTrue(robot.value(of: "cycle.empty.meds").contains("need-med"))
        robot.addMedication(name: "Estrogen", dose: "1 mg")
        robot.waitFor(id: "cycle.lane.estrogen")
    }
}
