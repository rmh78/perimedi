import SwiftData
import XCTest
import PeriMediDomain
@testable import PeriMedi

@MainActor
final class DoseWidgetBridgeTests: XCTestCase {
    func testFailedTakeRepublishesTakeWithoutAck() throws {
        let prior = DoseWidgetSnapshotFile.read()
        defer { try? DoseWidgetSnapshotFile.write(prior) }

        let container = try ModelContainer(
            for: PersistenceController.schema,
            configurations: [ModelConfiguration(schema: PersistenceController.schema, isStoredInMemoryOnly: true)]
        )
        let store = Store(container: container)
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
        try DoseWidgetSnapshotFile.write(blank)

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
}
