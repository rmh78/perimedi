import SwiftData
import XCTest
import PeriMediDomain
@testable import PeriMedi

@MainActor
final class CustomSymptomSyncTests: XCTestCase {
    private nonisolated static let foldSuiteName = "perimedi.late-score"

    private let fog = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-000000000001")!
    private let later = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-000000000002")!
    private let orphan = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-000000000099")!

    private nonisolated static let extraSuites = [
        "perimedi.late-score-stable",
        "perimedi.late-score-survive",
        "perimedi.late-score-malformed",
        "perimedi.export-fold",
        "perimedi.refresh-keep",
        "perimedi.empty-record-id",
        "perimedi.shared-record-id",
        "perimedi.import-same-name",
    ]

    override func tearDown() {
        for name in [Self.foldSuiteName] + Self.extraSuites {
            UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
        }
        super.tearDown()
    }

    func testCycleAndMonthLeaveOrphanScoreUnmarked() {
        let directory = SymptomDirectory.restored([
            CustomSymptom(id: fog, name: "Fog", sort: 0),
        ])
        let scores = [
            SymptomScore(id: "hot_flash", date: "2026-03-15", severity: 3, loggedAt: "2026-03-15T08:00:00Z"),
            SymptomScore(id: fog.rawValue, date: "2026-03-15", severity: 2, loggedAt: "2026-03-15T08:00:00Z"),
            SymptomScore(id: orphan.rawValue, date: "2026-03-17", severity: 4, loggedAt: "2026-03-17T09:00:00Z"),
        ]
        let remarks = [
            Remark(
                id: "r1",
                occurredOn: "2026-03-14",
                kind: .note,
                body: "note",
                createdAt: "2026-03-14T08:00:00Z"
            ),
        ]
        let cycle = CycleSnapshot.build(
            selectedDate: "2026-03-15",
            today: "2026-03-15",
            medications: [],
            schedules: [],
            doseLogs: [],
            remarks: remarks,
            symptomScores: scores,
            directory: directory,
            periods: [],
            settings: .default
        )
        XCTAssertTrue(cycle.strip.contains { $0.dateKey == "2026-03-17" })
        XCTAssertEqual(marked(cycle.strip, "2026-03-15"), true)
        XCTAssertEqual(marked(cycle.strip, "2026-03-14"), true)
        XCTAssertEqual(marked(cycle.strip, "2026-03-17"), false)

        let month = MonthGridModel.build(
            monthAnchor: DateKeys.parseDateKey("2026-03-15")!,
            selectedDate: "2026-03-15",
            today: "2026-03-15",
            medications: [],
            schedules: [],
            doseLogs: [],
            remarks: remarks,
            symptomScores: scores,
            directory: directory,
            periods: [],
            settings: .default
        )
        XCTAssertEqual(monthCell(month, "2026-03-15")?.hasSymptom, true)
        XCTAssertEqual(monthCell(month, "2026-03-14")?.hasSymptom, true)
        let orphanDay = monthCell(month, "2026-03-17")
        XCTAssertEqual(orphanDay?.hasSymptom, false)
        XCTAssertEqual(orphanDay?.scoreSummary, "")
    }

    func testExportPayloadFoldsNamesAndOmitsOrphan() throws {
        let container = try inMemoryContainer(name: "export-fold")
        let context = container.mainContext
        for symptom in [
            CustomSymptom(id: fog, name: "Fog", sort: 0),
            CustomSymptom(id: later, name: " FOG ", sort: 1),
        ] {
            let row = SDCustomSymptom()
            row.apply(symptom)
            context.insert(row)
        }
        for score in [
            SymptomScore(id: "hot_flash", date: "2026-03-15", severity: 3, loggedAt: "2026-03-15T08:00:00Z"),
            SymptomScore(id: fog.rawValue, date: "2026-03-15", severity: 2, loggedAt: "2026-03-15T08:00:00Z"),
            SymptomScore(id: later.rawValue, date: "2026-03-15", severity: 4, loggedAt: "2026-03-16T09:00:00Z"),
            SymptomScore(id: orphan.rawValue, date: "2026-03-17", severity: 4, loggedAt: "2026-03-17T09:00:00Z"),
        ] {
            let row = SDSymptomScore()
            row.apply(score)
            context.insert(row)
        }

        let suite = "perimedi.export-fold"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let store = Store(container: container, foldDefaults: defaults)
        let payload = store.exportPayload()

        XCTAssertEqual(
            payload.customSymptoms,
            [CustomSymptom(id: fog, name: "Fog", sort: 0)]
        )
        XCTAssertEqual(
            payload.symptomScores,
            [
                SymptomScore(id: fog.rawValue, date: "2026-03-15", severity: 4, loggedAt: "2026-03-16T09:00:00Z"),
                SymptomScore(id: "hot_flash", date: "2026-03-15", severity: 3, loggedAt: "2026-03-15T08:00:00Z"),
            ]
        )
        XCTAssertFalse(payload.symptomScores.contains { $0.id == orphan.rawValue })
        XCTAssertNil(store.lastError)
    }

    func testLateScoreForDeletedDuplicateLandsOnKeptSymptom() throws {
        let container = try ModelContainer(
            for: PersistenceController.schema,
            configurations: [
                ModelConfiguration(
                    "late-score",
                    schema: PersistenceController.schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                ),
            ]
        )
        let context = container.mainContext
        for symptom in [
            CustomSymptom(id: fog, name: "Fog", sort: 0),
            CustomSymptom(id: later, name: " FOG ", sort: 1),
        ] {
            let row = SDCustomSymptom()
            row.apply(symptom)
            context.insert(row)
        }
        let defaults = try XCTUnwrap(UserDefaults(suiteName: Self.foldSuiteName))
        defaults.removePersistentDomain(forName: Self.foldSuiteName)
        let store = Store(container: container, foldDefaults: defaults)
        XCTAssertEqual(store.customSymptoms, [CustomSymptom(id: fog, name: "Fog", sort: 0)])

        let late = SymptomScore(
            id: later.rawValue,
            date: "2026-03-17",
            severity: 4,
            loggedAt: "2026-03-17T09:00:00Z"
        )
        let row = SDSymptomScore()
        row.apply(late)
        context.insert(row)
        store.refresh()

        let kept = SymptomScore(
            id: fog.rawValue,
            date: "2026-03-17",
            severity: 4,
            loggedAt: "2026-03-17T09:00:00Z"
        )
        XCTAssertEqual(store.symptomScores, [kept])
        XCTAssertFalse(store.symptomScores.contains { $0.id == later.rawValue })

        let directory = store.symptomDirectory
        let cycle = CycleSnapshot.build(
            selectedDate: "2026-03-15",
            today: "2026-03-15",
            medications: [],
            schedules: [],
            doseLogs: [],
            remarks: [],
            symptomScores: store.symptomScores,
            directory: directory,
            periods: [],
            settings: store.settings
        )
        XCTAssertEqual(marked(cycle.strip, "2026-03-17"), true)

        let month = MonthGridModel.build(
            monthAnchor: DateKeys.parseDateKey("2026-03-15")!,
            selectedDate: "2026-03-15",
            today: "2026-03-15",
            medications: [],
            schedules: [],
            doseLogs: [],
            remarks: [],
            symptomScores: store.symptomScores,
            directory: directory,
            periods: [],
            settings: store.settings
        )
        let lateDay = monthCell(month, "2026-03-17")
        XCTAssertEqual(lateDay?.hasSymptom, true)
        XCTAssertFalse(lateDay?.scoreSummary.isEmpty ?? true)

        let payload = store.exportPayload()
        XCTAssertEqual(payload.customSymptoms, [CustomSymptom(id: fog, name: "Fog", sort: 0)])
        XCTAssertEqual(payload.symptomScores, [kept])
        XCTAssertNil(store.lastError)
    }

    func testSecondRefreshKeepsTheRetargetedScore() throws {
        let harness = try foldedPair(name: "late-score-stable", suite: "perimedi.late-score-stable")
        let kept = insertLateScore(harness.container)
        harness.store.refresh()
        XCTAssertEqual(harness.store.symptomScores, [kept])
        harness.store.refresh()
        XCTAssertEqual(harness.store.symptomScores, [kept])
        XCTAssertEqual(harness.store.customSymptoms, [CustomSymptom(id: fog, name: "Fog", sort: 0)])
        XCTAssertEqual(harness.store.exportPayload().symptomScores, [kept])
        XCTAssertNil(harness.store.lastError)
    }

    func testRememberedPairsSurviveANewStore() throws {
        let harness = try foldedPair(name: "late-score-survive", suite: "perimedi.late-score-survive")
        XCTAssertEqual(harness.store.customSymptoms, [CustomSymptom(id: fog, name: "Fog", sort: 0)])
        let second = Store(container: harness.container, foldDefaults: harness.defaults)
        let kept = insertLateScore(harness.container)
        second.refresh()
        XCTAssertEqual(second.symptomScores, [kept])
        XCTAssertEqual(second.exportPayload().symptomScores, [kept])
        XCTAssertNil(second.lastError)
    }

    func testRefreshKeepsLowestRecordAndLeavesOmittedRows() throws {
        let suite = "perimedi.refresh-keep"
        let blank = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-000000000099")!
        let unknown = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-000000000088")!
        let container = try inMemoryContainer(name: "refresh-keep")
        let context = container.mainContext
        let fogRow = SDCustomSymptom()
        fogRow.apply(CustomSymptom(id: fog, name: "Fog", sort: 0))
        let folded = SDCustomSymptom()
        folded.apply(CustomSymptom(id: later, name: "fog", sort: 1))
        let blankRow = SDCustomSymptom()
        blankRow.apply(CustomSymptom(id: blank, name: "   ", sort: 9))
        let invalid = SDCustomSymptom()
        invalid.id = "not-a-custom"
        invalid.name = "Nope"
        invalid.sort = 4
        let secondKept = SDCustomSymptom()
        secondKept.apply(CustomSymptom(id: fog, name: "Fog", sort: 0))
        for row in [fogRow, folded, blankRow, invalid, secondKept] {
            context.insert(row)
        }
        let tied = "2026-03-15T08:00:00Z"
        let low = SDSymptomScore()
        low.recordId = "a"
        low.apply(SymptomScore(id: later.rawValue, date: "2026-03-15", severity: 2, loggedAt: tied))
        let high = SDSymptomScore()
        high.recordId = "b"
        high.apply(SymptomScore(id: fog.rawValue, date: "2026-03-15", severity: 4, loggedAt: tied))
        let omitted = SDSymptomScore()
        omitted.recordId = "z"
        omitted.apply(SymptomScore(id: unknown.rawValue, date: "2026-03-17", severity: 4, loggedAt: tied))
        for row in [low, high, omitted] {
            context.insert(row)
        }
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let store = Store(container: container, foldDefaults: defaults)

        func assertRows() throws {
            let scores = try context.fetch(FetchDescriptor<SDSymptomScore>())
            XCTAssertEqual(scores.count, 2)
            let keptScore = try XCTUnwrap(scores.first { $0.recordId == "a" })
            XCTAssertEqual(keptScore.symptomId, fog.rawValue)
            XCTAssertEqual(keptScore.severity, 4)
            XCTAssertEqual(keptScore.loggedAt, tied)
            XCTAssertEqual(keptScore.date, "2026-03-15")
            XCTAssertEqual(keptScore.recordId, "a")
            XCTAssertNil(keptScore.count)
            XCTAssertNil(keptScore.note)
            XCTAssertTrue(keptScore.higherIsWorse)
            XCTAssertFalse(scores.contains { $0.recordId == "b" })
            let omittedScore = try XCTUnwrap(scores.first { $0.recordId == "z" })
            XCTAssertEqual(omittedScore.symptomId, unknown.rawValue)
            XCTAssertEqual(omittedScore.severity, 4)

            let customs = try context.fetch(FetchDescriptor<SDCustomSymptom>())
            XCTAssertEqual(customs.count, 4)
            XCTAssertFalse(customs.contains { $0.id == later.rawValue })
            XCTAssertTrue(customs.contains { $0.id == blank.rawValue && $0.name == "   " })
            XCTAssertTrue(customs.contains { $0.id == "not-a-custom" })
            XCTAssertEqual(customs.filter { $0.id == fog.rawValue }.count, 2)
        }

        try assertRows()
        store.refresh()
        try assertRows()
        XCTAssertNil(store.lastError)
    }

    func testMalformedRememberedPairsFallBackToNone() throws {
        let container = try inMemoryContainer(name: "late-score-malformed")
        let context = container.mainContext
        let symptom = SDCustomSymptom()
        symptom.apply(CustomSymptom(id: fog, name: "Fog", sort: 0))
        context.insert(symptom)
        let kept = SymptomScore(
            id: fog.rawValue,
            date: "2026-03-15",
            severity: 2,
            loggedAt: "2026-03-15T08:00:00Z"
        )
        let late = SymptomScore(
            id: later.rawValue,
            date: "2026-03-17",
            severity: 4,
            loggedAt: "2026-03-17T09:00:00Z"
        )
        for score in [kept, late] {
            let row = SDSymptomScore()
            row.apply(score)
            context.insert(row)
        }
        let suite = "perimedi.late-score-malformed"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defaults.set(
            [later.rawValue: fog.rawValue, "c.00000000-0000-0000-0000-000000000003": 1] as [String: Any],
            forKey: "perimedi.rememberedScoreRewrites"
        )
        let store = Store(container: container, foldDefaults: defaults)
        XCTAssertEqual(store.symptomScores, [kept])
        XCTAssertNil(store.lastError)
    }

    func testEmptyOrSharedRecordIdKeepsTheOtherDay() throws {
        try assertSharedRecordKeepsBothDays(recordId: "", name: "empty-record-id", suite: "perimedi.empty-record-id")
        try assertSharedRecordKeepsBothDays(recordId: "same-row", name: "shared-record-id", suite: "perimedi.shared-record-id")
    }

    func testImportOfSameNamedSymptomsKeepsALaterScore() throws {
        let prior = CustomSymptomId(rawValue: "c.00000000-0000-0000-0000-000000000003")!
        let suite = "perimedi.import-same-name"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defaults.set(
            [prior.rawValue: fog.rawValue],
            forKey: "perimedi.rememberedScoreRewrites"
        )
        let container = try inMemoryContainer(name: "import-same-name")
        let store = Store(container: container, foldDefaults: defaults)
        let imported = SymptomScore(
            id: later.rawValue,
            date: "2026-03-16",
            severity: 3,
            loggedAt: "2026-03-16T08:00:00Z"
        )
        let omitted = SymptomScore(
            id: prior.rawValue,
            date: "2026-03-18",
            severity: 1,
            loggedAt: "2026-03-18T08:00:00Z"
        )
        try store.replaceAll(with: ExportPayload(
            exportedAt: "2026-03-16T12:00:00Z",
            medications: [],
            schedules: [],
            doseLogs: [],
            remarks: [],
            cycleSettings: .default,
            periods: [],
            symptomScores: [imported, omitted],
            customSymptoms: [
                CustomSymptom(id: fog, name: "Fog", sort: 0),
                CustomSymptom(id: later, name: "fog", sort: 1),
            ]
        ))

        let keptImport = SymptomScore(
            id: fog.rawValue,
            date: "2026-03-16",
            severity: 3,
            loggedAt: "2026-03-16T08:00:00Z"
        )
        assertDayVisible(store, keptImport, today: "2026-03-20")
        assertDayAbsent(store, "2026-03-18")

        let late = SymptomScore(
            id: later.rawValue,
            date: "2026-03-17",
            severity: 4,
            loggedAt: "2026-03-17T09:00:00Z"
        )
        let stillRemembered = SymptomScore(
            id: prior.rawValue,
            date: "2026-03-19",
            severity: 2,
            loggedAt: "2026-03-19T09:00:00Z"
        )
        insertStoredScore(late, in: container.mainContext)
        insertStoredScore(stillRemembered, in: container.mainContext)
        store.refresh()

        assertDayVisible(
            store,
            SymptomScore(
                id: fog.rawValue,
                date: "2026-03-17",
                severity: 4,
                loggedAt: "2026-03-17T09:00:00Z"
            ),
            today: "2026-03-20"
        )
        assertDayVisible(
            store,
            SymptomScore(
                id: fog.rawValue,
                date: "2026-03-19",
                severity: 2,
                loggedAt: "2026-03-19T09:00:00Z"
            ),
            today: "2026-03-20"
        )
        assertDayAbsent(store, "2026-03-18")
        let report = visitReport(store, today: "2026-03-20")
        XCTAssertEqual(report.symptoms.first { $0.id == fog.rawValue }?.dayCount, 3)
        XCTAssertNil(store.lastError)
    }

    private func assertSharedRecordKeepsBothDays(
        recordId: String,
        name: String,
        suite: String
    ) throws {
        let container = try inMemoryContainer(name: name)
        let context = container.mainContext
        let symptom = SDCustomSymptom()
        symptom.apply(CustomSymptom(id: fog, name: "Fog", sort: 0))
        context.insert(symptom)
        let earlier = SymptomScore(
            id: fog.rawValue,
            date: "2026-03-15",
            severity: 2,
            loggedAt: "2026-03-15T08:00:00Z"
        )
        let laterDay = SymptomScore(
            id: fog.rawValue,
            date: "2026-03-16",
            severity: 3,
            loggedAt: "2026-03-16T08:00:00Z"
        )
        insertCollidingScore(earlier, recordId: recordId, in: context)
        insertCollidingScore(laterDay, recordId: recordId, in: context)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let store = Store(container: container, foldDefaults: defaults)
        store.refresh()

        assertDayVisible(store, earlier, today: "2026-03-16")
        assertDayVisible(store, laterDay, today: "2026-03-16")
        let report = visitReport(store, today: "2026-03-16")
        XCTAssertEqual(report.symptoms.first { $0.id == fog.rawValue }?.dayCount, 2)
        XCTAssertNil(store.lastError)
    }

    private func assertDayVisible(
        _ store: Store,
        _ score: SymptomScore,
        today: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            store.symptomScores.contains(score),
            "missing \(score.date) from the store",
            file: file,
            line: line
        )
        XCTAssertTrue(
            store.exportPayload().symptomScores.contains(score),
            "missing \(score.date) from the export",
            file: file,
            line: line
        )
        let directory = store.symptomDirectory
        let cycle = CycleSnapshot.build(
            selectedDate: "2026-03-16",
            today: today,
            medications: [],
            schedules: [],
            doseLogs: [],
            remarks: [],
            symptomScores: store.symptomScores,
            directory: directory,
            periods: [],
            settings: store.settings
        )
        XCTAssertEqual(marked(cycle.strip, score.date), true, file: file, line: line)
        let month = MonthGridModel.build(
            monthAnchor: DateKeys.parseDateKey("2026-03-16")!,
            selectedDate: "2026-03-16",
            today: today,
            medications: [],
            schedules: [],
            doseLogs: [],
            remarks: [],
            symptomScores: store.symptomScores,
            directory: directory,
            periods: [],
            settings: store.settings
        )
        let cell = monthCell(month, score.date)
        XCTAssertEqual(cell?.hasSymptom, true, file: file, line: line)
        XCTAssertEqual(cell?.scoreSummary, "\(score.severity)", file: file, line: line)
    }

    private func assertDayAbsent(
        _ store: Store,
        _ date: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(store.symptomScores.contains { $0.date == date }, file: file, line: line)
        XCTAssertFalse(store.exportPayload().symptomScores.contains { $0.date == date }, file: file, line: line)
        let directory = store.symptomDirectory
        let cycle = CycleSnapshot.build(
            selectedDate: "2026-03-16",
            today: "2026-03-20",
            medications: [],
            schedules: [],
            doseLogs: [],
            remarks: [],
            symptomScores: store.symptomScores,
            directory: directory,
            periods: [],
            settings: store.settings
        )
        XCTAssertEqual(marked(cycle.strip, date), false, file: file, line: line)
        let month = MonthGridModel.build(
            monthAnchor: DateKeys.parseDateKey("2026-03-16")!,
            selectedDate: "2026-03-16",
            today: "2026-03-20",
            medications: [],
            schedules: [],
            doseLogs: [],
            remarks: [],
            symptomScores: store.symptomScores,
            directory: directory,
            periods: [],
            settings: store.settings
        )
        XCTAssertEqual(monthCell(month, date)?.hasSymptom, false, file: file, line: line)
    }

    private func visitReport(_ store: Store, today: String) -> DoctorVisitReport {
        DoctorVisitLogic.report(
            today: today,
            medications: [],
            schedules: [],
            doseLogs: [],
            periods: [],
            settings: store.settings,
            scores: store.symptomScores,
            changes: [],
            directory: store.symptomDirectory
        )
    }

    private func insertCollidingScore(_ score: SymptomScore, recordId: String, in context: ModelContext) {
        let row = SDSymptomScore()
        row.symptomId = score.id
        row.date = score.date
        row.severity = score.severity
        row.loggedAt = score.loggedAt
        row.higherIsWorse = score.higherIsWorse
        row.recordId = recordId
        context.insert(row)
    }

    private func insertStoredScore(_ score: SymptomScore, in context: ModelContext) {
        let row = SDSymptomScore()
        row.recordId = score.rowId
        row.apply(score)
        context.insert(row)
    }

    private func foldedPair(
        name: String,
        suite: String
    ) throws -> (container: ModelContainer, store: Store, defaults: UserDefaults) {
        let container = try inMemoryContainer(name: name)
        let context = container.mainContext
        for symptom in [
            CustomSymptom(id: fog, name: "Fog", sort: 0),
            CustomSymptom(id: later, name: " FOG ", sort: 1),
        ] {
            let row = SDCustomSymptom()
            row.apply(symptom)
            context.insert(row)
        }
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let store = Store(container: container, foldDefaults: defaults)
        return (container, store, defaults)
    }

    private func inMemoryContainer(name: String) throws -> ModelContainer {
        try ModelContainer(
            for: PersistenceController.schema,
            configurations: [
                ModelConfiguration(
                    name,
                    schema: PersistenceController.schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                ),
            ]
        )
    }

    private func insertLateScore(_ container: ModelContainer) -> SymptomScore {
        let late = SymptomScore(
            id: later.rawValue,
            date: "2026-03-17",
            severity: 4,
            loggedAt: "2026-03-17T09:00:00Z"
        )
        let row = SDSymptomScore()
        row.apply(late)
        container.mainContext.insert(row)
        return SymptomScore(
            id: fog.rawValue,
            date: "2026-03-17",
            severity: 4,
            loggedAt: "2026-03-17T09:00:00Z"
        )
    }

    private func marked(_ strip: [StripDay], _ key: String) -> Bool? {
        strip.first { $0.dateKey == key }?.hasSymptom
    }

    private func monthCell(_ month: MonthGridModel, _ key: String) -> MonthDayCell? {
        month.cells.first { $0.key == key }
    }
}
