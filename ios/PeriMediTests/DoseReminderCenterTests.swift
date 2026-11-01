import SwiftData
import XCTest
import PeriMediDomain
@testable import PeriMedi

@MainActor
final class DoseReminderCenterTests: XCTestCase {
    private var savedStore: Store?
    private var savedMaster: Any?
    private var container: ModelContainer?
    private let held = HeldAdds()

    override func tearDown() async throws {
        let center = DoseReminderCenter.shared
        if let savedStore {
            center.store = savedStore
        }
        if let savedMaster {
            UserDefaults.standard.set(savedMaster, forKey: DoseReminderCenter.masterKey)
        } else {
            UserDefaults.standard.removeObject(forKey: DoseReminderCenter.masterKey)
        }
        ReminderDelivery.resetForTest()
        savedStore = nil
        container = nil
        try await super.tearDown()
    }

    func testTakenSlotHasNoPendingRequestsAfterStaleReschedule() async throws {
        let (center, store, identity, family) = try await heldDose()
        center.setSlotStatuses(
            medicationId: identity.medicationId,
            slots: [
                SlotStatusWrite(
                    scheduleId: identity.scheduleId,
                    date: identity.date,
                    timeOfDay: identity.timeOfDay,
                    existingLogId: nil
                ),
            ],
            status: .taken
        )
        center.refresh()
        for _ in 0..<8 {
            await Task.yield()
            center.finishNotificationWork()
        }

        held.release()
        center.finishNotificationWork()

        let status = logStatus(store, identity: identity)
        let pending = await held.pendingIds()
        XCTAssertEqual(status, .taken)
        XCTAssertTrue(
            pending.isDisjoint(with: family),
            "pending \(pending) still has \(family)"
        )
    }

    func testLaneTakeCancelsReminder() async throws {
        let (center, store, identity, family) = try await heldDose()
        center.setSlotStatuses(
            medicationId: identity.medicationId,
            slots: [
                SlotStatusWrite(
                    scheduleId: identity.scheduleId,
                    date: identity.date,
                    timeOfDay: identity.timeOfDay,
                    existingLogId: nil
                ),
            ],
            status: .taken
        )
        XCTAssertEqual(logStatus(store, identity: identity), .taken)

        held.release()
        center.finishNotificationWork()
        let pending = await held.pendingIds()
        XCTAssertTrue(
            pending.isDisjoint(with: family),
            "pending \(pending) still has \(family)"
        )
    }

    func testSnoozeCancelsThePendingDoseAndSchedulesSnooze() async throws {
        let (center, _, identity, _) = try await heldDose()
        held.release()
        center.finishNotificationWork()
        let doseId = ReminderSlot.doseId(
            scheduleId: identity.scheduleId,
            date: identity.date,
            timeOfDay: identity.timeOfDay
        )
        let pendingBefore = await held.pendingIds()
        XCTAssertTrue(pendingBefore.contains(doseId))

        center.snooze(
            reminder: PendingReminder(
                medicationId: identity.medicationId,
                scheduleId: identity.scheduleId,
                date: identity.date,
                timeOfDay: identity.timeOfDay,
                medicationName: "Estrogen",
                doseLabel: "1 mg"
            )
        )
        center.finishNotificationWork()

        let pending = await held.pendingIds()
        XCTAssertFalse(pending.contains(doseId), "pending \(pending) still has \(doseId)")
        let snoozeId = ReminderSlot.snoozeId(
            scheduleId: identity.scheduleId,
            date: identity.date,
            timeOfDay: identity.timeOfDay
        )
        XCTAssertTrue(held.requestIdentifiers().contains(snoozeId))
    }

    func testLookupTakeIsSavedWhileTheAddIsHeld() async throws {
        let (center, store, identity, family) = try await heldDose()
        let result = try center.markSlotTaken(identity, shownLogId: .lookup)
        let saved = logStatus(store, identity: identity)
        XCTAssertEqual(result, .taken)
        XCTAssertEqual(saved, .taken, "the log was still \(String(describing: saved)) when Take returned")

        held.release()
        center.finishNotificationWork()
        let pending = await held.pendingIds()
        XCTAssertTrue(
            pending.isDisjoint(with: family),
            "pending \(pending) still has \(family)"
        )
    }

    private func heldDose() async throws -> (DoseReminderCenter, Store, PlannedSlotIdentity, Set<String>) {
        let center = DoseReminderCenter.shared
        savedStore = center.store
        savedMaster = UserDefaults.standard.object(forKey: DoseReminderCenter.masterKey)
        UserDefaults.standard.set(true, forKey: DoseReminderCenter.masterKey)

        let container = try ModelContainer(
            for: PersistenceController.schema,
            configurations: [
                ModelConfiguration(
                    "taken-pending-\(UUID().uuidString)",
                    schema: PersistenceController.schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                ),
            ]
        )
        self.container = container
        let store = Store(container: container)
        let medicationId = "taken-pending-med"
        let scheduleId = "taken-pending-schedule"
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
                id: scheduleId,
                medicationId: medicationId,
                daysOfWeek: [],
                timeOfDay: "09:00",
                times: ["09:00"],
                active: true,
                cycleRule: .none
            )
        )
        store.addAfterChange { [weak center] in
            center?.refresh()
        }
        ReminderDelivery.installForTest(
            add: { [held] request, done in held.add(request, done: done) },
            remove: { [held] ids in held.remove(ids) },
            pending: { [held] in await held.pendingIds() },
            auth: { .authorized }
        )
        center.store = store
        center.refresh()
        var request: UNNotificationRequest?
        for _ in 0..<20 {
            await Task.yield()
            center.finishNotificationWork()
            request = held.doseRequests().first { request in
                ReminderDelivery.identity(of: request)?.scheduleId == scheduleId
            }
            if request != nil { break }
        }
        let post = try XCTUnwrap(request, "reschedule did not submit a dose add")
        let identity = try XCTUnwrap(ReminderDelivery.identity(of: post))
        let family = Set(
            ReminderSlot.ids(
                scheduleId: identity.scheduleId,
                date: identity.date,
                timeOfDay: identity.timeOfDay
            )
        )
        return (center, store, identity, family)
    }

    private func logStatus(_ store: Store, identity: PlannedSlotIdentity) -> DoseStatus? {
        let planned = ScheduleLogic.plannedForIso(dateKey: identity.date, timeOfDay: identity.timeOfDay)
        return store.doseLogs.first {
            $0.scheduleId == identity.scheduleId && $0.plannedFor == planned
        }?.status
    }
}

private final class HeldAdds {
    private let lock = NSLock()
    private var pending: Set<String> = []
    private var held: [(UNNotificationRequest, () -> Void)] = []

    func add(_ request: UNNotificationRequest, done: @escaping () -> Void) {
        lock.lock()
        held.append((request, done))
        lock.unlock()
    }

    func remove(_ ids: [String]) {
        lock.lock()
        pending.subtract(ids)
        lock.unlock()
    }

    func pendingIds() async -> Set<String> {
        copyPending()
    }

    private func copyPending() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return pending
    }

    func requestIdentifiers() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return Set(held.map(\.0.identifier))
    }

    func doseRequests() -> [UNNotificationRequest] {
        lock.lock()
        defer { lock.unlock() }
        return held.map(\.0).filter { $0.identifier.hasPrefix("dose.") }
    }

    func release() {
        let batch: [(UNNotificationRequest, () -> Void)]
        lock.lock()
        batch = held
        held = []
        for (request, _) in batch {
            pending.insert(request.identifier)
        }
        lock.unlock()
        for (_, done) in batch {
            done()
        }
    }
}
