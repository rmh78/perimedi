import XCTest
@testable import PeriMediDomain

final class SymptomTrendLogicTests: XCTestCase {
    private let settings = CycleSettings(averageCycleLength: 28, averagePeriodLength: 5)
    private let today = TrendsFixture.today

    private func chart(
        periods: [Period]? = nil,
        scores: [SymptomScore]? = nil,
        changes: [MedicationChange]? = nil,
        selectedIds: [String]? = nil,
        settings: CycleSettings? = nil
    ) -> SymptomTrendChart? {
        let payload = TrendsFixture.payload()
        let result = SymptomTrendLogic.summarize(
            today: today,
            periods: periods ?? payload.periods,
            settings: settings ?? self.settings,
            scores: scores ?? payload.symptomScores,
            changes: changes ?? payload.medicationChanges,
            selectedIds: selectedIds
        )
        guard case .chart(let chart) = result.kind else { return nil }
        return chart
    }

    func testNoPeriodHistoryNeedsCycles() {
        let result = SymptomTrendLogic.summarize(
            today: today,
            periods: [],
            settings: settings,
            scores: [],
            changes: []
        )
        XCTAssertEqual(result.kind, .needCycles)
    }

    func testTrackingOffIsHidden() {
        var off = settings
        off.tracksPeriods = false
        let result = SymptomTrendLogic.summarize(
            today: today,
            periods: TrendsFixture.payload().periods,
            settings: off,
            scores: TrendsFixture.payload().symptomScores,
            changes: []
        )
        XCTAssertEqual(result.kind, .hidden)
    }

    func testNoScoresInLoggedCycles() {
        let result = SymptomTrendLogic.summarize(
            today: today,
            periods: [Period(id: "p1", startDate: "2026-03-01", endDate: "2026-03-05")],
            settings: settings,
            scores: [],
            changes: []
        )
        XCTAssertEqual(result.kind, .noScores)
    }

    func testPredictedStartsDoNotSplitCycles() {
        let periods = [
            Period(id: "p0", startDate: "2026-02-01"),
            Period(id: "p1", startDate: "2026-03-01"),
        ]
        let windows = CycleLogic.loggedCycleWindows(periods: periods, today: today)
        XCTAssertEqual(windows.map(\.start), ["2026-02-01", "2026-03-01"])
        XCTAssertEqual(windows[0].end, "2026-02-28")
        XCTAssertEqual(windows[1].end, today)
    }

    func testEmptyCycleWithoutScoresIsOmittedFromX() {
        let chart = chart()
        XCTAssertEqual(chart?.cycles.map(\.start), [
            TrendsFixture.cycleA,
            TrendsFixture.cycleB,
            TrendsFixture.cycleC,
        ])
        XCTAssertFalse(chart?.cycles.contains { $0.start == TrendsFixture.emptyStart } ?? true)
    }

    func testYIsDaysScoredAndSizeIsMean() {
        let chart = chart()
        let flash = chart?.series.first { $0.id == "hot_flash" }
        let a = flash?.points.first { $0.cycleStart == TrendsFixture.cycleA }
        let b = flash?.points.first { $0.cycleStart == TrendsFixture.cycleB }
        XCTAssertEqual(a?.dayCount, 8)
        XCTAssertEqual(a?.meanIntensity ?? 0, 1, accuracy: 0.01)
        XCTAssertEqual(b?.dayCount, 2)
        XCTAssertEqual(b?.meanIntensity ?? 0, 4, accuracy: 0.01)
        XCTAssertGreaterThan(a?.dayCount ?? 0, b?.dayCount ?? 99)
        XCTAssertLessThan(a?.meanIntensity ?? 99, b?.meanIntensity ?? 0)
    }

    func testHotFlashDoesNotUseEpisodeCount() {
        let chart = chart()
        let a = chart?.series.first { $0.id == "hot_flash" }?
            .points.first { $0.cycleStart == TrendsFixture.cycleA }
        XCTAssertEqual(a?.dayCount, 8)
        XCTAssertNotEqual(a?.dayCount, 99)
    }

    func testGapIsNotAZero() {
        let chart = chart()
        let sleep = chart?.series.first { $0.id == "sleep" }
        XCTAssertNil(sleep?.points.first { $0.cycleStart == TrendsFixture.cycleA })
        XCTAssertEqual(sleep?.points.first { $0.cycleStart == TrendsFixture.cycleB }?.dayCount, 4)
        XCTAssertFalse(sleep?.points.contains { $0.dayCount == 0 } ?? true)
    }

    func testDefaultThreeAreMostLoggedDaysNotHighestMean() {
        let chart = chart()
        XCTAssertEqual(chart?.defaultIds, ["hot_flash", "mood", "sleep"])
        XCTAssertEqual(chart?.series.map(\.id), ["hot_flash", "sleep", "mood"])
        XCTAssertFalse(chart?.series.contains { $0.id == "joints" } ?? true)
        XCTAssertFalse(chart?.series.contains { $0.id == "anxiety" } ?? true)
    }

    func testExplicitSelectionReplacesDefaults() {
        let chart = chart(selectedIds: ["hot_flash", "mood", "anxiety"])
        XCTAssertEqual(chart?.defaultIds, ["hot_flash", "mood", "sleep"])
        XCTAssertEqual(chart?.series.map(\.id), ["hot_flash", "mood", "anxiety"])
        XCTAssertFalse(chart?.series.contains { $0.id == "sleep" } ?? true)
    }

    func testToggleSelectsAndDeselects() {
        let ranked = ["hot_flash", "mood", "sleep"]
        XCTAssertEqual(
            SymptomTrendLogic.toggling("sleep", in: ranked, ranked: ranked),
            ["hot_flash", "mood"]
        )
        XCTAssertEqual(
            SymptomTrendLogic.toggling("anxiety", in: ranked, ranked: ranked),
            ["hot_flash", "mood", "anxiety"]
        )
    }

    func testEmptyExplicitSelectionDrawsNoSeries() {
        let chart = chart(selectedIds: [])
        XCTAssertEqual(chart?.series, [])
        XCTAssertEqual(chart?.defaultIds, ["hot_flash", "mood", "sleep"])
    }

    func testOneCycleHasAPointAndNoSecondDot() {
        let periods = [Period(id: "p1", startDate: TrendsFixture.cycleC, endDate: "2026-03-05")]
        let scores = [
            SymptomScore(id: "hot_flash", date: "2026-03-02", severity: 3, loggedAt: "t"),
        ]
        let chart = chart(periods: periods, scores: scores, changes: [])
        XCTAssertEqual(chart?.cycles.count, 1)
        XCTAssertEqual(chart?.series.first?.points.count, 1)
    }

    func testDoseChangeMarksVisibleCycle() {
        let chart = chart()
        XCTAssertEqual(chart?.ticks.count, 1)
        XCTAssertEqual(chart?.ticks.first?.cycleStart, TrendsFixture.cycleB)
        XCTAssertEqual(chart?.ticks.first?.nameSnapshot, TrendsFixture.doseMedName)
        XCTAssertEqual(chart?.ticks.first?.newValue, TrendsFixture.doseNewValue)
    }

    func testChangeOutsideVisibleSpanIsIgnored() {
        let early = MedicationChange(
            id: "old",
            medicationId: "m",
            nameSnapshot: "Estrogel",
            field: .dose,
            previousValue: "1 pump",
            newValue: "2 pumps",
            effectiveDate: "2025-11-01",
            loggedAt: "t"
        )
        let chart = chart(changes: [early])
        XCTAssertEqual(chart?.ticks, [])
    }

    func testMaxThreeSeries() {
        let chart = chart(selectedIds: ["hot_flash", "mood", "sleep", "joints"])
        XCTAssertLessThanOrEqual(chart?.series.count ?? 99, 3)
    }
}
