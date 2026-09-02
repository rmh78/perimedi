import XCTest
@testable import PeriMediDomain

final class EffectLogicTests: XCTestCase {
    private let settings = CycleSettings(averageCycleLength: 28, averagePeriodLength: 5)
    private let today = "2026-03-15"
    private let previousStart = "2026-02-01"
    private let currentStart = "2026-03-05"

    private var twoCycles: [Period] {
        [
            Period(id: "p0", startDate: previousStart, endDate: "2026-02-05"),
            Period(id: "p1", startDate: currentStart, endDate: "2026-03-09"),
        ]
    }

    private func score(_ id: SymptomId, date: String, severity: Int) -> SymptomScore {
        SymptomScore(id: id.rawValue, date: date, severity: severity, loggedAt: "t")
    }

    private func change(
        field: MedicationChangeField = .dose,
        effective: String,
        name: String = "Estrogel",
        newValue: String = "2 pumps"
    ) -> MedicationChange {
        MedicationChange(
            id: createId(),
            medicationId: "m1",
            nameSnapshot: name,
            field: field,
            previousValue: "1 pump",
            newValue: newValue,
            effectiveDate: effective,
            loggedAt: "t"
        )
    }

    func testNoPeriodHistoryIsHidden() {
        let result = EffectLogic.summarize(
            today: today,
            periods: [],
            settings: settings,
            scores: [],
            changes: []
        )
        XCTAssertEqual(result.kind, .hidden)
    }

    func testTrackingOffIsHidden() {
        var off = settings
        off.tracksPeriods = false
        let result = EffectLogic.summarize(
            today: today,
            periods: twoCycles,
            settings: off,
            scores: [
                score(.hot_flash, date: "2026-03-06", severity: 3),
                score(.hot_flash, date: "2026-02-02", severity: 1),
            ],
            changes: []
        )
        XCTAssertEqual(result.kind, .hidden)
    }

    func testOnlyOneCycle() {
        let result = EffectLogic.summarize(
            today: today,
            periods: [Period(id: "p1", startDate: currentStart)],
            settings: settings,
            scores: [score(.hot_flash, date: today, severity: 3)],
            changes: []
        )
        XCTAssertEqual(result.kind, .noPreviousCycle)
    }

    func testNotEnoughOverlappingScores() {
        let result = EffectLogic.summarize(
            today: today,
            periods: twoCycles,
            settings: settings,
            scores: [score(.hot_flash, date: "2026-03-06", severity: 3)],
            changes: []
        )
        XCTAssertEqual(result.kind, .notEnoughDays)
        XCTAssertNil(result.context)
    }

    func testRollingWeekIsNotTheWindow() {
        // Last 7 calendar days are all current-cycle; previous-cycle scores sit on
        // unmatched cycle days (day 20 of the previous cycle, outside days 1–11).
        let scores = [
            score(.hot_flash, date: "2026-03-10", severity: 4),
            score(.hot_flash, date: "2026-03-12", severity: 4),
            score(.hot_flash, date: "2026-02-20", severity: 1),
        ]
        let result = EffectLogic.summarize(
            today: today,
            periods: twoCycles,
            settings: settings,
            scores: scores,
            changes: []
        )
        XCTAssertEqual(result.kind, .notEnoughDays)
    }

    func testSameCycleDaysComparison() {
        // Today is cycle day 11 (Mar 5 → Mar 15). Compare days 1–11 vs previous 1–11.
        let scores = [
            score(.hot_flash, date: "2026-03-06", severity: 2),
            score(.hot_flash, date: "2026-03-10", severity: 2),
            score(.hot_flash, date: "2026-02-02", severity: 4),
            score(.hot_flash, date: "2026-02-08", severity: 4),
            score(.sleep, date: "2026-03-07", severity: 4),
            score(.sleep, date: "2026-03-11", severity: 3),
            score(.sleep, date: "2026-02-03", severity: 1),
            score(.sleep, date: "2026-02-09", severity: 1),
        ]
        let result = EffectLogic.summarize(
            today: today,
            periods: twoCycles,
            settings: settings,
            scores: scores,
            changes: []
        )
        guard case .changed(let shifts) = result.kind else {
            return XCTFail("expected changed, got \(result.kind)")
        }
        XCTAssertEqual(shifts.map(\.id), ["hot_flash", "sleep"])
        XCTAssertEqual(shifts[0].direction, .improved)
        XCTAssertEqual(shifts[1].direction, .worse)
        XCTAssertNil(result.context)
    }

    func testSimilarScores() {
        let scores = [
            score(.hot_flash, date: "2026-03-06", severity: 2),
            score(.hot_flash, date: "2026-02-02", severity: 2),
        ]
        let result = EffectLogic.summarize(
            today: today,
            periods: twoCycles,
            settings: settings,
            scores: scores,
            changes: []
        )
        XCTAssertEqual(result.kind, .similar)
    }

    func testDoseChangeInThisCycleIsContext() {
        let scores = [
            score(.hot_flash, date: "2026-03-06", severity: 2),
            score(.hot_flash, date: "2026-02-02", severity: 4),
        ]
        let result = EffectLogic.summarize(
            today: today,
            periods: twoCycles,
            settings: settings,
            scores: scores,
            changes: [change(effective: "2026-03-08")]
        )
        guard case .changed = result.kind else {
            return XCTFail("expected changed")
        }
        XCTAssertEqual(result.context?.nameSnapshot, "Estrogel")
        XCTAssertEqual(result.context?.field, .dose)
        XCTAssertEqual(result.context?.newValue, "2 pumps")
    }

    func testChangeOutsideTwoCyclesIsIgnored() {
        let scores = [
            score(.hot_flash, date: "2026-03-06", severity: 2),
            score(.hot_flash, date: "2026-02-02", severity: 4),
        ]
        let result = EffectLogic.summarize(
            today: today,
            periods: twoCycles,
            settings: settings,
            scores: scores,
            changes: [change(effective: "2026-01-15")]
        )
        XCTAssertNil(result.context)
    }

    func testPrefersDoseContextOverSchedule() {
        let scores = [
            score(.hot_flash, date: "2026-03-06", severity: 2),
            score(.hot_flash, date: "2026-02-02", severity: 4),
        ]
        let result = EffectLogic.summarize(
            today: today,
            periods: twoCycles,
            settings: settings,
            scores: scores,
            changes: [
                change(field: .schedule, effective: "2026-03-10", newValue: "every day @ 20:00"),
                change(field: .dose, effective: "2026-03-06"),
            ]
        )
        XCTAssertEqual(result.context?.field, .dose)
    }

    func testSampleYieldsSentenceAndDoseContext() {
        let sample = SampleData.payload(now: DateKeys.parseDateKey(today)!)
        let result = EffectLogic.summarize(
            today: today,
            periods: sample.periods,
            settings: sample.cycleSettings,
            scores: sample.symptomScores,
            changes: sample.medicationChanges
        )
        guard case .changed(let shifts) = result.kind else {
            return XCTFail("expected changed, got \(result.kind)")
        }
        XCTAssertTrue(shifts.contains { $0.id == "hot_flash" && $0.direction == .improved })
        XCTAssertTrue(shifts.contains { $0.id == "sleep" && $0.direction == .worse })
        XCTAssertEqual(result.context?.nameSnapshot, "Estradiol gel")
        XCTAssertEqual(result.context?.field, .dose)
    }
}
