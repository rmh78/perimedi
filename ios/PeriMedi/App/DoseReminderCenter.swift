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
        Self.notificationQueue.async {
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()
        }
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
        let pendingIds = Array(await ReminderDelivery.pendingIdentifiers())
        if !masterEnabled {
            Self.removePending(pendingIds.filter(Self.isReminderRequest))
            return
        }
        let status = await ReminderDelivery.authorization()
        guard ReminderPermissionPolicy.shouldScheduleDoseReminders(
            masterEnabled: true,
            status: status
        ) else {
            Self.removePending(pendingIds.filter(Self.isDoseOrFollow))
            return
        }

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
        // Rebuild every dose request so a broken trigger (no time zone) is not kept.
        Self.removePending(pendingIds.filter(Self.isDoseOrFollow))

        for slot in plan.doses {
            guard let request = makeRequest(
                id: slot.id,
                medicationName: slot.medicationName,
                doseLabel: slot.doseLabel,
                timeOfDay: slot.timeOfDay,
                fireAt: slot.fireAt,
                info: userInfo(for: slot)
            ) else { continue }
            Self.enqueue(request)
        }
        for follow in plan.followUps {
            guard let request = makeRequest(
                id: follow.id,
                medicationName: follow.medicationName,
                doseLabel: follow.doseLabel,
                timeOfDay: follow.timeOfDay,
                fireAt: follow.fireAt,
                info: userInfo(
                    medicationId: follow.medicationId,
                    scheduleId: follow.scheduleId,
                    date: follow.date,
                    timeOfDay: follow.timeOfDay,
                    medicationName: follow.medicationName,
                    doseLabel: follow.doseLabel
                )
            ) else { continue }
            Self.enqueue(request)
        }

        let liveSnooze = ReminderLogic.pendingSnoozeIds(
            now: Date(),
            medications: store.medications,
            schedules: store.schedules,
            doseLogs: store.doseLogs,
            periods: store.periods,
            settings: store.settings
        )
        let staleSnooze = pendingIds.filter { $0.hasPrefix("snooze.") && !liveSnooze.contains($0) }
        if !staleSnooze.isEmpty {
            Self.removePendingAndDelivered(staleSnooze)
        }
    }

    private func scheduleSoon(using store: Store, delay: Int) async {
        guard let slot = ReminderLogic.pending(
            on: DateKeys.todayKey(),
            medications: store.medications,
            schedules: store.schedules,
            doseLogs: store.doseLogs,
            periods: store.periods,
            settings: store.settings
        ).first else { return }
        var soon = slot
        soon.fireAt = Date().addingTimeInterval(TimeInterval(max(1, delay)))
        // The card is in-app. add() on the main actor froze the UI for
        // 286s after Taken while XCTest waited for the app to go idle.
        present(soon)
        if let request = makeRequest(
            id: soon.id,
            medicationName: soon.medicationName,
            doseLabel: soon.doseLabel,
            timeOfDay: soon.timeOfDay,
            fireAt: soon.fireAt,
            info: userInfo(for: soon)
        ) {
            Self.enqueue(request)
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
        _ = try? markSlotTaken(reminder.identity)
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
        do {
            for slot in med.pending {
                try commitTaken(slot.identity, existingLogId: slot.log?.id)
            }
            return .taken
        } catch {
            throw MarkDoseTakenError.saveFailed
        }
    }

    @discardableResult
    func markSlotTaken(
        _ identity: PlannedSlotIdentity,
        shownLogId: ShownLogId = .lookup
    ) throws -> MarkSlotTakenResult {
        guard store != nil else { throw MarkDoseTakenError.saveFailed }
        switch shownLogId {
        case .lookup:
            return try acceptLookup(identity)
        case .shown(let existingLogId):
            try commitTaken(identity, existingLogId: existingLogId)
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

    func finishNotificationWork() {
        Self.notificationQueue.sync {}
    }

    private func acceptLookup(_ identity: PlannedSlotIdentity) throws -> MarkSlotTakenResult {
        guard let store else { return .notPlanned }
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
            try commitTaken(identity, existingLogId: dose.log?.id)
            return .taken
        }
    }

    private func commitTaken(_ identity: PlannedSlotIdentity, existingLogId: String?) throws {
        guard let store else { throw MarkDoseTakenError.saveFailed }
        do {
            try store.setDoseStatus(
                medicationId: identity.medicationId,
                scheduleId: identity.scheduleId,
                date: identity.date,
                timeOfDay: identity.timeOfDay,
                status: .taken,
                existingLogId: existingLogId
            )
        } catch {
            throw MarkDoseTakenError.saveFailed
        }
        retireAndWait(identity)
    }

    private func releaseAndPend(_ identity: PlannedSlotIdentity, existingLogId: String?) {
        Self.notificationQueue.sync {
            ReminderDelivery.release(identity)
        }
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

    private func retireAndWait(_ identity: PlannedSlotIdentity) {
        let ids = ReminderSlot.ids(
            scheduleId: identity.scheduleId,
            date: identity.date,
            timeOfDay: identity.timeOfDay
        )
        Self.notificationQueue.sync {
            ReminderDelivery.retire(identity)
            ReminderDelivery.remove(ids, delivered: true)
        }
    }

    private func cancelNotifications(for identity: PlannedSlotIdentity) {
        retireAndWait(identity)
    }

    /// One serial queue. A concurrent queue let a slow add from an earlier
    /// reschedule land after Taken's cancel, so a taken dose could fire again.
    /// The calls still leave the main actor, because the daemon can block.
    nonisolated private static let notificationQueue = DispatchQueue(
        label: "app.perimedi.notifications",
        qos: .utility
    )

    nonisolated private static func enqueue(_ request: UNNotificationRequest) {
        notificationQueue.async {
            if let slot = ReminderDelivery.identity(of: request), ReminderDelivery.isRetired(slot) {
                return
            }
            ReminderDelivery.add(request) {
                notificationQueue.async {
                    guard
                        let slot = ReminderDelivery.identity(of: request),
                        ReminderDelivery.isRetired(slot)
                    else { return }
                    ReminderDelivery.remove([request.identifier], delivered: true)
                }
            }
        }
    }

    nonisolated private static func removePending(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        notificationQueue.async {
            ReminderDelivery.remove(ids, delivered: false)
        }
    }

    nonisolated private static func removePendingAndDelivered(_ ids: [String]) {
        notificationQueue.async {
            ReminderDelivery.remove(ids, delivered: true)
        }
    }

    nonisolated private static func cancelNotifications(ids: [String]) {
        removePendingAndDelivered(ids)
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

    private func makeRequest(
        id: String,
        medicationName: String,
        doseLabel: String,
        timeOfDay: String,
        fireAt: Date,
        info: [AnyHashable: Any]
    ) -> UNNotificationRequest? {
        guard let kind = ReminderLogic.triggerKind(fireAt: fireAt) else { return nil }
        let content = UNMutableNotificationContent()
        content.title = reminderTitle()
        content.subtitle = medicationName
        content.body = reminderBody(dose: doseLabel, time: timeOfDay)
        content.sound = notificationSound
        content.categoryIdentifier = Self.categoryId
        content.userInfo = info
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
                let remaining = fireAt.timeIntervalSinceNow
                guard remaining > 0 else { return nil }
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, remaining), repeats: false)
            }
        }
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    private var notificationSound: UNNotificationSound {
        let sound = ReminderSound.current
        if let fileName = sound.fileName {
            let stem = (fileName as NSString).deletingPathExtension
            if Bundle.main.url(forResource: stem, withExtension: "caf") != nil {
                return sound.notificationSound
            }
        }
        return .default
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
                )
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
        Self.cancelNotifications(
            ids: ReminderSlot.followUpIds(scheduleId: scheduleId, date: date, timeOfDay: timeOfDay)
        )
        let fireAt = Date().addingTimeInterval(TimeInterval(ReminderLogic.snoozeMinutes * 60))
        let id = ReminderSlot.snoozeId(scheduleId: scheduleId, date: date, timeOfDay: timeOfDay)
        if let request = makeRequest(
            id: id,
            medicationName: medicationName,
            doseLabel: doseLabel,
            timeOfDay: timeOfDay,
            fireAt: fireAt,
            info: info
        ) {
            Self.enqueue(request)
        }
    }

    private func storedFollowUpRaw() -> Int? {
        guard UserDefaults.standard.object(forKey: FollowUpCount.storageKey) != nil else { return nil }
        return UserDefaults.standard.integer(forKey: FollowUpCount.storageKey)
    }

    private static func isReminderRequest(_ id: String) -> Bool {
        id.hasPrefix("dose.") || id.hasPrefix("follow.") || id.hasPrefix("snooze.")
    }

    private static func isDoseOrFollow(_ id: String) -> Bool {
        id.hasPrefix("dose.") || id.hasPrefix("follow.")
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

enum ReminderDelivery {
    private static let lock = NSLock()
    private static var retired = Set<PlannedSlotIdentity>()
    private static var addHook: ((UNNotificationRequest, @escaping () -> Void) -> Void)?
    private static var removeHook: (([String]) -> Void)?
    private static var pendingHook: (() async -> Set<String>)?
    private static var authHook: (() async -> ReminderAuthStatus)?

    static func installForTest(
        add: @escaping (UNNotificationRequest, @escaping () -> Void) -> Void,
        remove: @escaping ([String]) -> Void,
        pending: @escaping () async -> Set<String>,
        auth: @escaping () async -> ReminderAuthStatus
    ) {
        lock.lock()
        addHook = add
        removeHook = remove
        pendingHook = pending
        authHook = auth
        lock.unlock()
    }

    static func resetForTest() {
        lock.lock()
        retired.removeAll()
        addHook = nil
        removeHook = nil
        pendingHook = nil
        authHook = nil
        lock.unlock()
    }

    static func retire(_ slot: PlannedSlotIdentity) {
        lock.lock()
        retired.insert(slot)
        lock.unlock()
    }

    static func release(_ slot: PlannedSlotIdentity) {
        lock.lock()
        retired.remove(slot)
        lock.unlock()
    }

    static func isRetired(_ slot: PlannedSlotIdentity) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return retired.contains(slot)
    }

    static func identity(of request: UNNotificationRequest) -> PlannedSlotIdentity? {
        let info = request.content.userInfo
        guard
            let medicationId = info["medicationId"] as? String,
            let scheduleId = info["scheduleId"] as? String,
            let date = info["date"] as? String,
            let time = info["timeOfDay"] as? String
        else { return nil }
        return PlannedSlotIdentity(
            medicationId: medicationId,
            scheduleId: scheduleId,
            date: date,
            timeOfDay: time
        )
    }

    static func add(_ request: UNNotificationRequest, done: @escaping () -> Void) {
        let hook = locked { addHook }
        if let hook {
            hook(request, done)
            return
        }
        DispatchQueue.global(qos: .utility).async {
            UNUserNotificationCenter.current().add(request) { _ in done() }
        }
    }

    static func remove(_ ids: [String], delivered: Bool) {
        guard !ids.isEmpty else { return }
        let hook = locked { removeHook }
        if let hook {
            hook(ids)
            return
        }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        if delivered {
            center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    static func pendingIdentifiers() async -> Set<String> {
        let hook = locked { pendingHook }
        if let hook { return await hook() }
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return Set(pending.map(\.identifier))
    }

    static func authorization() async -> ReminderAuthStatus {
        let hook = locked { authHook }
        if let hook { return await hook() }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return ReminderAuthStatus(settings.authorizationStatus)
    }

    private static func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
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
