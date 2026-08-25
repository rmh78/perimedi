import XCTest
@testable import PeriMediDomain

final class CycleLogicTests: XCTestCase {
    let settings = CycleSettings(averageCycleLength: 28, averagePeriodLength: 5)

    func testWindowStartsAtMonthWhenNoPeriods() {
        let w = CycleLogic.cycleWindowForDate(dateKey: "2026-08-07", periods: [], settings: settings)
        XCTAssertEqual(w.start, "2026-08-01")
        XCTAssertEqual(w.length, 31)
        let days = (0..<w.length).map { DateKeys.addDaysKey(w.start, $0) }
        XCTAssertEqual(days.first, "2026-08-01")
        XCTAssertTrue(days.contains("2026-08-07"))
        XCTAssertEqual(days.last, "2026-08-31")
    }

    func testWindowIgnoresPeriodsWhenTrackingOff() {
        let off = CycleSettings(averageCycleLength: 28, averagePeriodLength: 5, tracksPeriods: false)
        let periods = [Period(id: "p1", startDate: "2026-07-10")]
        let w = CycleLogic.cycleWindowForDate(dateKey: "2026-08-19", periods: periods, settings: off)
        XCTAssertEqual(w.start, "2026-08-01")
        XCTAssertEqual(w.length, 31)
        XCTAssertNil(CycleLogic.getDayCycleInfo(dateKey: "2026-07-10", periods: periods, settings: off).cycleDay)
        XCTAssertNil(CycleLogic.nextPredictedPeriodStart(periods: periods, settings: off))
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

    func testLookupMatchesOriginalDayInfoAcrossRange() {
        let periods = [
            Period(id: "p1", startDate: "2026-06-01", endDate: "2026-06-06"),
            Period(id: "p2", startDate: "2026-06-29", endDate: "2026-07-03"),
            Period(id: "p3", startDate: "2026-07-26", endDate: "2026-07-30"),
        ]
        let lookup = CycleLogic.dayCycleLookup(periods: periods, settings: settings)
        for offset in 0..<120 {
            let key = DateKeys.addDaysKey("2026-05-20", offset)
            XCTAssertEqual(
                lookup.info(dateKey: key),
                originalDayCycleInfo(dateKey: key, periods: periods, settings: settings),
                key
            )
        }
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

    /// Reference copy of the previous per-day walk, used to lock lookup output.
    private func originalDayCycleInfo(
        dateKey: String,
        periods: [Period],
        settings: CycleSettings
    ) -> DayCycleInfo {
        let isLoggedPeriod = periods.contains {
            CycleLogic.periodCoversDate($0, dateKey: dateKey, defaultPeriodLength: settings.averagePeriodLength)
        }
        let cycleDay = CycleLogic.getCycleDay(dateKey: dateKey, periods: periods)
        var isPredictedPeriod = false

        if let lastStart = CycleLogic.lastPeriodStart(periods), let lastDate = DateKeys.parseDateKey(lastStart) {
            let cycleLen = max(2, settings.averageCycleLength)
            let periodLen = max(1, settings.averagePeriodLength)
            let horizon = DateKeys.addDaysKey(dateKey, cycleLen * 3)
            var cycleStart = lastDate
            for i in 0..<24 {
                let cs = DateKeys.toDateKey(cycleStart)
                if cs > horizon { break }
                if i > 0 {
                    let pe = DateKeys.toDateKey(DateKeys.addDays(cycleStart, periodLen - 1))
                    if dateKey >= cs && dateKey <= pe {
                        isPredictedPeriod = true
                    }
                }
                cycleStart = DateKeys.addDays(cycleStart, cycleLen)
            }
        }

        if isLoggedPeriod {
            isPredictedPeriod = false
        }

        return DayCycleInfo(
            date: dateKey,
            isLoggedPeriod: isLoggedPeriod,
            isPredictedPeriod: isPredictedPeriod,
            cycleDay: cycleDay
        )
    }
}
