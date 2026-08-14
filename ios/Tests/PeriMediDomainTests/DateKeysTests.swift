import XCTest
@testable import PeriMediDomain

final class DateKeysTests: XCTestCase {
    override func tearDown() {
        DateKeys.pinnedTodayKey = nil
        super.tearDown()
    }

    func testTodayKeyUsesDeviceClockWhenUnpinned() {
        XCTAssertNil(DateKeys.pinnedTodayKey)
        let expected = DateKeys.toDateKey(Date())
        XCTAssertEqual(DateKeys.todayKey(), expected)
    }

    func testPinnedTodayOverridesClock() {
        DateKeys.pinnedTodayKey = "2026-03-15"
        XCTAssertEqual(DateKeys.todayKey(), "2026-03-15")
        XCTAssertEqual(DateKeys.todayKey(Date()), "2026-03-15")
        XCTAssertEqual(DateKeys.addDaysKey(DateKeys.todayKey(), -8), "2026-03-07")
    }

    func testToDateKeyPassesThroughISODatePrefix() {
        XCTAssertEqual(DateKeys.toDateKey("2026-03-15"), "2026-03-15")
        XCTAssertEqual(DateKeys.toDateKey("2026-03-15T08:30:00"), "2026-03-15")
    }
}
