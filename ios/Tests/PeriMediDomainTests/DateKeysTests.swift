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

    func testDayOfMonth() {
        XCTAssertEqual(DateKeys.dayOfMonth("2026-03-15"), 15)
        XCTAssertEqual(DateKeys.dayOfMonth("2026-03-01"), 1)
        XCTAssertEqual(DateKeys.dayOfMonth("2026-03-15T08:30:00"), 15)
        XCTAssertNil(DateKeys.dayOfMonth("not-a-date"))
    }

    func testStartOfMonthAndDaysInMonth() {
        XCTAssertEqual(DateKeys.startOfMonthKey("2026-08-19"), "2026-08-01")
        XCTAssertEqual(DateKeys.daysInMonth("2026-08-19"), 31)
        XCTAssertEqual(DateKeys.daysInMonth("2026-02-10"), 28)
    }

    func testTimeOfDayRoundTrip() {
        let morning = DateKeys.parseTimeOfDay("7:30")
        XCTAssertEqual(DateKeys.formatTimeOfDay(morning), "07:30")
        let evening = DateKeys.parseTimeOfDay("20:00")
        XCTAssertEqual(DateKeys.formatTimeOfDay(evening), "20:00")
    }
}
