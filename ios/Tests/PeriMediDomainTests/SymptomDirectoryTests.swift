import XCTest
@testable import PeriMediDomain

final class SymptomDirectoryTests: XCTestCase {
    private let fog = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-000000000001")!
    private let ache = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-000000000002")!

    func testMintParsesAndCatalogIdDoesNot() {
        let minted = CustomSymptomId.mint()
        XCTAssertEqual(SymptomRef.parse(minted.rawValue), .custom(minted))
        XCTAssertEqual(SymptomRef.parse("hot_flash"), .catalog(.hot_flash))
        XCTAssertNil(SymptomRef.parse("Brain fog"))
        XCTAssertNil(CustomSymptomId(rawValue: "c.NOT-A-UUID"))
    }

    func testRenameKeepsIdAndRejectsDuplicateFold() {
        let added = SymptomDirectory.catalogOnly.adding("Fog", mint: fog)
        guard case .success(let pair) = added else {
            return XCTFail("expected create")
        }
        let renamed = pair.0.renaming(fog, to: "  fog  ")
        guard case .success(let next) = renamed else {
            return XCTFail("expected rename")
        }
        XCTAssertEqual(next.customs, [CustomSymptom(id: fog, name: "fog", sort: 0)])
        guard case .failure(let error) = next.adding("FOG", mint: ache) else {
            return XCTFail("expected a duplicate")
        }
        XCTAssertEqual(error, .duplicateName)
    }

    func testBlankAndLongNamesFail() {
        guard case .failure(let blank) = SymptomDirectory.catalogOnly.adding("   ") else {
            return XCTFail("expected a blank name")
        }
        XCTAssertEqual(blank, .blankName)
        let long = String(repeating: "a", count: 41)
        guard case .failure(let tooLong) = SymptomDirectory.catalogOnly.adding(long) else {
            return XCTFail("expected a long name")
        }
        XCTAssertEqual(tooLong, .nameTooLong)
    }

    func testAddCapIsEight() {
        var directory = SymptomDirectory.catalogOnly
        for index in 0..<8 {
            let id = CustomSymptomId(rawValue: String(format: "c.00000000-0000-0000-0000-%012d", index))!
            guard case .success(let pair) = directory.adding("Name \(index)", mint: id) else {
                return XCTFail("add \(index)")
            }
            directory = pair.0
        }
        guard case .failure(let capped) = directory.adding("Ninth", mint: ache) else {
            return XCTFail("expected the cap")
        }
        XCTAssertEqual(capped, .tooMany)
        let ninth = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-000000000009")!
        let restored = SymptomDirectory.restored(directory.customs + [
            CustomSymptom(id: ninth, name: "Ninth", sort: 8)
        ])
        XCTAssertEqual(restored.customs.count, 9)
    }

    func testRestoreDropsBlankAndTruncates() {
        let long = String(repeating: "b", count: 45)
        let restored = SymptomDirectory.restored([
            CustomSymptom(id: fog, name: "   ", sort: 0),
            CustomSymptom(id: ache, name: long, sort: 2),
            CustomSymptom(id: ache, name: "shorter", sort: 1),
        ])
        XCTAssertEqual(restored.customs.count, 1)
        XCTAssertEqual(restored.customs[0].name, "shorter")
        XCTAssertEqual(restored.customs[0].sort, 1)
    }

    func testRankedIdsKeepCatalogOrderThenCustom() throws {
        let directory = try SymptomDirectory.catalogOnly.adding("Fog", mint: fog).get().0
        XCTAssertEqual(directory.rankedIds.prefix(11).map { $0 }, SymptomId.allCases.map(\.rawValue))
        XCTAssertEqual(directory.rankedIds.last, fog.rawValue)
        XCTAssertEqual(directory.blocks.count, 4)
    }

    func testOldBackupWithoutCustomSymptomsDecodesEmpty() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "export-v1", withExtension: "json", subdirectory: "Fixtures")
        )
        let payload = try BackupCodec.decode(Data(contentsOf: url))
        XCTAssertEqual(payload.version, 1)
        XCTAssertEqual(payload.customSymptoms, [])
    }

    func testBadCustomElementDoesNotFailTheFile() throws {
        let json = """
        {"version":1,"exportedAt":"t","medications":[],"schedules":[],"doseLogs":[],"remarks":[],"cycleSettings":{"averageCycleLength":28,"averagePeriodLength":5,"tracksPeriods":true},"periods":[],"customSymptoms":[{"id":"nope","name":"X","sort":0},{"id":"c.00000000-0000-0000-0000-000000000001","name":"Fog","sort":1},"bad"]}
        """
        let payload = try BackupCodec.decode(Data(json.utf8))
        XCTAssertEqual(payload.customSymptoms, [CustomSymptom(id: fog, name: "Fog", sort: 1)])
    }

    func testCustomSeriesOutranksAQuieterCatalogId() throws {
        let directory = try SymptomDirectory.catalogOnly.adding("Fog", mint: fog).get().0
        let periods = [
            Period(id: "p0", startDate: "2026-01-01"),
            Period(id: "p1", startDate: "2026-02-01"),
        ]
        var scores: [SymptomScore] = []
        for day in ["2026-01-02", "2026-01-03", "2026-02-02", "2026-02-03"] {
            scores.append(SymptomScore(id: fog.rawValue, date: day, severity: 2, loggedAt: "t"))
        }
        scores.append(SymptomScore(id: "hot_flash", date: "2026-01-02", severity: 3, loggedAt: "t"))
        let result = SymptomTrendLogic.summarize(
            today: "2026-02-15",
            periods: periods,
            settings: CycleSettings(averageCycleLength: 28, averagePeriodLength: 5),
            scores: scores,
            changes: [],
            directory: directory
        )
        guard case .chart(let chart) = result.kind else {
            return XCTFail("expected a chart")
        }
        XCTAssertEqual(chart.defaultIds, [fog.rawValue, "hot_flash"])
        let toggled = SymptomTrendLogic.toggling(
            fog.rawValue,
            in: chart.defaultIds,
            ranked: chart.defaultIds,
            directory: directory
        )
        XCTAssertEqual(toggled, ["hot_flash"])
        XCTAssertEqual(
            SymptomTrendLogic.toggling("not-a-symptom", in: toggled, ranked: chart.defaultIds, directory: directory),
            ["hot_flash"]
        )
    }

    func testDayRowOmitsSeverityOutsideOneToFour() {
        XCTAssertNil(SymptomDay.row(date: "2026-03-15", ref: .catalog(.sleep), severity: nil, loggedAt: "t"))
        XCTAssertNil(SymptomDay.row(date: "2026-03-15", ref: .catalog(.sleep), severity: 0, loggedAt: "t"))
        let row = SymptomDay.row(date: "2026-03-15", ref: .custom(fog), severity: 2, loggedAt: "t")
        XCTAssertEqual(row?.id, fog.rawValue)
        XCTAssertEqual(row?.severity, 2)
        XCTAssertNil(row?.note)
    }

    func testEqualDayCountsKeepTheEarlierCatalogId() throws {
        let directory = try SymptomDirectory.catalogOnly.adding("Fog", mint: fog).get().0
        let periods = [
            Period(id: "p0", startDate: "2026-01-01"),
            Period(id: "p1", startDate: "2026-02-01"),
        ]
        let days = ["2026-01-02", "2026-02-02"]
        var scores: [SymptomScore] = []
        for day in days {
            scores.append(SymptomScore(id: "hot_flash", date: day, severity: 2, loggedAt: "t"))
            scores.append(SymptomScore(id: fog.rawValue, date: day, severity: 4, loggedAt: "t"))
        }
        let result = SymptomTrendLogic.summarize(
            today: "2026-02-15",
            periods: periods,
            settings: CycleSettings(averageCycleLength: 28, averagePeriodLength: 5),
            scores: scores,
            changes: [],
            directory: directory
        )
        guard case .chart(let chart) = result.kind else {
            return XCTFail("expected a chart")
        }
        XCTAssertEqual(chart.defaultIds, ["hot_flash", fog.rawValue])
    }

    func testRoundTripKeepsCustomsAndDropsOrphanScores() throws {
        let directory = try SymptomDirectory.catalogOnly.adding("Fog", mint: fog).get().0
        let orphan = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-000000000099")!
        let scores = [
            SymptomScore(id: "hot_flash", date: "2026-03-15", severity: 3, loggedAt: "t"),
            SymptomScore(id: fog.rawValue, date: "2026-03-15", severity: 2, loggedAt: "t"),
            SymptomScore(id: orphan.rawValue, date: "2026-03-15", severity: 4, loggedAt: "t"),
        ]
        let payload = BackupCodec.makeExport(
            medications: [],
            schedules: [],
            doseLogs: [],
            remarks: [],
            cycleSettings: .default,
            periods: [],
            symptomScores: scores,
            customSymptoms: directory.customs
        )
        let decoded = try BackupCodec.decode(try BackupCodec.encode(payload))
        XCTAssertEqual(decoded.customSymptoms, [CustomSymptom(id: fog, name: "Fog", sort: 0)])
        let stored = SymptomDirectory.scoresToStore(
            decoded.symptomScores,
            directory: SymptomDirectory.restored(decoded.customSymptoms)
        )
        XCTAssertEqual(stored.map(\.id), ["hot_flash", fog.rawValue])
    }
}
