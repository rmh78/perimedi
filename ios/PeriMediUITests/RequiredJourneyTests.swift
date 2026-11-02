import XCTest

final class RequiredJourneyTests: PeriMediUITestCase {
    override func setUp() {
        super.setUp()
        executionTimeAllowance = 180
        HomeScreen.prepare()
    }

    override func tearDown() {
        HomeScreen().restoreIcon()
        SpringboardIdleBypass.restore()
        super.tearDown()
    }

    func testUserFlow() {
        UserFlow(robot: robot).run()
    }
}
