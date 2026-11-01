import XCTest

final class RequiredJourneyTests: PeriMediUITestCase {
    override func setUp() {
        super.setUp()
        let smoke = name.contains("testEnglishSmoke")
        executionTimeAllowance = smoke ? 360 : 900
        if smoke || name.contains("testEnglishWidgetJourney") {
            WidgetShell.prepare()
        }
    }

    override func tearDown() {
        if name.contains("testEnglishSmoke") || name.contains("testEnglishWidgetJourney") {
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
        executionTimeAllowance = 360
        robot.launch(.widgetToday)
        let alert = robot.app.alerts.firstMatch
        if alert.waitForExistence(timeout: 2) {
            alert.buttons.firstMatch.tap()
        }
        robot.waitFor(id: "tab.cycle")
        robot.waitFor(id: "cycle.action.med")
        robot.waitFor(id: "cycle.empty.meds")
        XCTAssertTrue(robot.value(of: "cycle.empty.meds").contains("need-med"))
        let home = HomeWidgets()
        home.show(.medium)
        XCTAssertTrue(
            home.spin(8) { home.hasWidget },
            "icon did not become a widget. icons: \(home.iconLabels) buttons: \(home.buttonLabels)"
        )
        robot.app.activate()
        robot.addMedication(name: "Estrogen", dose: "1 mg")
        robot.waitFor(id: "cycle.lane.estrogen")
        home.open()
        XCTAssertTrue(
            home.spin(20) { home.hasMed("Estrogen") && home.hasTake },
            "widget row or Take missing. buttons: \(home.buttonLabels)"
        )
        home.tapTaken(beside: "Estrogen")
        if !home.spin(1) { home.hasCheck } {
            WidgetShell.restart()
            home.open()
            XCTAssertTrue(
                home.spin(8) { home.hasCheck },
                "check missing after one SpringBoard restart"
            )
        }
    }
}
