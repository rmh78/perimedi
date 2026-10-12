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
}
