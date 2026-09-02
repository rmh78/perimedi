import XCTest
@testable import PeriMediDomain

final class DoseRangeAndBackupTests: XCTestCase {
    let settings = CycleSettings(averageCycleLength: 28, averagePeriodLength: 5)

    func testRangeCoversTodayAndSelected() {
        let r = DoseRangeLogic.doseExpansionRange(
            today: "2026-08-07",
            selectedDate: "2026-08-01",
            periods: [],
            settings: settings
        )
        XCTAssertEqual(r.from, "2026-08-01")
        XCTAssertGreaterThanOrEqual(r.to, "2026-08-07")
    }

    func testRangeIncludesLatestCycleStart() {
        let r = DoseRangeLogic.doseExpansionRange(
            today: "2026-08-07",
            selectedDate: "2026-08-07",
            periods: [Period(id: "p1", startDate: "2026-07-10")],
            settings: settings
        )
        XCTAssertEqual(r.from, "2026-07-10")
    }

    func testRangeWidensWithExtras() {
        let r = DoseRangeLogic.doseExpansionRange(
            today: "2026-08-07",
            selectedDate: "2026-08-07",
            periods: [],
            settings: settings,
            extraFrom: ["2026-07-01"],
            extraTo: ["2026-09-05"]
        )
        XCTAssertEqual(r.from, "2026-07-01")
        XCTAssertEqual(r.to, "2026-09-05")
    }

    func testRejectsInvalidJSONWithoutThrowingPayload() {
        XCTAssertThrowsError(try BackupCodec.decode(Data("not-json".utf8))) { error in
            XCTAssertEqual(error as? BackupError, .invalidJSON)
        }
    }

    func testRejectsWrongVersion() throws {
        let json = """
        {"version":2,"exportedAt":"t","medications":[],"schedules":[],"doseLogs":[],"remarks":[],"cycleSettings":{"id":"default","averageCycleLength":28,"averagePeriodLength":5},"periods":[]}
        """
        XCTAssertThrowsError(try BackupCodec.decode(Data(json.utf8))) { error in
            XCTAssertEqual(error as? BackupError, .unsupportedVersion(2))
        }
    }

    func testSampleHasDosesOnToday() {
        let today = "2026-03-15"
        let sample = SampleData.payload(now: DateKeys.parseDateKey(today)!)
        let doses = ScheduleLogic.expandPlannedDoses(
            from: today,
            to: today,
            medications: sample.medications,
            schedules: sample.schedules,
            doseLogs: sample.doseLogs,
            periods: sample.periods,
            settings: sample.cycleSettings
        )
        let names = Set(doses.filter { $0.date == today }.map(\.medication.name))
        XCTAssertTrue(names.contains("Estradiol gel"))
        XCTAssertTrue(names.contains("Micronized progesterone"))
        XCTAssertTrue(names.contains("Vitamin D3"))
        XCTAssertTrue(names.contains("Magnesium glycinate"))
        XCTAssertEqual(CycleLogic.getCycleDay(dateKey: today, periods: sample.periods), 18)
    }

    func testRoundTripAndVersion1Fixture() throws {
        let sample = SampleData.payload(now: DateKeys.parseDateKey("2026-08-07")!)
        let data = try BackupCodec.encode(sample)
        let again = try BackupCodec.decode(data)
        XCTAssertEqual(again.version, 1)
        XCTAssertEqual(again.medications.count, 5)
        XCTAssertEqual(again.periods.count, 4)
        XCTAssertEqual(again.cycleSettings.averageCycleLength, 30)
        XCTAssertEqual(again.medicationChanges.count, 1)
        XCTAssertEqual(again.medicationChanges.first?.field, .dose)

        let fixtureURL = Bundle.module.url(forResource: "export-v1", withExtension: "json", subdirectory: "Fixtures")
        XCTAssertNotNil(fixtureURL, "export-v1.json fixture must ship with tests")
        if let fixtureURL {
            let imported = try BackupCodec.decode(Data(contentsOf: fixtureURL))
            XCTAssertEqual(imported.version, 1)
            XCTAssertEqual(imported.medications.map(\.name), ["Estradiol gel", "Micronized progesterone"])
            XCTAssertEqual(imported.schedules.count, 2)
            XCTAssertEqual(imported.periods.count, 1)
            XCTAssertEqual(imported.doseLogs.first?.status, .taken)
            XCTAssertEqual(imported.remarks.first?.body, "Cramps day 1")
            XCTAssertEqual(imported.cycleSettings.averagePeriodLength, 5)
        }
    }
}
