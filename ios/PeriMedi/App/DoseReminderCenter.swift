import AVFoundation
import AudioToolbox
import Foundation
import UIKit
import UserNotifications
import PeriMediDomain

enum ReminderSound: String, CaseIterable, Identifiable {
    case system
    case chime
    case drop
    case pulse

    var id: String { rawValue }
    var fileName: String? {
        switch self {
        case .system: return nil
        case .chime: return "ReminderChime.caf"
        case .drop: return "ReminderDrop.caf"
        case .pulse: return "ReminderPulse.caf"
        }
    }

    var labelKey: String { "reminder.sound.\(rawValue)" }

    static let storageKey = "perimedi.reminderSound"

    static var current: ReminderSound {
        ReminderSound(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }

    var notificationSound: UNNotificationSound {
        if let fileName {
            return UNNotificationSound(named: UNNotificationSoundName(fileName))
        }
        return .default
    }
}

@MainActor
final class DoseReminderCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = DoseReminderCenter()
    static let masterKey = "perimedi.reminders"
    static let categoryId = "dose"
    static let takenAction = "taken"
    static let snoozeAction = "snooze"

    weak var store: Store?
    weak var app: AppModel?
    private var previewPlayer: AVAudioPlayer?
    private let engine = ReminderEngine(poster: SystemReminderPoster())
    private var owedTokens: [UUID: PlannedSlotIdentity] = [:]
    private var lookupToken: [PlannedSlotIdentity: UUID] = [:]

    override init() {
        super.init()
        engine.deliverWrite = { [weak self] owed in
            Task { @MainActor in
                self?.performOwedWrite(owed)
            }
        }
    }

    var masterEnabled: Bool {
        if UserDefaults.standard.object(forKey: Self.masterKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: Self.masterKey)
    }

    private var uiTesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTesting")
    }

    private var didRegisterAfterChange = false

    func attach(store: Store, app: AppModel) {
        self.store = store
        self.app = app
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerCategories()
        if !didRegisterAfterChange {
            didRegisterAfterChange = true
            store.addAfterChange { [weak self] in
                self?.refresh()
            }
        }
        refresh()
        Task { await requestAuthorizationIfNeeded() }
    }

    func registerCategories() {
        let taken = UNNotificationAction(
            identifier: Self.takenAction,
            title: app?.t("reminder.taken") ?? "Taken",
            options: [.authenticationRequired]
        )
        let snooze = UNNotificationAction(
            identifier: Self.snoozeAction,
            title: app?.t("reminder.snooze") ?? "Snooze 10 min",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryId,
            actions: [taken, snooze],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func requestAuthorizationIfNeeded() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let status = ReminderAuthStatus(settings.authorizationStatus)
        guard ReminderPermissionPolicy.shouldRequestAuthorization(
            masterEnabled: masterEnabled,
            status: status,
            uiTesting: uiTesting
        ) else { return }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        refresh()
    }

    /// UI tests pass `-remindIn=N` so the next pending slot fires in N seconds.
    var remindInSeconds: Int? {
        for arg in ProcessInfo.processInfo.arguments where arg.hasPrefix("-remindIn=") {
            return Int(arg.dropFirst("-remindIn=".count))
        }
        return nil
    }

    func refresh() {
        if uiTesting, remindInSeconds == nil {
            clearAll()
            return
        }
        guard let store else { return }
        Task { await reschedule(using: store) }
    }

    func clearAll() {
        engine.enqueue(.clearAll)
    }

    func previewSound(_ sound: ReminderSound) {
        previewPlayer?.stop()
        if let fileName = sound.fileName {
            let stem = (fileName as NSString).deletingPathExtension
            guard let url = Bundle.main.url(forResource: stem, withExtension: "caf") else { return }
            previewPlayer = try? AVAudioPlayer(contentsOf: url)
            previewPlayer?.play()
        } else {
            AudioServicesPlaySystemSound(1007)
        }
    }

    func authorizationDenied() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .denied
    }

    private func reschedule(using store: Store) async {
        if let delay = remindInSeconds {
            await scheduleSoon(using: store, delay: delay)
            return
        }
        let poster = engine.currentPoster()
        let seen = await poster.pendingIdentifiers()
        let status = await poster.authorization()
        let allowed = masterEnabled && ReminderPermissionPolicy.shouldScheduleDoseReminders(
            masterEnabled: true,
            status: status
        )
        let posts: [ReminderPost]
        let preserve: Set<String>
        if allowed {
            let count = FollowUpCount.parsed(storedFollowUpRaw())
            let plan = ReminderLogic.followUpPlan(
                now: Date(),
                count: count,
                stops: ReminderChainStops.load(),
                medications: store.medications,
                schedules: store.schedules,
                doseLogs: store.doseLogs,
                periods: store.periods,
                settings: store.settings
            )
            ReminderChainStops.save(plan.stops)
            posts = reminderPosts(from: plan)
            preserve = ReminderLogic.pendingSnoozeIds(
                now: Date(),
                medications: store.medications,
                schedules: store.schedules,
                doseLogs: store.doseLogs,
                periods: store.periods,
                settings: store.settings
            )
        } else {
            posts = []
            preserve = []
        }
        engine.enqueue(.reconcile(seen: seen, posts: posts, preserve: preserve))
    }

    private func scheduleSoon(using store: Store, delay: Int) async {
        let owed = Set(owedTokens.values)
        guard let slot = ReminderLogic.pending(
            on: DateKeys.todayKey(),
            medications: store.medications,
            schedules: store.schedules,
            doseLogs: store.doseLogs,
            periods: store.periods,
            settings: store.settings
        ).first(where: { !owed.contains($0.identity) }) else { return }
        var soon = slot
        soon.fireAt = Date().addingTimeInterval(TimeInterval(max(1, delay)))
        present(soon)
        if let post = makePost(
            id: soon.id,
            identity: soon.identity,
            medicationName: soon.medicationName,
            doseLabel: soon.doseLabel,
            timeOfDay: soon.timeOfDay,
            fireAt: soon.fireAt,
            info: stringInfo(userInfo(for: soon))
        ) {
            engine.enqueue(.submit(post))
        }
    }

    func presentFromUserInfo(_ info: [AnyHashable: Any]) {
        guard let date = info["date"] as? String,
              let scheduleId = info["scheduleId"] as? String,
              let medicationId = info["medicationId"] as? String,
              let time = info["timeOfDay"] as? String
        else { return }
        let med = store?.medications.first { $0.id == medicationId }
        present(
            ReminderSlot(
                medicationId: medicationId,
                scheduleId: scheduleId,
                date: date,
                timeOfDay: time,
                medicationName: med?.name ?? "",
                doseLabel: med?.doseLabel ?? "",
                fireAt: Date()
            )
        )
    }

    func present(_ slot: ReminderSlot) {
        app?.selectedDate = slot.date
        app?.selectedTab = .cycle
        app?.pendingReminder = PendingReminder(
            medicationId: slot.medicationId,
            scheduleId: slot.scheduleId,
            date: slot.date,
            timeOfDay: slot.timeOfDay,
            medicationName: slot.medicationName,
            doseLabel: slot.doseLabel
        )
    }

    func take(reminder: PendingReminder) {
        _ = try? markSlotTaken(reminder.identity, shownLogId: .lookup)
        app?.pendingReminder = nil
        refresh()
    }

    @discardableResult
    func markMedicationTaken(medicationId: String) throws -> MarkMedicationTakenResult {
        guard let store else { throw MarkDoseTakenError.saveFailed }
        let today = DateKeys.todayKey()
        guard let todayDate = DateKeys.parseDateKey(today) else {
            DoseWidgetBridge.publish()
            return .notPlanned
        }
        let list = TodayPendingMeds.list(
            now: todayDate,
            medications: store.medications,
            schedules: store.schedules,
            doseLogs: store.doseLogs,
            periods: store.periods,
            settings: store.settings
        )
        guard let med = list.first(where: { $0.medication.id == medicationId }) else {
            DoseWidgetBridge.publish()
            return .alreadyTaken
        }
        for slot in med.pending {
            _ = try markSlotTaken(slot.identity, shownLogId: .lookup)
        }
        return .taken
    }

    @discardableResult
    func markSlotTaken(
        _ identity: PlannedSlotIdentity,
        shownLogId: ShownLogId
    ) throws -> MarkSlotTakenResult {
        guard store != nil else { throw MarkDoseTakenError.saveFailed }
        switch shownLogId {
        case .lookup:
            return acceptLookup(identity)
        case .shown(let existingLogId):
            beginTake(identity, existingLogId: existingLogId, dedupeLookup: false)
            return .taken
        }
    }

    func setSlotStatuses(
        medicationId: String,
        slots: [SlotStatusWrite],
        status: DoseStatus
    ) {
        for slot in slots {
            let identity = PlannedSlotIdentity(
                medicationId: medicationId,
                scheduleId: slot.scheduleId,
                date: slot.date,
                timeOfDay: slot.timeOfDay
            )
            switch status {
            case .taken:
                _ = try? markSlotTaken(identity, shownLogId: .shown(slot.existingLogId))
            case .pending:
                releaseAndPend(identity, existingLogId: slot.existingLogId)
            case .skipped:
                break
            }
        }
    }

    func hasOwedTake(medicationId: String) -> Bool {
        owedTokens.values.contains { $0.medicationId == medicationId }
    }

    func adoptPoster(_ poster: ReminderPoster) async {
        engine.setPoster(poster, resetLedger: true)
        await engine.fence()
    }

    func restoreSystemPoster() async {
        engine.setPoster(SystemReminderPoster(), resetLedger: true)
        await engine.fence()
    }

    func finishReminderWork() async {
        await engine.fence()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { cont.resume() }
        }
    }

    private func acceptLookup(_ identity: PlannedSlotIdentity) -> MarkSlotTakenResult {
        guard let store else { return .notPlanned }
        if lookupToken[identity] != nil {
            cancelNotifications(for: identity)
            DoseWidgetBridge.publish()
            return .alreadyTaken
        }
        switch NextPendingDose.resolve(
            identity: identity,
            medications: store.medications,
            schedules: store.schedules,
            doseLogs: store.doseLogs,
            periods: store.periods,
            settings: store.settings
        ) {
        case .missing:
            DoseWidgetBridge.publish()
            return .notPlanned
        case .alreadyTaken:
            cancelNotifications(for: identity)
            DoseWidgetBridge.publish()
            return .alreadyTaken
        case .pending(let dose):
            beginTake(identity, existingLogId: dose.log?.id, dedupeLookup: true)
            return .taken
        }
    }

    private func beginTake(
        _ identity: PlannedSlotIdentity,
        existingLogId: String?,
        dedupeLookup: Bool
    ) {
        let token = UUID()
        owedTokens[token] = identity
        if dedupeLookup {
            lookupToken[identity] = token
        }
        let owed = OwedWrite(token: token, identity: identity, existingLogId: existingLogId)
        engine.enqueue(.retire(owed: owed, ids: slotIds(identity), slot: identity))
    }

    private func releaseAndPend(_ identity: PlannedSlotIdentity, existingLogId: String?) {
        let tokens = Set(owedTokens.compactMap { token, slot in slot == identity ? token : nil })
        for token in tokens {
            owedTokens.removeValue(forKey: token)
        }
        lookupToken.removeValue(forKey: identity)
        engine.enqueue(.release(identity, cancel: tokens))
        guard let store else { return }
        try? store.setDoseStatus(
            medicationId: identity.medicationId,
            scheduleId: identity.scheduleId,
            date: identity.date,
            timeOfDay: identity.timeOfDay,
            status: .pending,
            existingLogId: existingLogId
        )
    }

    private func performOwedWrite(_ owed: OwedWrite) {
        guard owedTokens.removeValue(forKey: owed.token) != nil else {
            engine.enqueue(.dropOwed(owed.token))
            return
        }
        if lookupToken[owed.identity] == owed.token {
            lookupToken.removeValue(forKey: owed.identity)
        }
        guard let store else {
            engine.enqueue(.release(owed.identity, cancel: []))
            engine.enqueue(.dropOwed(owed.token))
            return
        }
        do {
            try store.setDoseStatus(
                medicationId: owed.identity.medicationId,
                scheduleId: owed.identity.scheduleId,
                date: owed.identity.date,
                timeOfDay: owed.identity.timeOfDay,
                status: .taken,
                existingLogId: owed.existingLogId
            )
            engine.enqueue(.dropOwed(owed.token))
        } catch {
            engine.enqueue(.release(owed.identity, cancel: []))
            engine.enqueue(.dropOwed(owed.token))
            DoseWidgetBridge.publish()
        }
    }

    private func cancelNotifications(for identity: PlannedSlotIdentity) {
        engine.enqueue(.retire(owed: nil, ids: slotIds(identity), slot: identity))
    }

    private func slotIds(_ identity: PlannedSlotIdentity) -> [String] {
        ReminderSlot.ids(
            scheduleId: identity.scheduleId,
            date: identity.date,
            timeOfDay: identity.timeOfDay
        )
    }

    func snooze(reminder: PendingReminder) {
        app?.pendingReminder = nil
        snoozeSlot(
            scheduleId: reminder.scheduleId,
            date: reminder.date,
            timeOfDay: reminder.timeOfDay,
            medicationName: reminder.medicationName,
            doseLabel: reminder.doseLabel,
            info: userInfo(
                medicationId: reminder.medicationId,
                scheduleId: reminder.scheduleId,
                date: reminder.date,
                timeOfDay: reminder.timeOfDay,
                medicationName: reminder.medicationName,
                doseLabel: reminder.doseLabel
            )
        )
    }

    private func reminderTitle() -> String {
        app?.t("reminder.title") ?? "Time for your dose"
    }

    private func reminderBody(dose: String, time: String) -> String {
        app?.t("reminder.body", ["dose": dose, "time": time])
            ?? "Take \(dose) · planned \(time). Tap Taken when you’ve taken it."
    }

    private func userInfo(for slot: ReminderSlot) -> [AnyHashable: Any] {
        userInfo(
            medicationId: slot.medicationId,
            scheduleId: slot.scheduleId,
            date: slot.date,
            timeOfDay: slot.timeOfDay,
            medicationName: slot.medicationName,
            doseLabel: slot.doseLabel
        )
    }

    private func userInfo(
        medicationId: String,
        scheduleId: String,
        date: String,
        timeOfDay: String,
        medicationName: String,
        doseLabel: String
    ) -> [AnyHashable: Any] {
        [
            "medicationId": medicationId,
            "scheduleId": scheduleId,
            "date": date,
            "timeOfDay": timeOfDay,
            "medicationName": medicationName,
            "doseLabel": doseLabel,
        ]
    }

    private func reminderPosts(from plan: FollowUpPlan) -> [ReminderPost] {
        var posts: [ReminderPost] = []
        for slot in plan.doses {
            if let post = makePost(
                id: slot.id,
                identity: slot.identity,
                medicationName: slot.medicationName,
                doseLabel: slot.doseLabel,
                timeOfDay: slot.timeOfDay,
                fireAt: slot.fireAt,
                info: stringInfo(userInfo(for: slot))
            ) {
                posts.append(post)
            }
        }
        for follow in plan.followUps {
            let identity = PlannedSlotIdentity(
                medicationId: follow.medicationId,
                scheduleId: follow.scheduleId,
                date: follow.date,
                timeOfDay: follow.timeOfDay
            )
            if let post = makePost(
                id: follow.id,
                identity: identity,
                medicationName: follow.medicationName,
                doseLabel: follow.doseLabel,
                timeOfDay: follow.timeOfDay,
                fireAt: follow.fireAt,
                info: stringInfo(
                    userInfo(
                        medicationId: follow.medicationId,
                        scheduleId: follow.scheduleId,
                        date: follow.date,
                        timeOfDay: follow.timeOfDay,
                        medicationName: follow.medicationName,
                        doseLabel: follow.doseLabel
                    )
                )
            ) {
                posts.append(post)
            }
        }
        return posts
    }

    private func makePost(
        id: String,
        identity: PlannedSlotIdentity,
        medicationName: String,
        doseLabel: String,
        timeOfDay: String,
        fireAt: Date,
        info: [String: String]
    ) -> ReminderPost? {
        guard ReminderLogic.triggerKind(fireAt: fireAt) != nil else { return nil }
        return ReminderPost(
            id: id,
            fireAt: fireAt,
            identity: identity,
            title: reminderTitle(),
            subtitle: medicationName,
            body: reminderBody(dose: doseLabel, time: timeOfDay),
            soundName: currentSoundName(),
            userInfo: info
        )
    }

    private func currentSoundName() -> String? {
        let sound = ReminderSound.current
        guard let fileName = sound.fileName else { return nil }
        let stem = (fileName as NSString).deletingPathExtension
        guard Bundle.main.url(forResource: stem, withExtension: "caf") != nil else { return nil }
        return fileName
    }

    private func stringInfo(_ info: [AnyHashable: Any]) -> [String: String] {
        var out: [String: String] = [:]
        for (key, value) in info {
            guard let key = key as? String, let value = value as? String else { continue }
            out[key] = value
        }
        return out
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let testing = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        completionHandler(testing ? [] : [.banner, .sound, .list])
        guard testing else { return }
        let info = notification.request.content.userInfo
        Task { @MainActor in
            DoseReminderCenter.shared.presentFromUserInfo(info)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            await handle(response)
            completionHandler()
        }
    }

    private func handle(_ response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard let date = info["date"] as? String,
              let scheduleId = info["scheduleId"] as? String,
              let medicationId = info["medicationId"] as? String,
              let time = info["timeOfDay"] as? String
        else { return }

        switch response.actionIdentifier {
        case Self.takenAction:
            try? markSlotTaken(
                PlannedSlotIdentity(
                    medicationId: medicationId,
                    scheduleId: scheduleId,
                    date: date,
                    timeOfDay: time
                ),
                shownLogId: .lookup
            )
        case Self.snoozeAction:
            await snooze(response.notification)
        default:
            app?.selectedDate = date
            app?.selectedTab = .cycle
        }
        refresh()
    }

    private func snooze(_ notification: UNNotification) async {
        let info = notification.request.content.userInfo
        let scheduleId = info["scheduleId"] as? String ?? ""
        let date = info["date"] as? String ?? ""
        let time = info["timeOfDay"] as? String ?? ""
        let medicationName = (info["medicationName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? {
                let subtitle = notification.request.content.subtitle
                return subtitle.isEmpty ? notification.request.content.title : subtitle
            }()
        let doseLabel = info["doseLabel"] as? String ?? ""
        snoozeSlot(
            scheduleId: scheduleId,
            date: date,
            timeOfDay: time,
            medicationName: medicationName,
            doseLabel: doseLabel,
            info: info
        )
    }

    private func snoozeSlot(
        scheduleId: String,
        date: String,
        timeOfDay: String,
        medicationName: String,
        doseLabel: String,
        info: [AnyHashable: Any]
    ) {
        ReminderChainStops.insert(scheduleId: scheduleId, date: date, timeOfDay: timeOfDay)
        let followUps = Set(
            ReminderSlot.followUpIds(scheduleId: scheduleId, date: date, timeOfDay: timeOfDay)
        )
        engine.enqueue(.remove(followUps))
        let fireAt = Date().addingTimeInterval(TimeInterval(ReminderLogic.snoozeMinutes * 60))
        let id = ReminderSlot.snoozeId(scheduleId: scheduleId, date: date, timeOfDay: timeOfDay)
        let strings = stringInfo(info)
        let identity = PlannedSlotIdentity(
            medicationId: strings["medicationId"] ?? "",
            scheduleId: scheduleId,
            date: date,
            timeOfDay: timeOfDay
        )
        if let post = makePost(
            id: id,
            identity: identity,
            medicationName: medicationName,
            doseLabel: doseLabel,
            timeOfDay: timeOfDay,
            fireAt: fireAt,
            info: strings
        ) {
            engine.enqueue(.submit(post))
        }
    }

    private func storedFollowUpRaw() -> Int? {
        guard UserDefaults.standard.object(forKey: FollowUpCount.storageKey) != nil else { return nil }
        return UserDefaults.standard.integer(forKey: FollowUpCount.storageKey)
    }

}

enum ShownLogId: Equatable, Sendable {
    case lookup
    case shown(String?)
}

struct SlotStatusWrite: Equatable, Sendable {
    var scheduleId: String
    var date: String
    var timeOfDay: String
    var existingLogId: String?
}

struct ReminderPost: Equatable, Sendable {
    var id: String
    var fireAt: Date
    var identity: PlannedSlotIdentity
    var title: String
    var subtitle: String
    var body: String
    var soundName: String?
    var userInfo: [String: String]
}

enum ReminderAddResult: Equatable, Sendable {
    case installed
    case failed
}

protocol ReminderPoster: AnyObject {
    func pendingIdentifiers() async -> Set<String>
    func authorization() async -> ReminderAuthStatus
    func add(_ post: ReminderPost, done: @escaping (ReminderAddResult) -> Void)
    func remove(ids: Set<String>)
    func clearAll()
}

private struct OwedWrite: Equatable, Sendable {
    var token: UUID
    var identity: PlannedSlotIdentity
    var existingLogId: String?
}

private struct ReminderLedger {
    var tombstone: Set<PlannedSlotIdentity> = []
    var submitted: Set<String> = []
    var inflight: Set<String> = []
    var owed: [UUID: OwedWrite] = [:]
    var writeScheduled: Set<UUID> = []
    var cancelled: Set<UUID> = []
}

private enum ReminderCommand: Sendable {
    case retire(owed: OwedWrite?, ids: [String], slot: PlannedSlotIdentity)
    case release(PlannedSlotIdentity, cancel: Set<UUID>)
    case reconcile(seen: Set<String>, posts: [ReminderPost], preserve: Set<String>)
    case submit(ReminderPost)
    case remove(Set<String>)
    case clearAll
    case dropOwed(UUID)
}

private final class ReminderEngine: @unchecked Sendable {
    let queue = DispatchQueue(label: "app.perimedi.notifications", qos: .utility)
    private let posterLock = NSLock()
    private var poster: ReminderPoster
    private var ledger = ReminderLedger()
    var deliverWrite: (@Sendable (OwedWrite) -> Void)?

    init(poster: ReminderPoster) {
        self.poster = poster
    }

    func currentPoster() -> ReminderPoster {
        posterLock.lock()
        defer { posterLock.unlock() }
        return poster
    }

    func setPoster(_ poster: ReminderPoster, resetLedger: Bool) {
        posterLock.lock()
        self.poster = poster
        posterLock.unlock()
        if resetLedger {
            queue.async { self.ledger = ReminderLedger() }
        }
    }

    func enqueue(_ command: ReminderCommand) {
        queue.async { self.perform(command) }
    }

    func fence() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async { cont.resume() }
        }
    }

    private func perform(_ command: ReminderCommand) {
        switch command {
        case .retire(let owed, let ids, let slot):
            performRetire(owed: owed, ids: ids, slot: slot)
        case .release(let slot, let cancel):
            performRelease(slot: slot, cancel: cancel)
        case .reconcile(let seen, let posts, let preserve):
            performReconcile(seen: seen, posts: posts, preserve: preserve)
        case .submit(let post):
            submit(post)
        case .remove(let ids):
            performRemove(ids)
        case .clearAll:
            currentPoster().clearAll()
            ledger.submitted.removeAll()
        case .dropOwed(let token):
            ledger.owed.removeValue(forKey: token)
            ledger.writeScheduled.remove(token)
            ledger.cancelled.remove(token)
        }
    }

    private func performRetire(owed: OwedWrite?, ids: [String], slot: PlannedSlotIdentity) {
        if let owed, ledger.cancelled.contains(owed.token) {
            ledger.cancelled.remove(owed.token)
            return
        }
        ledger.tombstone.insert(slot)
        let family = Set(ids)
        let removeIds = family.union(ledger.submitted.intersection(family))
        ledger.submitted.subtract(removeIds)
        if !removeIds.isEmpty {
            currentPoster().remove(ids: removeIds)
        }
        if let owed {
            ledger.owed[owed.token] = owed
            if family.isDisjoint(with: ledger.inflight) {
                scheduleWrite(owed)
            }
        }
    }

    private func performRelease(slot: PlannedSlotIdentity, cancel: Set<UUID>) {
        ledger.tombstone.remove(slot)
        ledger.cancelled.formUnion(cancel)
        for token in cancel {
            ledger.owed.removeValue(forKey: token)
            ledger.writeScheduled.remove(token)
        }
    }

    private func performReconcile(seen: Set<String>, posts: [ReminderPost], preserve: Set<String>) {
        let blocked = tombstoneIds()
        let installing = posts.filter { !ledger.tombstone.contains($0.identity) }
        let keep = Set(installing.map(\.id)).union(preserve.subtracting(blocked))
        let universe = seen.union(ledger.submitted).union(blocked)
        let removeIds = Set(universe.filter(isReminderIdentifier)).subtracting(keep)
        ledger.submitted.subtract(removeIds)
        if !removeIds.isEmpty {
            currentPoster().remove(ids: removeIds)
        }
        for post in installing {
            submit(post)
        }
    }

    private func performRemove(_ ids: Set<String>) {
        guard !ids.isEmpty else { return }
        ledger.submitted.subtract(ids)
        currentPoster().remove(ids: ids)
    }

    private func submit(_ post: ReminderPost) {
        guard !ledger.tombstone.contains(post.identity) else { return }
        ledger.submitted.insert(post.id)
        ledger.inflight.insert(post.id)
        let id = post.id
        let slot = post.identity
        currentPoster().add(post) { [weak self] result in
            self?.queue.async {
                self?.finishAdd(id: id, slot: slot, result: result)
            }
        }
    }

    private func finishAdd(id: String, slot: PlannedSlotIdentity, result: ReminderAddResult) {
        ledger.inflight.remove(id)
        if ledger.tombstone.contains(slot) {
            ledger.submitted.remove(id)
            currentPoster().remove(ids: [id])
        } else if result != .installed {
            ledger.submitted.remove(id)
        }
        let family = Set(
            ReminderSlot.ids(scheduleId: slot.scheduleId, date: slot.date, timeOfDay: slot.timeOfDay)
        )
        guard family.isDisjoint(with: ledger.inflight) else { return }
        for owed in ledger.owed.values where owed.identity == slot {
            scheduleWrite(owed)
        }
    }

    private func scheduleWrite(_ owed: OwedWrite) {
        guard ledger.owed[owed.token] != nil else { return }
        guard ledger.writeScheduled.insert(owed.token).inserted else { return }
        deliverWrite?(owed)
    }

    private func tombstoneIds() -> Set<String> {
        var ids = Set<String>()
        for slot in ledger.tombstone {
            ids.formUnion(
                ReminderSlot.ids(scheduleId: slot.scheduleId, date: slot.date, timeOfDay: slot.timeOfDay)
            )
        }
        return ids
    }
}

private func isReminderIdentifier(_ id: String) -> Bool {
    id.hasPrefix("dose.") || id.hasPrefix("follow.") || id.hasPrefix("snooze.")
}

private final class SystemReminderPoster: ReminderPoster {
    func pendingIdentifiers() async -> Set<String> {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return Set(pending.map(\.identifier))
    }

    func authorization() async -> ReminderAuthStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return ReminderAuthStatus(settings.authorizationStatus)
    }

    func add(_ post: ReminderPost, done: @escaping (ReminderAddResult) -> Void) {
        guard let request = makeRequest(post) else {
            done(.failed)
            return
        }
        UNUserNotificationCenter.current().add(request) { error in
            done(error == nil ? .installed : .failed)
        }
    }

    func remove(ids: Set<String>) {
        guard !ids.isEmpty else { return }
        let list = Array(ids)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: list)
        center.removeDeliveredNotifications(withIdentifiers: list)
    }

    func clearAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    private func makeRequest(_ post: ReminderPost) -> UNNotificationRequest? {
        guard let kind = ReminderLogic.triggerKind(fireAt: post.fireAt) else { return nil }
        let content = UNMutableNotificationContent()
        content.title = post.title
        content.subtitle = post.subtitle
        content.body = post.body
        if let soundName = post.soundName {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
        } else {
            content.sound = .default
        }
        content.categoryIdentifier = DoseReminderCenter.categoryId
        content.userInfo = post.userInfo
        let trigger: UNNotificationTrigger
        switch kind {
        case .timeInterval(let interval):
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        case .calendar(let comps):
            let calendarTrigger = UNCalendarNotificationTrigger(
                dateMatching: comps.dateComponents,
                repeats: false
            )
            if let next = calendarTrigger.nextTriggerDate(), next.timeIntervalSinceNow > 0 {
                trigger = calendarTrigger
            } else {
                let remaining = post.fireAt.timeIntervalSinceNow
                guard remaining > 0 else { return nil }
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, remaining), repeats: false)
            }
        }
        return UNNotificationRequest(identifier: post.id, content: content, trigger: trigger)
    }
}

enum ReminderChainStops {
    static let storageKey = "perimedi.reminderChainStops"

    static func load() -> Set<ReminderChainStop> {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let rows = try? JSONDecoder().decode([ReminderChainStop].self, from: data)
        else { return [] }
        return Set(rows)
    }

    static func save(_ stops: Set<ReminderChainStop>) {
        guard let data = try? JSONEncoder().encode(Array(stops)) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func insert(scheduleId: String, date: String, timeOfDay: String) {
        var stops = load()
        stops.insert(ReminderChainStop(scheduleId: scheduleId, date: date, timeOfDay: timeOfDay))
        save(stops)
    }
}

extension ReminderAuthStatus {
    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .authorized: self = .authorized
        case .provisional: self = .provisional
        case .ephemeral: self = .ephemeral
        @unknown default: self = .denied
        }
    }
}
