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

    override func tearDown() {
        UserDefaults(suiteName: Self.foldSuiteName)?.removePersistentDomain(forName: Self.foldSuiteName)
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
        let container = try ModelContainer(
            for: PersistenceController.schema,
            configurations: [ModelConfiguration(schema: PersistenceController.schema, isStoredInMemoryOnly: true)]
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

        let store = Store(container: container)
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

    private func marked(_ strip: [StripDay], _ key: String) -> Bool? {
        strip.first { $0.dateKey == key }?.hasSymptom
    }

    private func monthCell(_ month: MonthGridModel, _ key: String) -> MonthDayCell? {
        month.cells.first { $0.key == key }
    }
}
