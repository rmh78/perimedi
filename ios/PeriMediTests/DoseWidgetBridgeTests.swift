import SwiftData
import XCTest
import PeriMediDomain
@testable import PeriMedi

@MainActor
final class DoseWidgetBridgeTests: XCTestCase {
    private nonisolated static let foldSuiteName = "perimedi.widget-bridge"

    override func tearDown() {
        DoseWidgetSnapshotFile.refuseNextWrite = false
        DoseWidgetBridge.runOffMain = { body in
            DispatchQueue.global(qos: .utility).async(execute: body)
        }
        UserDefaults(suiteName: Self.foldSuiteName)?.removePersistentDomain(forName: Self.foldSuiteName)
        super.tearDown()
    }

    func testFailedTakeRepublishesTakeWithoutAck() throws {
        let prior = DoseWidgetSnapshotFile.read()
        defer { _ = DoseWidgetSnapshotFile.write(prior) }

        let container = try ModelContainer(
            for: PersistenceController.schema,
            configurations: [
                ModelConfiguration(
                    "widget-bridge",
                    schema: PersistenceController.schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                ),
            ]
        )
        let defaults = try XCTUnwrap(UserDefaults(suiteName: Self.foldSuiteName))
        defaults.removePersistentDomain(forName: Self.foldSuiteName)
        let store = Store(container: container, foldDefaults: defaults)
        let medicationId = "bridge-fail"
        try store.upsertMedication(
            Medication(
                id: medicationId,
                name: "Estrogen",
                form: .PILL,
                doseLabel: "1 mg",
                createdAt: "t"
            )
        )
        try store.upsertSchedule(
            Schedule(
                id: "bridge-fail-schedule",
                medicationId: medicationId,
                daysOfWeek: [],
                timeOfDay: "08:00",
                times: ["08:00"],
                active: true,
                cycleRule: .none
            )
        )

        let locale = LocaleController()
        let today = DateKeys.todayKey()
        var blank = DoseWidgetSnapshot.make(
            chrome: DoseWidgetChrome.make(t: locale.t),
            date: today,
            meds: [],
            nextDate: DateKeys.addDaysKey(today, 1),
            nextMeds: []
        )
        blank.ack = nil
        guard case .visible = DoseWidgetSnapshotFile.write(blank) else {
            XCTFail("blank snapshot was not stored")
            return
        }

        DoseWidgetBridge.install(store: store, locale: locale)
        let reminder = DoseReminderCenter.shared
        let savedStore = reminder.store
        reminder.store = nil
        defer { reminder.store = savedStore }

        XCTAssertThrowsError(try DoseWidgetBridge.takeFromWidget(medicationId))

        let snapshot = DoseWidgetSnapshotFile.read()
        XCTAssertNil(snapshot.ack)
        let face = snapshot.face(at: Date())
        let row = try XCTUnwrap(face.rows.first { $0.medicationId == medicationId })
        guard case .take = row.control else {
            return XCTFail("failed take left \(row.control)")
        }
        XCTAssertFalse(face.showsCheck)
    }

    func testRefusedWidgetWriteAfterTakeDoesNotReload() throws {
        let container = try ModelContainer(
            for: PersistenceController.schema,
            configurations: [
                ModelConfiguration(
                    "widget-bridge-refuse",
                    schema: PersistenceController.schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                ),
            ]
        )
        let defaults = try XCTUnwrap(UserDefaults(suiteName: Self.foldSuiteName))
        defaults.removePersistentDomain(forName: Self.foldSuiteName)
        let store = Store(container: container, foldDefaults: defaults)
        let medicationId = "bridge-refuse"
        try store.upsertMedication(
            Medication(
                id: medicationId,
                name: "Estrogen",
                form: .PILL,
                doseLabel: "1 mg",
                createdAt: "t"
            )
        )
        try store.upsertSchedule(
            Schedule(
                id: "bridge-refuse-schedule",
                medicationId: medicationId,
                daysOfWeek: [],
                timeOfDay: "08:00",
                times: ["08:00"],
                active: true,
                cycleRule: .none
            )
        )

        let reminder = DoseReminderCenter.shared
        let savedStore = reminder.store
        reminder.store = store
        defer { reminder.store = savedStore }

        let locale = LocaleController()
        DoseWidgetBridge.install(store: store, locale: locale)

        var hops = 0
        DoseWidgetBridge.runOffMain = { _ in hops += 1 }
        DoseWidgetBridge.publish()
        XCTAssertEqual(hops, 1)

        DoseWidgetSnapshotFile.refuseNextWrite = true
        XCTAssertEqual(try DoseWidgetBridge.takeFromWidget(medicationId), .taken)
        XCTAssertEqual(hops, 1)
    }
}
