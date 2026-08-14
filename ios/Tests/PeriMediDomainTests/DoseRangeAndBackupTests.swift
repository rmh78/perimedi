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
            extraFrom: ["2026-07-26"],
            extraTo: ["2026-09-05"]
        )
        XCTAssertEqual(r.from, "2026-07-26")
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

    func testRoundTripAndWebFixture() throws {
        let sample = SampleData.payload(now: DateKeys.parseDateKey("2026-08-07")!)
        let data = try BackupCodec.encode(sample)
        let again = try BackupCodec.decode(data)
        XCTAssertEqual(again.version, 1)
        XCTAssertEqual(again.medications.count, 6)
        XCTAssertEqual(again.periods.count, 3)
        XCTAssertEqual(again.cycleSettings.averageCycleLength, 28)

        let fixtureURL = Bundle.module.url(forResource: "web-export-v1", withExtension: "json", subdirectory: "Fixtures")
        XCTAssertNotNil(fixtureURL, "web-export-v1.json fixture must ship with tests")
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
