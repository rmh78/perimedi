import XCTest
@testable import PeriMediDomain

final class SymptomDirectoryTests: XCTestCase {
    private let day = "2026-03-15"
    private let fog = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-000000000001")!
    private let ache = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-000000000002")!

    private func dayScore(
        id: String,
        severity: Int,
        count: Int? = nil,
        note: String? = nil,
        loggedAt: String = "old",
        higherIsWorse: Bool = true,
        date: String? = nil
    ) -> SymptomScore {
        SymptomScore(
            id: id,
            date: date ?? day,
            severity: severity,
            count: count,
            note: note,
            loggedAt: loggedAt,
            higherIsWorse: higherIsWorse
        )
    }

    private func mark(
        _ decision: SymptomDay.Write,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> SymptomScore? {
        guard case .rewrite(let mark?) = decision else {
            XCTFail("expected a replacement row", file: file, line: line)
            return nil
        }
        return mark.score
    }

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

    func testWriteSkipsACleanCatalogRow() {
        let existing = dayScore(id: "sleep", severity: 2, loggedAt: "old", higherIsWorse: false)
        let decision = SymptomDay.write(
            date: day,
            ref: .catalog(.sleep),
            severity: 2,
            scores: [existing],
            directory: .catalogOnly,
            loggedAt: "new"
        )
        XCTAssertEqual(decision, .skip)
    }

    func testWriteSkipsACleanEmptyNote() {
        let existing = dayScore(id: "sleep", severity: 2, note: "")
        let decision = SymptomDay.write(
            date: day,
            ref: .catalog(.sleep),
            severity: 2,
            scores: [existing],
            directory: .catalogOnly,
            loggedAt: "new"
        )
        XCTAssertEqual(decision, .skip)
    }

    func testWriteSkipsWhenNothingMatchesAClear() {
        let otherDay = dayScore(id: "sleep", severity: 2, date: "2026-03-14")
        let otherId = dayScore(id: "hot_flash", severity: 2)
        for severity in [Int?.none, 0, 5] {
            let decision = SymptomDay.write(
                date: day,
                ref: .catalog(.sleep),
                severity: severity,
                scores: [otherDay, otherId],
                directory: .catalogOnly,
                loggedAt: "new"
            )
            XCTAssertEqual(decision, .skip)
        }
    }

    func testWriteSkipsAnUnlistedCustomSeverity() throws {
        let leftover = dayScore(id: fog.rawValue, severity: 2, count: 1, note: "kept")
        for severity in [3, 0, 5] {
            let decision = SymptomDay.write(
                date: day,
                ref: .custom(fog),
                severity: severity,
                scores: [leftover],
                directory: .catalogOnly,
                loggedAt: "new"
            )
            XCTAssertEqual(decision, .skip)
        }
    }

    func testWriteClearsAStoredRow() throws {
        let existing = dayScore(id: "sleep", severity: 2)
        for severity in [Int?.none, 0, 5] {
            let decision = SymptomDay.write(
                date: day,
                ref: .catalog(.sleep),
                severity: severity,
                scores: [existing],
                directory: .catalogOnly,
                loggedAt: "new"
            )
            XCTAssertEqual(decision, .rewrite(nil))
        }
        let listed = try SymptomDirectory.catalogOnly.adding("Fog", mint: fog).get().0
        let custom = dayScore(id: fog.rawValue, severity: 2)
        XCTAssertEqual(
            SymptomDay.write(
                date: day,
                ref: .custom(fog),
                severity: 0,
                scores: [custom],
                directory: listed,
                loggedAt: "new"
            ),
            .rewrite(nil)
        )
        XCTAssertEqual(
            SymptomDay.write(
                date: day,
                ref: .custom(fog),
                severity: nil,
                scores: [custom],
                directory: .catalogOnly,
                loggedAt: "new"
            ),
            .rewrite(nil)
        )
    }

    func testWriteReplacesWithACleanRow() throws {
        let created = try XCTUnwrap(mark(
            SymptomDay.write(
                date: day,
                ref: .catalog(.sleep),
                severity: 2,
                scores: [],
                directory: .catalogOnly,
                loggedAt: "new"
            )
        ))
        XCTAssertEqual(
            created,
            SymptomScore(id: "sleep", date: day, severity: 2, loggedAt: "new")
        )
        XCTAssertEqual(SymptomLog.normalized(created), created)

        let counted = dayScore(id: "sleep", severity: 2, count: 0)
        let spaced = dayScore(id: "sleep", severity: 2, note: " ")
        let duplicates = [dayScore(id: "sleep", severity: 2), dayScore(id: "sleep", severity: 2)]
        for scores in [[counted], [spaced], duplicates] {
            let score = try XCTUnwrap(mark(
                SymptomDay.write(
                    date: day,
                    ref: .catalog(.sleep),
                    severity: 2,
                    scores: scores,
                    directory: .catalogOnly,
                    loggedAt: "new"
                )
            ))
            XCTAssertEqual(score.count, nil)
            XCTAssertEqual(score.note, nil)
            XCTAssertEqual(score.loggedAt, "new")
            XCTAssertEqual(score.severity, 2)
        }

        let listed = try SymptomDirectory.catalogOnly.adding("Fog", mint: fog).get().0
        let custom = try XCTUnwrap(mark(
            SymptomDay.write(
                date: day,
                ref: .custom(fog),
                severity: 4,
                scores: [],
                directory: listed,
                loggedAt: "new"
            )
        ))
        XCTAssertEqual(custom.id, fog.rawValue)
        XCTAssertEqual(custom.severity, 4)
    }

    func testWriteSkipsTheRowItJustStored() throws {
        let first = try XCTUnwrap(mark(
            SymptomDay.write(
                date: day,
                ref: .catalog(.sleep),
                severity: 3,
                scores: [],
                directory: .catalogOnly,
                loggedAt: "first"
            )
        ))
        let second = SymptomDay.write(
            date: day,
            ref: .catalog(.sleep),
            severity: 3,
            scores: [first],
            directory: .catalogOnly,
            loggedAt: "second"
        )
        XCTAssertEqual(second, .skip)
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
        let plan = SymptomDirectory.synced(
            rows: decoded.customSymptoms,
            scores: decoded.symptomScores
        )
        XCTAssertEqual(
            plan.scores,
            [
                SymptomScore(id: fog.rawValue, date: "2026-03-15", severity: 2, loggedAt: "t"),
                SymptomScore(id: "hot_flash", date: "2026-03-15", severity: 3, loggedAt: "t"),
            ]
        )
    }

    func testSyncedFoldAndExportMatchesImport() throws {
        let later = ache
        let other = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-000000000003")!
        let orphan = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-000000000099")!
        let rows = [
            CustomSymptom(id: fog, name: "Fog", sort: 0),
            CustomSymptom(id: later, name: " FOG ", sort: 1),
            CustomSymptom(id: other, name: "Ache", sort: 2),
        ]
        let scores = [
            SymptomScore(id: "hot_flash", date: "2026-03-15", severity: 3, loggedAt: "2026-03-15T08:00:00Z"),
            SymptomScore(id: fog.rawValue, date: "2026-03-15", severity: 2, loggedAt: "2026-03-15T08:00:00Z"),
            SymptomScore(id: later.rawValue, date: "2026-03-15", severity: 4, loggedAt: "2026-03-16T09:00:00Z"),
            SymptomScore(id: later.rawValue, date: "2026-03-16", severity: 1, loggedAt: "2026-03-16T09:00:00Z"),
            SymptomScore(id: orphan.rawValue, date: "2026-03-17", severity: 4, loggedAt: "2026-03-17T09:00:00Z"),
        ]
        let plan = SymptomDirectory.synced(rows: rows, scores: scores)
        XCTAssertEqual(
            plan.directory.customs,
            [
                CustomSymptom(id: fog, name: "Fog", sort: 0),
                CustomSymptom(id: other, name: "Ache", sort: 2),
            ]
        )
        XCTAssertEqual(plan.instructions, [.deleteCustom(later)])
        XCTAssertEqual(
            plan.scores,
            [
                SymptomScore(id: fog.rawValue, date: "2026-03-15", severity: 4, loggedAt: "2026-03-16T09:00:00Z"),
                SymptomScore(id: "hot_flash", date: "2026-03-15", severity: 3, loggedAt: "2026-03-15T08:00:00Z"),
                SymptomScore(id: fog.rawValue, date: "2026-03-16", severity: 1, loggedAt: "2026-03-16T09:00:00Z"),
            ]
        )
        let payload = BackupCodec.makeExport(
            medications: [],
            schedules: [],
            doseLogs: [],
            remarks: [],
            cycleSettings: .default,
            periods: [],
            symptomScores: plan.scores,
            customSymptoms: plan.directory.customs,
            exportedAt: Date(timeIntervalSince1970: 0)
        )
        let decoded = try BackupCodec.decode(try BackupCodec.encode(payload))
        let imported = SymptomDirectory.synced(rows: decoded.customSymptoms, scores: decoded.symptomScores)
        XCTAssertEqual(imported.directory.customs, plan.directory.customs)
        XCTAssertEqual(imported.scores, plan.scores)
    }

    func testSyncedSameOrderKeepsLowerId() {
        let plan = SymptomDirectory.synced(
            rows: [
                CustomSymptom(id: ache, name: "Fog", sort: 3),
                CustomSymptom(id: fog, name: "FOG", sort: 3),
            ],
            scores: []
        )
        XCTAssertEqual(plan.directory.customs, [CustomSymptom(id: fog, name: "FOG", sort: 3)])
        XCTAssertEqual(plan.instructions, [.deleteCustom(ache)])
    }

    func testSyncedSameDayTieBreakIgnoresArrivalOrder() {
        let third = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-000000000003")!
        let rows = [
            CustomSymptom(id: fog, name: "Fog", sort: 0),
            CustomSymptom(id: ache, name: "FOG", sort: 1),
            CustomSymptom(id: third, name: "fog", sort: 2),
        ]
        let tied = "2026-03-15T08:00:00Z"
        let byCount = [
            SymptomScore(id: fog.rawValue, date: "2026-03-15", severity: 2, count: 1, note: "a", loggedAt: tied),
            SymptomScore(id: ache.rawValue, date: "2026-03-15", severity: 2, count: 1, note: "b", loggedAt: tied),
            SymptomScore(id: third.rawValue, date: "2026-03-15", severity: 2, count: 4, note: "a", loggedAt: tied),
        ]
        let counted = SymptomScore(
            id: fog.rawValue, date: "2026-03-15", severity: 2, count: 4, note: "a", loggedAt: tied
        )
        for order in orders(of: byCount) {
            XCTAssertEqual(SymptomDirectory.synced(rows: rows, scores: order).scores, [counted])
        }

        let byNote = [
            SymptomScore(id: fog.rawValue, date: "2026-03-15", severity: 2, count: 1, note: "a", loggedAt: tied),
            SymptomScore(id: ache.rawValue, date: "2026-03-15", severity: 2, count: 1, note: "b", loggedAt: tied),
        ]
        let noted = SymptomScore(
            id: fog.rawValue, date: "2026-03-15", severity: 2, count: 1, note: "b", loggedAt: tied
        )
        for order in orders(of: byNote) {
            XCTAssertEqual(SymptomDirectory.synced(rows: rows, scores: order).scores, [noted])
        }

        let byId = [
            SymptomScore(
                id: ache.rawValue, date: "2026-03-15", severity: 2, count: 1, note: "m",
                loggedAt: tied, higherIsWorse: true
            ),
            SymptomScore(
                id: fog.rawValue, date: "2026-03-15", severity: 2, count: 1, note: "m",
                loggedAt: tied, higherIsWorse: false
            ),
        ]
        let lowerId = SymptomScore(
            id: fog.rawValue, date: "2026-03-15", severity: 2, count: 1, note: "m",
            loggedAt: tied, higherIsWorse: false
        )
        for order in orders(of: byId) {
            XCTAssertEqual(SymptomDirectory.synced(rows: rows, scores: order).scores, [lowerId])
        }

        let sameId = [
            SymptomScore(
                id: fog.rawValue, date: "2026-03-15", severity: 2, count: 1, note: "m",
                loggedAt: tied, higherIsWorse: false
            ),
            SymptomScore(
                id: fog.rawValue, date: "2026-03-15", severity: 2, count: 1, note: "m",
                loggedAt: tied, higherIsWorse: true
            ),
        ]
        let worse = SymptomScore(
            id: fog.rawValue, date: "2026-03-15", severity: 2, count: 1, note: "m",
            loggedAt: tied, higherIsWorse: true
        )
        for order in orders(of: sameId) {
            XCTAssertEqual(SymptomDirectory.synced(rows: rows, scores: order).scores, [worse])
        }

        let laterLog = SymptomDirectory.synced(
            rows: rows,
            scores: [
                SymptomScore(id: third.rawValue, date: "2026-03-15", severity: 2, count: 9, note: "z", loggedAt: tied),
                SymptomScore(id: fog.rawValue, date: "2026-03-15", severity: 1, loggedAt: "2026-03-16T09:00:00Z"),
            ]
        )
        XCTAssertEqual(
            laterLog.scores,
            [SymptomScore(id: fog.rawValue, date: "2026-03-15", severity: 1, loggedAt: "2026-03-16T09:00:00Z")]
        )
    }

    func testSyncedSameTimestampKeepsHigherSeverity() {
        let plan = SymptomDirectory.synced(
            rows: [
                CustomSymptom(id: fog, name: "Fog", sort: 0),
                CustomSymptom(id: ache, name: "fog", sort: 1),
            ],
            scores: [
                SymptomScore(id: fog.rawValue, date: "2026-03-15", severity: 2, loggedAt: "2026-03-15T08:00:00Z"),
                SymptomScore(id: ache.rawValue, date: "2026-03-15", severity: 4, loggedAt: "2026-03-15T08:00:00Z"),
            ]
        )
        XCTAssertEqual(
            plan.scores,
            [SymptomScore(id: fog.rawValue, date: "2026-03-15", severity: 4, loggedAt: "2026-03-15T08:00:00Z")]
        )
    }

    func testRememberedPairRetargetsLateScoreOntoKeptSymptom() {
        let later = ache
        let memory = RememberedScoreRewrites.none.remembering([later: fog])
        let plan = SymptomDirectory.synced(
            rows: [CustomSymptom(id: fog, name: "Fog", sort: 0)],
            scores: [
                SymptomScore(id: fog.rawValue, date: "2026-03-17", severity: 2, loggedAt: "2026-03-17T08:00:00Z"),
                SymptomScore(id: later.rawValue, date: "2026-03-17", severity: 4, loggedAt: "2026-03-17T09:00:00Z"),
            ],
            memory: memory
        )
        XCTAssertEqual(
            plan.scores,
            [SymptomScore(id: fog.rawValue, date: "2026-03-17", severity: 4, loggedAt: "2026-03-17T09:00:00Z")]
        )
        XCTAssertEqual(plan.instructions, [])
        XCTAssertEqual(plan.memory, memory)
    }

    func testUnknownIdWithEmptyMemoryStaysOutOfScores() {
        let plan = SymptomDirectory.synced(
            rows: [CustomSymptom(id: fog, name: "Fog", sort: 0)],
            scores: [
                SymptomScore(id: fog.rawValue, date: "2026-03-15", severity: 2, loggedAt: "2026-03-15T08:00:00Z"),
                SymptomScore(id: ache.rawValue, date: "2026-03-17", severity: 4, loggedAt: "2026-03-17T09:00:00Z"),
            ]
        )
        XCTAssertEqual(
            plan.scores,
            [SymptomScore(id: fog.rawValue, date: "2026-03-15", severity: 2, loggedAt: "2026-03-15T08:00:00Z")]
        )
        XCTAssertEqual(plan.memory, .none)
    }

    func testPairWhoseWinnerIsAbsentStaysOutOfScores() {
        let later = ache
        let late = SymptomScore(
            id: later.rawValue,
            date: "2026-03-17",
            severity: 4,
            loggedAt: "2026-03-17T09:00:00Z"
        )
        let catalog = SymptomScore(
            id: "hot_flash",
            date: "2026-03-17",
            severity: 3,
            loggedAt: "2026-03-17T08:00:00Z"
        )
        let memory = RememberedScoreRewrites.none.remembering([later: fog])
        let plan = SymptomDirectory.synced(rows: [], scores: [late, catalog], memory: memory)
        XCTAssertEqual(plan.scores, [catalog])
        XCTAssertEqual(memory.wire, [later.rawValue: fog.rawValue])
        XCTAssertEqual(plan.memory, memory)
    }

    func testRememberingEmptyMapKeepsDormantPair() {
        let memory = RememberedScoreRewrites.none.remembering([ache: fog])
        XCTAssertEqual(memory.wire, [ache.rawValue: fog.rawValue])
        XCTAssertEqual(memory.remembering([:]).wire, [ache.rawValue: fog.rawValue])
    }

    func testRememberedPairDoesNotRetargetASymptomThatIsStillKept() {
        let memory = RememberedScoreRewrites.none.remembering([ache: fog])
        let plan = SymptomDirectory.synced(
            rows: [
                CustomSymptom(id: fog, name: "Fog", sort: 0),
                CustomSymptom(id: ache, name: "Ache", sort: 1),
            ],
            scores: [
                SymptomScore(id: ache.rawValue, date: "2026-03-17", severity: 4, loggedAt: "2026-03-17T09:00:00Z"),
            ],
            memory: memory
        )
        XCTAssertEqual(
            plan.scores,
            [SymptomScore(id: ache.rawValue, date: "2026-03-17", severity: 4, loggedAt: "2026-03-17T09:00:00Z")]
        )
        XCTAssertEqual(plan.memory, memory)
    }

    func testRememberedChainRepointsALateScoreOntoTheFinalSymptom() {
        let later = ache
        let older = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-000000000003")!
        let memory = RememberedScoreRewrites.none
            .remembering([later: fog])
            .remembering([fog: older])
        let plan = SymptomDirectory.synced(
            rows: [CustomSymptom(id: older, name: "Fog", sort: 0)],
            scores: [
                SymptomScore(id: later.rawValue, date: "2026-03-17", severity: 4, loggedAt: "2026-03-17T09:00:00Z"),
                SymptomScore(id: fog.rawValue, date: "2026-03-18", severity: 2, loggedAt: "2026-03-18T09:00:00Z"),
            ],
            memory: memory
        )
        XCTAssertEqual(
            plan.scores,
            [
                SymptomScore(id: older.rawValue, date: "2026-03-17", severity: 4, loggedAt: "2026-03-17T09:00:00Z"),
                SymptomScore(id: older.rawValue, date: "2026-03-18", severity: 2, loggedAt: "2026-03-18T09:00:00Z"),
            ]
        )
        XCTAssertEqual(plan.memory, memory)
    }

    func testThreeHopChainResolvesOnFirstSyncedForEveryInsertionOrder() {
        let a = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-00000000000a")!
        let b = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-00000000000b")!
        let c = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-00000000000c")!
        let d = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-00000000000d")!
        let late = SymptomScore(
            id: a.rawValue, date: "2026-03-17", severity: 4, loggedAt: "2026-03-17T09:00:00Z"
        )
        let onFinal = SymptomScore(
            id: d.rawValue, date: "2026-03-17", severity: 4, loggedAt: "2026-03-17T09:00:00Z"
        )
        let flat = RememberedScoreRewrites(wire: [
            a.rawValue: d.rawValue,
            b.rawValue: d.rawValue,
            c.rawValue: d.rawValue,
        ])
        let edges = [(a, b), (b, c), (c, d)]
        for order in orders(of: edges) {
            var memory = RememberedScoreRewrites.none
            for edge in order {
                memory = memory.remembering([edge.0: edge.1])
            }
            XCTAssertEqual(memory, flat)
            let plan = SymptomDirectory.synced(
                rows: [CustomSymptom(id: d, name: "Fog", sort: 0)],
                scores: [late],
                memory: memory
            )
            XCTAssertEqual(plan.scores, [onFinal])
            XCTAssertEqual(plan.memory, flat)
        }
        let stored = RememberedScoreRewrites(wire: [
            a.rawValue: b.rawValue,
            b.rawValue: c.rawValue,
            c.rawValue: d.rawValue,
        ])
        let fromDisk = SymptomDirectory.synced(
            rows: [CustomSymptom(id: d, name: "Fog", sort: 0)],
            scores: [late],
            memory: stored
        )
        XCTAssertEqual(fromDisk.scores, [onFinal])
        XCTAssertEqual(fromDisk.memory, flat)
    }

    func testKeeperIsLowestRecordIdAndWritesPreferWinner() {
        let blank = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-000000000099")!
        let unknown = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-000000000088")!
        let low = ScoreRecordId(rawValue: "a")
        let high = ScoreRecordId(rawValue: "b")
        let omitted = ScoreRecordId(rawValue: "z")
        let tied = "2026-03-15T08:00:00Z"
        let winner = SymptomScore(
            id: fog.rawValue, date: "2026-03-15", severity: 4, loggedAt: tied
        )
        let plan = SymptomDirectory.synced(
            rows: [
                CustomSymptom(id: fog, name: "Fog", sort: 0),
                CustomSymptom(id: ache, name: "fog", sort: 1),
                CustomSymptom(id: blank, name: "   ", sort: 9),
            ],
            records: [
                ScoredRecord(
                    id: high,
                    score: SymptomScore(id: fog.rawValue, date: "2026-03-15", severity: 4, loggedAt: tied)
                ),
                ScoredRecord(
                    id: low,
                    score: SymptomScore(id: ache.rawValue, date: "2026-03-15", severity: 2, loggedAt: tied)
                ),
                ScoredRecord(
                    id: omitted,
                    score: SymptomScore(id: unknown.rawValue, date: "2026-03-17", severity: 4, loggedAt: tied)
                ),
            ]
        )
        XCTAssertEqual(plan.scores, [winner])
        XCTAssertEqual(
            plan.instructions,
            [
                .deleteCustom(ache),
                .keep(ScoreKeep(recordId: low, score: winner)),
                .deleteScore(high),
            ]
        )
        XCTAssertEqual(plan.memory, RememberedScoreRewrites.none.remembering([ache: fog]))
    }

    func testRememberedEdgeStopsAtTheKeptSymptom() {
        let gone = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-00000000000b")!
        let still = ache
        let other = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-00000000000d")!
        let memory = RememberedScoreRewrites(wire: [
            gone.rawValue: still.rawValue,
            still.rawValue: other.rawValue,
        ])
        let plan = SymptomDirectory.synced(
            rows: [
                CustomSymptom(id: still, name: "Ache", sort: 0),
                CustomSymptom(id: other, name: "Other", sort: 1),
            ],
            scores: [
                SymptomScore(
                    id: gone.rawValue, date: "2026-03-17", severity: 4, loggedAt: "2026-03-17T09:00:00Z"
                ),
            ],
            memory: memory
        )
        XCTAssertEqual(
            plan.scores,
            [SymptomScore(
                id: still.rawValue, date: "2026-03-17", severity: 4, loggedAt: "2026-03-17T09:00:00Z"
            )]
        )
        XCTAssertEqual(plan.memory, memory)
    }

    func testRememberedPairPrefersLowerOriginalId() {
        let later = ache
        let tied = "2026-03-17T08:00:00Z"
        let memory = RememberedScoreRewrites.none.remembering([later: fog])
        let plan = SymptomDirectory.synced(
            rows: [CustomSymptom(id: fog, name: "Fog", sort: 0)],
            scores: [
                SymptomScore(
                    id: later.rawValue, date: "2026-03-17", severity: 2, count: 1, note: "m",
                    loggedAt: tied, higherIsWorse: true
                ),
                SymptomScore(
                    id: fog.rawValue, date: "2026-03-17", severity: 2, count: 1, note: "m",
                    loggedAt: tied, higherIsWorse: false
                ),
            ],
            memory: memory
        )
        XCTAssertEqual(
            plan.scores,
            [SymptomScore(
                id: fog.rawValue, date: "2026-03-17", severity: 2, count: 1, note: "m",
                loggedAt: tied, higherIsWorse: false
            )]
        )
    }

    private func orders<T>(of items: [T]) -> [[T]] {
        guard items.count > 1 else { return [items] }
        return items.indices.flatMap { index -> [[T]] in
            var rest = items
            let item = rest.remove(at: index)
            return orders(of: rest).map { [item] + $0 }
        }
    }
}
