import SwiftData
import XCTest
import PeriMediDomain
@testable import PeriMedi

@MainActor
final class DoseReminderCenterTests: XCTestCase {
    private var savedStore: Store?
    private var savedMaster: Any?

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
        await center.restoreSystemPoster()
        savedStore = nil
        try await super.tearDown()
    }

    func testTakenSlotIsAbsentFromPendingIdsAfterAStaleCenterRead() async throws {
        let center = DoseReminderCenter.shared
        savedStore = center.store
        savedMaster = UserDefaults.standard.object(forKey: DoseReminderCenter.masterKey)
        UserDefaults.standard.set(true, forKey: DoseReminderCenter.masterKey)

        let container = try ModelContainer(
            for: PersistenceController.schema,
            configurations: [
                ModelConfiguration(
                    "taken-pending",
                    schema: PersistenceController.schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                ),
            ]
        )
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

        let poster = WithholdingPoster()
        center.store = store
        await center.adoptPoster(poster)
        center.refresh()
        var dosePost: ReminderPost?
        for _ in 0..<12 {
            await center.finishReminderWork()
            dosePost = poster.dosePosts().first { $0.identity.scheduleId == scheduleId }
            if dosePost != nil { break }
        }
        let post = try XCTUnwrap(dosePost, "reschedule did not submit a dose add")
        let identity = post.identity
        let family = Set(
            ReminderSlot.ids(
                scheduleId: identity.scheduleId,
                date: identity.date,
                timeOfDay: identity.timeOfDay
            )
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
        center.refresh()
        for _ in 0..<8 {
            await center.finishReminderWork()
        }

        poster.releaseAdditions()
        let planned = ScheduleLogic.plannedForIso(dateKey: identity.date, timeOfDay: identity.timeOfDay)
        var pending: Set<String> = []
        var status: DoseStatus?
        for _ in 0..<16 {
            await center.finishReminderWork()
            pending = await poster.pendingIdentifiers()
            status = store.doseLogs.first {
                $0.scheduleId == identity.scheduleId && $0.plannedFor == planned
            }?.status
            if status == .taken && pending.isDisjoint(with: family) { break }
        }

        XCTAssertEqual(status, .taken)
        XCTAssertTrue(
            pending.isDisjoint(with: family),
            "pending \(pending) still has \(family)"
        )
    }

    func testLookupTakeIsSavedWhileTheAddIsHeld() async throws {
        let center = DoseReminderCenter.shared
        savedStore = center.store
        savedMaster = UserDefaults.standard.object(forKey: DoseReminderCenter.masterKey)
        UserDefaults.standard.set(true, forKey: DoseReminderCenter.masterKey)

        let container = try ModelContainer(
            for: PersistenceController.schema,
            configurations: [
                ModelConfiguration(
                    "lookup-take",
                    schema: PersistenceController.schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                ),
            ]
        )
        let store = Store(container: container)
        let medicationId = "lookup-take-med"
        let scheduleId = "lookup-take-schedule"
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

        let poster = WithholdingPoster()
        center.store = store
        await center.adoptPoster(poster)
        center.refresh()
        var dosePost: ReminderPost?
        for _ in 0..<12 {
            await center.finishReminderWork()
            dosePost = poster.dosePosts().first { $0.identity.scheduleId == scheduleId }
            if dosePost != nil { break }
        }
        let post = try XCTUnwrap(dosePost, "reschedule did not submit a dose add")
        let identity = post.identity
        let family = Set(
            ReminderSlot.ids(
                scheduleId: identity.scheduleId,
                date: identity.date,
                timeOfDay: identity.timeOfDay
            )
        )

        let result = try center.markSlotTaken(identity, shownLogId: .lookup)
        let planned = ScheduleLogic.plannedForIso(dateKey: identity.date, timeOfDay: identity.timeOfDay)
        let saved = store.doseLogs.first {
            $0.scheduleId == identity.scheduleId && $0.plannedFor == planned
        }?.status
        XCTAssertEqual(result, .taken)
        XCTAssertEqual(saved, .taken, "the log was still \(String(describing: saved)) when Take returned")

        poster.releaseAdditions()
        var pending: Set<String> = []
        for _ in 0..<16 {
            await center.finishReminderWork()
            pending = await poster.pendingIdentifiers()
            if pending.isDisjoint(with: family) { break }
        }
        XCTAssertTrue(
            pending.isDisjoint(with: family),
            "pending \(pending) still has \(family)"
        )
    }
}

private final class WithholdingPoster: ReminderPoster {
    private let lock = NSLock()
    private var pending: Set<String> = []
    private var withheld: [(ReminderPost, (ReminderAddResult) -> Void)] = []

    func pendingIdentifiers() async -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return pending
    }

    func authorization() async -> ReminderAuthStatus { .authorized }

    func add(_ post: ReminderPost, done: @escaping (ReminderAddResult) -> Void) {
        lock.lock()
        withheld.append((post, done))
        lock.unlock()
    }

    func remove(ids: Set<String>) {
        lock.lock()
        pending.subtract(ids)
        lock.unlock()
    }

    func clearAll() {
        lock.lock()
        pending.removeAll()
        lock.unlock()
    }

    func dosePosts() -> [ReminderPost] {
        lock.lock()
        defer { lock.unlock() }
        return withheld.map(\.0).filter { $0.id.hasPrefix("dose.") }
    }

    func releaseAdditions() {
        let batch: [(ReminderPost, (ReminderAddResult) -> Void)]
        lock.lock()
        batch = withheld
        withheld = []
        for (post, _) in batch {
            pending.insert(post.id)
        }
        lock.unlock()
        for (_, done) in batch {
            done(.installed)
        }
    }
}
