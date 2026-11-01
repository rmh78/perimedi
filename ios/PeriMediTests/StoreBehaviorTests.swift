import SwiftData
import XCTest
import PeriMediDomain
@testable import PeriMedi

@MainActor
final class StoreBehaviorTests: XCTestCase {
    func testBackupV1RoundTripMatchesFixtureAfterWipe() throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tests/PeriMediDomainTests/Fixtures/export-v1.json")
        let fixture = try BackupCodec.decode(Data(contentsOf: fixtureURL))
        let suite = "perimedi.backup-v1-round-trip"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let container = try Self.memoryContainer(name: "backup-v1-round-trip")
        let store = Store(container: container, foldDefaults: defaults)
        try store.replaceAll(with: fixture)
        let exported = store.exportPayload()
        XCTAssertEqual(Self.aligned(exported, exportedAt: fixture.exportedAt), Self.aligned(fixture, exportedAt: fixture.exportedAt))

        try store.clearAll()
        XCTAssertEqual(store.medications, [])
        XCTAssertEqual(store.schedules, [])
        XCTAssertEqual(store.doseLogs, [])
        XCTAssertEqual(store.remarks, [])
        XCTAssertEqual(store.periods, [])
        XCTAssertEqual(store.symptomScores, [])

        try store.replaceAll(with: exported)
        let again = store.exportPayload()
        XCTAssertEqual(Self.aligned(again, exportedAt: exported.exportedAt), Self.aligned(exported, exportedAt: exported.exportedAt))
        XCTAssertNil(store.lastError)
    }

    func testPreviousSchemaOpensAndRowsSurvive() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("perimedi-previous-schema-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let storeURL = root.appendingPathComponent("Previous.store")
        let previous = Schema([
            SDMedication.self,
            SDSchedule.self,
            SDDoseLog.self,
            SDRemark.self,
            SDSymptomScore.self,
            SDPeriod.self,
            SDCycleSettings.self,
        ])
        try Self.writePreviousStore(schema: previous, url: storeURL)

        let current = ModelConfiguration(
            "current",
            schema: PersistenceController.schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: PersistenceController.schema, configurations: [current])
        let suite = "perimedi.previous-schema"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = Store(container: container, foldDefaults: defaults)
        XCTAssertEqual(store.medications.map(\.name), ["Estradiol gel"])
        XCTAssertEqual(store.periods.map(\.startDate), ["2026-07-29"])
        XCTAssertEqual(store.customSymptoms, [])
        XCTAssertEqual(store.medicationChanges, [])
        XCTAssertNil(store.lastError)
    }

    private static func writePreviousStore(schema: Schema, url: URL) throws {
        let config = ModelConfiguration(
            "previous",
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let medication = SDMedication()
        medication.apply(Medication(
            id: "med-e2",
            name: "Estradiol gel",
            form: .CREAM,
            doseLabel: "1 pump",
            createdAt: "2026-08-07T12:00:00.000Z"
        ))
        context.insert(medication)
        let period = SDPeriod()
        period.apply(Period(id: "per-1", startDate: "2026-07-29", endDate: "2026-08-02", flowNote: .light))
        context.insert(period)
        let settings = SDCycleSettings()
        settings.apply(.default)
        context.insert(settings)
        try context.save()
    }

    private static func memoryContainer(name: String) throws -> ModelContainer {
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

    private static func aligned(_ payload: ExportPayload, exportedAt: String) -> ExportPayload {
        var copy = payload
        copy.exportedAt = exportedAt
        copy.medications.sort { $0.id < $1.id }
        copy.schedules.sort { $0.id < $1.id }
        copy.doseLogs.sort { $0.id < $1.id }
        copy.remarks.sort { $0.id < $1.id }
        copy.periods.sort { $0.id < $1.id }
        copy.symptomScores.sort { $0.date < $1.date }
        copy.medicationChanges.sort { $0.id < $1.id }
        copy.customSymptoms.sort { $0.id.rawValue < $1.id.rawValue }
        return copy
    }
}
