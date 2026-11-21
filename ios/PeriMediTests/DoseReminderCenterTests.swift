import SwiftData
import XCTest
import PeriMediDomain
@testable import PeriMedi

private let reminderWaitSeconds: TimeInterval = 30

@MainActor
final class DoseReminderCenterTests: XCTestCase {
    private var savedStore: Store?
    private var savedMaster: Any?
    private var container: ModelContainer?
    private var refreshTask: Task<Void, Never>?
    private let held = HeldAdds()

    override func tearDown() async throws {
        let center = DoseReminderCenter.shared
        let task = refreshTask
        refreshTask = nil
        await wait(for: task, what: "the test refresh", required: false)
        await finishNotificationWork(what: "notification work")
        ReminderDelivery.resetForTest()
        if let savedStore {
            center.store = savedStore
        }
        if let savedMaster {
            UserDefaults.standard.set(savedMaster, forKey: DoseReminderCenter.masterKey)
        } else {
            UserDefaults.standard.removeObject(forKey: DoseReminderCenter.masterKey)
        }
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
        refreshTask = center.refresh()
        await wait(for: refreshTask, what: "the refresh after the dose was taken")
        await finishNotificationWork(what: "notification work after the taken refresh")

        held.release()
        await finishNotificationWork(what: "notification work after the held adds were released")

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
        await finishNotificationWork(what: "notification work after the held adds were released")
        let pending = await held.pendingIds()
        XCTAssertTrue(
            pending.isDisjoint(with: family),
            "pending \(pending) still has \(family)"
        )
    }

    func testTakeReturnsWhileNotificationRemovalIsStillRunning() async throws {
        let (center, _, identity, _) = try await heldDose()
        let release = DispatchSemaphore(value: 0)
        let finished = Finished()
        let test = name
        ReminderDelivery.installForTest(
            add: { _, done in done() },
            remove: { _ in
                if release.wait(timeout: .now() + reminderWaitSeconds) == .timedOut {
                    XCTFail("\(test) timed out after \(Int(reminderWaitSeconds)) seconds waiting for notification removal to be released")
                }
                finished.mark()
            },
            pending: { [] },
            auth: { .authorized }
        )
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
        XCTAssertFalse(finished.isMarked())
        release.signal()
        await finishNotificationWork(what: "notification removal")
        XCTAssertTrue(finished.isMarked())
    }

    func testPutBackReturnsWhileNotificationRemovalIsStillRunning() async throws {
        let (center, _, identity, _) = try await heldDose()
        let release = DispatchSemaphore(value: 0)
        let finished = Finished()
        let test = name
        ReminderDelivery.installForTest(
            add: { _, done in done() },
            remove: { _ in
                if release.wait(timeout: .now() + reminderWaitSeconds) == .timedOut {
                    XCTFail("\(test) timed out after \(Int(reminderWaitSeconds)) seconds waiting for notification removal to be released")
                }
                finished.mark()
            },
            pending: { [] },
            auth: { .authorized }
        )
        let write = SlotStatusWrite(
            scheduleId: identity.scheduleId,
            date: identity.date,
            timeOfDay: identity.timeOfDay,
            existingLogId: nil
        )
        center.setSlotStatuses(
            medicationId: identity.medicationId,
            slots: [write],
            status: .taken
        )
        center.setSlotStatuses(
            medicationId: identity.medicationId,
            slots: [write],
            status: .pending
        )
        XCTAssertFalse(finished.isMarked())
        release.signal()
        await finishNotificationWork(what: "notification removal")
        XCTAssertTrue(finished.isMarked())
    }

    func testPutBackThenTakeAgainKeepsTheSlotRetired() async throws {
        let (center, store, identity, family) = try await heldDose()
        let gate = OpenGate()
        let test = name
        ReminderDelivery.installForTest(
            add: { [held] request, done in held.add(request, done: done) },
            remove: { [held] ids in
                gate.wait(test: test, what: "the removal gate")
                held.remove(ids)
            },
            pending: { [held] in await held.pendingIds() },
            auth: { .authorized }
        )
        let write = SlotStatusWrite(
            scheduleId: identity.scheduleId,
            date: identity.date,
            timeOfDay: identity.timeOfDay,
            existingLogId: nil
        )
        center.setSlotStatuses(
            medicationId: identity.medicationId,
            slots: [write],
            status: .taken
        )
        center.setSlotStatuses(
            medicationId: identity.medicationId,
            slots: [write],
            status: .pending
        )
        for _ in 0..<12 {
            await Task.yield()
        }
        center.setSlotStatuses(
            medicationId: identity.medicationId,
            slots: [write],
            status: .taken
        )
        let before = held.recordedIdentifiers()
        gate.open()
        await finishNotificationWork(what: "notification work after the removal gate opened")
        let posted = held.recordedIdentifiers().dropFirst(before.count)
        XCTAssertEqual(logStatus(store, identity: identity), .taken)
        XCTAssertTrue(
            ReminderDelivery.isRetired(identity),
            "slot \(identity) was released after it was taken again"
        )
        XCTAssertTrue(
            Set(posted).isDisjoint(with: family),
            "posted \(Array(posted)) for \(family)"
        )
    }

    func testSnoozeCancelsThePendingDoseAndSchedulesSnooze() async throws {
        let (center, _, identity, _) = try await heldDose()
        held.release()
        await finishNotificationWork(what: "notification work after the held adds were released")
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
        await finishNotificationWork(what: "notification work after snooze")

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
        await finishNotificationWork(what: "notification work after the held adds were released")
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
        let medicationId = UUID().uuidString
        let scheduleId = UUID().uuidString
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
        store.addAfterChange { [weak self, weak center] in
            self?.refreshTask = center?.refresh()
        }
        ReminderDelivery.installForTest(
            add: { [held] request, done in held.add(request, done: done) },
            remove: { [held] ids in held.remove(ids) },
            pending: { [held] in await held.pendingIds() },
            auth: { .authorized }
        )
        center.store = store
        let task = center.refresh()
        refreshTask = task
        await wait(for: task, what: "the dose reschedule")
        await finishNotificationWork(what: "notification work after the dose reschedule")
        let request = held.doseRequests().first { request in
            ReminderDelivery.identity(of: request)?.scheduleId == scheduleId
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

    private func wait(
        for task: Task<Void, Never>?,
        what: String,
        required: Bool = true
    ) async {
        guard let task else {
            if required {
                XCTFail("\(name) was waiting for \(what), and refresh did not start")
            }
            return
        }
        let finished = await finishFirst(within: reminderWaitSeconds) { finish in
            Task {
                await task.value
                finish()
            }
        }
        if finished { return }
        XCTFail("\(name) timed out after \(Int(reminderWaitSeconds)) seconds waiting for \(what)")
    }

    private func finishNotificationWork(what: String) async {
        let center = DoseReminderCenter.shared
        let finished = await finishFirst(within: reminderWaitSeconds) { finish in
            DispatchQueue.global(qos: .userInitiated).async {
                center.finishNotificationWork()
                finish()
            }
        }
        if finished { return }
        XCTFail("\(name) timed out after \(Int(reminderWaitSeconds)) seconds waiting for \(what)")
    }

    private func finishFirst(
        within seconds: TimeInterval,
        start: @escaping (@escaping () -> Void) -> Void
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            let once = Once()
            let sleeper = DispatchWorkItem {
                if once.take() {
                    continuation.resume(returning: false)
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds, execute: sleeper)
            start {
                sleeper.cancel()
                if once.take() {
                    continuation.resume(returning: true)
                }
            }
        }
    }

    private func logStatus(_ store: Store, identity: PlannedSlotIdentity) -> DoseStatus? {
        let planned = ScheduleLogic.plannedForIso(dateKey: identity.date, timeOfDay: identity.timeOfDay)
        return store.doseLogs.first {
            $0.scheduleId == identity.scheduleId && $0.plannedFor == planned
        }?.status
    }
}

private final class Once {
    private let lock = NSLock()
    private var taken = false

    func take() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if taken { return false }
        taken = true
        return true
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

    func recordedIdentifiers() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return held.map(\.0.identifier)
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

private final class Finished {
    private let lock = NSLock()
    private var marked = false

    func mark() {
        lock.lock()
        marked = true
        lock.unlock()
    }

    func isMarked() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return marked
    }
}

private final class OpenGate {
    private let lock = NSLock()
    private var opened = false
    private var parked: [DispatchSemaphore] = []

    func wait(test: String, what: String) {
        lock.lock()
        if opened {
            lock.unlock()
            return
        }
        let sem = DispatchSemaphore(value: 0)
        parked.append(sem)
        lock.unlock()
        if sem.wait(timeout: .now() + reminderWaitSeconds) == .timedOut {
            XCTFail("\(test) timed out after \(Int(reminderWaitSeconds)) seconds waiting for \(what)")
        }
    }

    func open() {
        lock.lock()
        opened = true
        let waiting = parked
        parked.removeAll()
        lock.unlock()
        for sem in waiting {
            sem.signal()
        }
    }
}
