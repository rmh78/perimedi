import PDFKit
import XCTest
@testable import PeriMediDomain

final class DoctorVisitLogicTests: XCTestCase {
    private let settings = CycleSettings(averageCycleLength: 28, averagePeriodLength: 5)
    private let today = "2026-03-15"

    private func med(
        id: String = "m1",
        name: String = "Estrogel",
        dose: String = "2 pumps"
    ) -> Medication {
        Medication(id: id, name: name, form: .CREAM, doseLabel: dose, createdAt: "t")
    }

    private func sched(medicationId: String = "m1", start: String = "2026-01-01") -> Schedule {
        Schedule(
            id: "s-\(medicationId)",
            medicationId: medicationId,
            daysOfWeek: [],
            timeOfDay: "08:00",
            active: true,
            startDate: start,
            cycleRule: .none
        )
    }

    private func period(_ id: String, start: String, end: String? = nil) -> Period {
        Period(id: id, startDate: start, endDate: end)
    }

    private func score(_ id: SymptomId, date: String, severity: Int, count: Int? = nil) -> SymptomScore {
        SymptomScore(id: id.rawValue, date: date, severity: severity, count: count, loggedAt: "t")
    }

    private func change(
        effective: String,
        name: String = "Estrogel",
        previous: String = "1 pump",
        newValue: String = "2 pumps"
    ) -> MedicationChange {
        MedicationChange(
            id: createId(),
            medicationId: "m1",
            nameSnapshot: name,
            field: .dose,
            previousValue: previous,
            newValue: newValue,
            effectiveDate: effective,
            loggedAt: "t"
        )
    }

    private func report(
        periods: [Period],
        settings: CycleSettings? = nil,
        scores: [SymptomScore] = [],
        medications: [Medication]? = nil,
        schedules: [Schedule]? = nil,
        doseLogs: [DoseLog] = [],
        changes: [MedicationChange] = []
    ) -> DoctorVisitReport {
        let meds = medications ?? [med()]
        return DoctorVisitLogic.report(
            today: today,
            medications: meds,
            schedules: schedules ?? [sched()],
            doseLogs: doseLogs,
            periods: periods,
            settings: settings ?? self.settings,
            scores: scores,
            changes: changes
        )
    }

    func testTwoCompletedCycles() {
        let result = report(periods: [
            period("p0", start: "2026-01-01", end: "2026-01-05"),
            period("p1", start: "2026-02-01", end: "2026-02-05"),
            period("p2", start: "2026-03-01", end: "2026-03-05"),
        ])
        XCTAssertEqual(result.rangeKind, .completedCycles(2))
        XCTAssertEqual(result.rangeStart, "2026-01-01")
        XCTAssertEqual(result.rangeEnd, "2026-02-28")
        XCTAssertEqual(result.generatedOn, today)
    }

    func testOneCompletedCycle() {
        let result = report(periods: [
            period("p1", start: "2026-02-01", end: "2026-02-05"),
            period("p2", start: "2026-03-01", end: "2026-03-05"),
        ])
        XCTAssertEqual(result.rangeKind, .completedCycles(1))
        XCTAssertEqual(result.rangeStart, "2026-02-01")
        XCTAssertEqual(result.rangeEnd, "2026-02-28")
    }

    func testThinHistoryUsesFourWeeks() {
        let result = report(periods: [period("p2", start: "2026-03-01", end: "2026-03-05")])
        XCTAssertEqual(result.rangeKind, .fourWeeks)
        XCTAssertEqual(result.rangeStart, "2026-02-16")
        XCTAssertEqual(result.rangeEnd, today)
    }

    func testNoPeriodHistoryUsesTwelveWeeks() {
        let result = report(periods: [])
        XCTAssertEqual(result.rangeKind, .twelveWeeks)
        XCTAssertEqual(result.rangeStart, "2025-12-22")
        XCTAssertEqual(result.rangeEnd, today)
    }

    func testTrackingOffUsesTwelveWeeks() {
        var off = settings
        off.tracksPeriods = false
        let result = report(
            periods: [
                period("p0", start: "2026-01-01"),
                period("p1", start: "2026-02-01"),
                period("p2", start: "2026-03-01"),
            ],
            settings: off
        )
        XCTAssertEqual(result.rangeKind, .twelveWeeks)
        XCTAssertEqual(result.rangeStart, "2025-12-22")
    }

    func testPredictedStartsDoNotDefineRange() {
        let windows = CycleLogic.loggedCycleWindows(
            periods: [
                period("p0", start: "2026-02-01"),
                period("p1", start: "2026-03-01"),
            ],
            today: today
        )
        XCTAssertEqual(windows.map(\.start), ["2026-02-01", "2026-03-01"])
        XCTAssertEqual(windows[0].end, "2026-02-28")
    }

    func testTakenRateIgnoresPending() {
        let logs = (0..<10).map { i -> DoseLog in
            let day = DateKeys.addDaysKey("2026-02-01", i)
            return DoseLog(
                id: "l\(i)",
                medicationId: "m1",
                scheduleId: "s-m1",
                plannedFor: "\(day)T08:00:00",
                status: i < 4 ? .taken : .pending
            )
        }
        let result = report(
            periods: [
                period("p1", start: "2026-02-01", end: "2026-02-05"),
                period("p2", start: "2026-03-01"),
            ],
            doseLogs: logs
        )
        XCTAssertEqual(result.medications.count, 1)
        XCTAssertEqual(result.medications[0].name, "Estrogel")
        XCTAssertEqual(result.medications[0].taken, 4)
        XCTAssertEqual(result.medications[0].planned, 28)
        XCTAssertEqual(result.medications[0].percent, 14)
    }

    func testMissingDaysAreNotZero() {
        let result = report(
            periods: [
                period("p1", start: "2026-02-01", end: "2026-02-05"),
                period("p2", start: "2026-03-01"),
            ],
            scores: [
                score(.sleep, date: "2026-02-02", severity: 4),
                score(.sleep, date: "2026-02-03", severity: 2),
                score(.sleep, date: "2026-02-04", severity: 3),
            ]
        )
        XCTAssertEqual(result.symptoms.map(\.id), ["sleep"])
        XCTAssertEqual(result.symptoms[0].dayCount, 3)
        XCTAssertEqual(result.symptoms[0].meanIntensity, 3.0, accuracy: 0.01)
    }

    func testHotFlashUsesDaysScoredNotEpisodeCount() {
        let result = report(
            periods: [
                period("p1", start: "2026-02-01"),
                period("p2", start: "2026-03-01"),
            ],
            scores: [
                score(.hot_flash, date: "2026-02-02", severity: 2, count: 12),
                score(.hot_flash, date: "2026-02-03", severity: 3, count: 8),
            ]
        )
        let row = result.symptoms.first { $0.id == "hot_flash" }
        XCTAssertEqual(row?.dayCount, 2)
        XCTAssertEqual(row?.meanIntensity ?? -1, 2.5, accuracy: 0.01)
    }

    func testUnscoredIdsOmittedAndChangesOutsideRangeDropped() {
        let result = report(
            periods: [
                period("p1", start: "2026-02-01"),
                period("p2", start: "2026-03-01"),
            ],
            scores: [score(.mood, date: "2026-02-10", severity: 2)],
            changes: [
                change(effective: "2026-01-15"),
                change(effective: "2026-02-10", newValue: "2 pumps"),
            ]
        )
        XCTAssertEqual(result.symptoms.map(\.id), ["mood"])
        XCTAssertEqual(result.changes.map(\.effectiveDate), ["2026-02-10"])
        XCTAssertEqual(result.periods.map(\.start), ["2026-02-01"])
    }

    func testOmitsEffectWhenNamedChangeIsOutsideRange() {
        let scores = [
            score(.hot_flash, date: "2026-03-06", severity: 2),
            score(.hot_flash, date: "2026-02-02", severity: 4),
        ]
        let result = report(
            periods: [
                period("p0", start: "2026-01-01", end: "2026-01-05"),
                period("p1", start: "2026-02-01", end: "2026-02-05"),
                period("p2", start: "2026-03-01", end: "2026-03-05"),
            ],
            scores: scores,
            changes: [change(effective: "2026-03-06")]
        )
        XCTAssertEqual(result.rangeKind, .completedCycles(2))
        XCTAssertEqual(result.rangeEnd, "2026-02-28")
        XCTAssertTrue(result.changes.isEmpty)
        XCTAssertEqual(result.effect.kind, .hidden)
    }

    func testKeepsEffectWhenNamedChangeIsInRange() {
        let scores = [
            score(.hot_flash, date: "2026-03-06", severity: 2),
            score(.hot_flash, date: "2026-02-02", severity: 4),
        ]
        let result = report(
            periods: [
                period("p1", start: "2026-02-01", end: "2026-02-05"),
                period("p2", start: "2026-03-01"),
            ],
            scores: scores,
            changes: [change(effective: "2026-02-10")]
        )
        XCTAssertEqual(result.rangeKind, .completedCycles(1))
        XCTAssertEqual(result.changes.map(\.effectiveDate), ["2026-02-10"])
        XCTAssertNotEqual(result.effect.kind, .hidden)
        XCTAssertEqual(result.effect.context?.effectiveDate, "2026-02-10")
    }

    func testSelectedHistoricalCycleSetsRange() {
        let cycles = DoctorVisitLogic.completedCycles(
            today: today,
            periods: [
                period("p0", start: "2026-01-01"),
                period("p1", start: "2026-02-01"),
                period("p2", start: "2026-03-01"),
            ],
            settings: settings
        )
        XCTAssertEqual(cycles.map(\.start), ["2026-01-01", "2026-02-01"])
        let result = DoctorVisitLogic.report(
            today: today,
            medications: [med()],
            schedules: [sched()],
            doseLogs: [],
            periods: [
                period("p0", start: "2026-01-01"),
                period("p1", start: "2026-02-01"),
                period("p2", start: "2026-03-01"),
            ],
            settings: settings,
            scores: [],
            changes: [],
            selectedCycles: [cycles[0]]
        )
        XCTAssertEqual(result.rangeKind, .completedCycles(1))
        XCTAssertEqual(result.rangeStart, "2026-01-01")
        XCTAssertEqual(result.rangeEnd, "2026-01-31")
    }

    func testDummyRangePdfContainsMedsPeriodsSymptomsChangeAndDisclaimer() {
        let logs = ["2026-02-02", "2026-02-03"].map { day in
            DoseLog(
                id: day,
                medicationId: "m1",
                scheduleId: "s-m1",
                plannedFor: "\(day)T08:00:00",
                status: .taken
            )
        }
        let scores = [
            score(.hot_flash, date: "2026-02-02", severity: 3, count: 9),
            score(.hot_flash, date: "2026-02-08", severity: 2),
            score(.hot_flash, date: "2026-03-06", severity: 1),
            score(.sleep, date: "2026-02-03", severity: 4),
            score(.sleep, date: "2026-03-07", severity: 2),
        ]
        let result = report(
            periods: [
                period("p1", start: "2026-02-01", end: "2026-02-05"),
                period("p2", start: "2026-03-01", end: "2026-03-05"),
            ],
            scores: scores,
            doseLogs: logs,
            changes: [change(effective: "2026-02-10")]
        )
        XCTAssertEqual(result.rangeKind, .completedCycles(1))
        XCTAssertEqual(result.medications.first?.taken, 2)
        XCTAssertEqual(result.symptoms.map(\.id), ["hot_flash", "sleep"])
        XCTAssertEqual(result.symptoms[0].dayCount, 2)
        XCTAssertFalse(result.changes.isEmpty)
        XCTAssertEqual(result.periods.first?.start, "2026-02-01")
        XCTAssertNotEqual(result.effect.kind, .hidden)

        let page = DoctorVisitPage(
            title: "PeriMedi visit summary",
            meta: ["Generated 15 Mar 2026", "1 Feb 2026 – 28 Feb 2026 (last completed cycle)"],
            sections: [
                DoctorVisitSection(heading: "Effect", rows: ["Hot flushes down a bit than last cycle"]),
                DoctorVisitSection(
                    heading: "Medications",
                    rows: ["Estrogel · 2 pumps · 2 of 28 taken (7%)"]
                ),
                DoctorVisitSection(
                    heading: "Dose and schedule changes",
                    rows: ["10 Feb 2026: Estrogel dose 1 pump → 2 pumps. Context only, not a cause."]
                ),
                DoctorVisitSection(heading: "Periods", rows: ["1 Feb 2026 – 5 Feb 2026"]),
                DoctorVisitSection(
                    heading: "Symptoms",
                    rows: [
                        "Symptom · days scored · average",
                        "Hot flushes · 2 days · average 2.5",
                        "Sleep · 1 days · average 4.0",
                    ]
                ),
            ],
            disclaimer: "This PDF is not a medical record and not medical advice. It is a personal summary from PeriMedi."
        )
        let data = DoctorVisitPDF.data(page: page)
        XCTAssertFalse(data.isEmpty)
        guard let doc = PDFDocument(data: data) else {
            return XCTFail("PDFDocument")
        }
        XCTAssertGreaterThanOrEqual(doc.pageCount, 1)
        let text = (0..<doc.pageCount).compactMap { doc.page(at: $0)?.string }.joined(separator: "\n")
        XCTAssertTrue(text.contains("Estrogel"))
        XCTAssertTrue(text.contains("2 of 28 taken"))
        XCTAssertTrue(text.contains("Hot flushes"))
        XCTAssertTrue(text.contains("2.5"))
        XCTAssertTrue(text.contains("1 pump"))
        XCTAssertTrue(text.contains("2 pumps"))
        XCTAssertTrue(text.contains("Context only"))
        XCTAssertTrue(text.contains("1 Feb 2026"))
        XCTAssertTrue(text.contains("not a medical record"))
        XCTAssertTrue(text.contains("not medical advice"))
        XCTAssertFalse(text.contains("MRS"))
        XCTAssertFalse(text.lowercased().contains("follicular"))

        let pdfPage = doc.page(at: 0)!
        let box = pdfPage.bounds(for: .mediaBox)
        let titleBox = pdfPage.characterBounds(at: 0)
        XCTAssertFalse(titleBox.isNull || titleBox.isEmpty, "title glyph bounds")
        XCTAssertGreaterThan(
            titleBox.midY,
            box.midY,
            "title must sit in the upper half (PDF Y-up); was flipped in Quick Look"
        )
    }
}
