import XCTest
@testable import PeriMediDomain

final class CycleLogicTests: XCTestCase {
    let settings = CycleSettings(averageCycleLength: 28, averagePeriodLength: 5)

    func testWindowStartsAtSelectedDateWhenNoPeriods() {
        let w = CycleLogic.cycleWindowForDate(dateKey: "2026-08-07", periods: [], settings: settings)
        XCTAssertEqual(w.start, "2026-08-07")
        XCTAssertGreaterThanOrEqual(w.length, 28)
    }

    func testWindowUsesPeriodStartOnOrBefore() {
        let periods = [Period(id: "p1", startDate: "2026-07-10")]
        let w = CycleLogic.cycleWindowForDate(dateKey: "2026-07-20", periods: periods, settings: settings)
        XCTAssertEqual(w.start, "2026-07-10")
        XCTAssertEqual(w.length, 28)
    }

    func testWindowExtendsForLateSelectedDay() {
        let periods = [Period(id: "p1", startDate: "2026-06-01")]
        let w = CycleLogic.cycleWindowForDate(dateKey: "2026-07-20", periods: periods, settings: settings)
        XCTAssertEqual(w.start, "2026-06-01")
        XCTAssertGreaterThan(w.length, 28)
        XCTAssertLessThanOrEqual(w.length, 90)
    }

    func testCycleDay1OnPeriodStart() {
        let periods = [Period(id: "p1", startDate: "2026-07-10", endDate: "2026-07-14")]
        XCTAssertEqual(CycleLogic.getCycleDay(dateKey: "2026-07-10", periods: periods), 1)
    }

    func testLoggedPeriodNotPredicted() {
        let periods = [Period(id: "p1", startDate: "2026-07-10", endDate: "2026-07-14")]
        let info = CycleLogic.getDayCycleInfo(dateKey: "2026-07-12", periods: periods, settings: settings)
        XCTAssertTrue(info.isLoggedPeriod)
        XCTAssertFalse(info.isPredictedPeriod)
        XCTAssertEqual(info.cycleDay, 3)
    }

    func testPredictsNextPeriod() {
        let periods = [Period(id: "p1", startDate: "2026-07-10", endDate: "2026-07-14")]
        XCTAssertEqual(CycleLogic.nextPredictedPeriodStart(periods: periods, settings: settings), "2026-08-07")
        let info = CycleLogic.getDayCycleInfo(dateKey: "2026-08-07", periods: periods, settings: settings)
        XCTAssertTrue(info.isPredictedPeriod)
        XCTAssertFalse(info.isLoggedPeriod)
    }

    func testPeriodLengthInclusive() {
        XCTAssertEqual(
            CycleLogic.periodLengthDays(Period(id: "p", startDate: "2026-07-10", endDate: "2026-07-14"), defaultLen: 5),
            5
        )
        XCTAssertEqual(
            CycleLogic.periodLengthDays(Period(id: "p", startDate: "2026-07-10"), defaultLen: 6),
            6
        )
    }
}
