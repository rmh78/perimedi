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
    private var testFire: DispatchWorkItem?
    private var previewPlayer: AVAudioPlayer?

    var masterEnabled: Bool {
        if UserDefaults.standard.object(forKey: Self.masterKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: Self.masterKey)
    }

    private var uiTesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTesting")
    }

    func attach(store: Store, app: AppModel) {
        self.store = store
        self.app = app
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerCategories()
        store.afterChange = { [weak self] in
            self?.refresh()
        }
        refresh()
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
        guard !uiTesting else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
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
        testFire?.cancel()
        testFire = nil
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
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
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        if !masterEnabled {
            let ours = pending.filter { $0.identifier.hasPrefix("dose.") || $0.identifier.hasPrefix("snooze.") }
            center.removePendingNotificationRequests(withIdentifiers: ours.map(\.identifier))
            return
        }
        if let delay = remindInSeconds {
            await scheduleSoon(using: store, delay: delay)
            return
        }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
        else {
            let doseIds = pending.filter { $0.identifier.hasPrefix("dose.") }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: doseIds)
            return
        }

        let slots = ReminderLogic.upcoming(
            now: Date(),
            medications: store.medications,
            schedules: store.schedules,
            doseLogs: store.doseLogs,
            periods: store.periods,
            settings: store.settings
        )
        let desired = Set(slots.map(\.id))
        let existingDose = Set(pending.filter { $0.identifier.hasPrefix("dose.") }.map(\.identifier))
        center.removePendingNotificationRequests(withIdentifiers: Array(existingDose.subtracting(desired)))

        for slot in slots where !existingDose.contains(slot.id) {
            let request = makeRequest(
                id: slot.id,
                title: slot.medicationName,
                body: body(for: slot),
                fireAt: slot.fireAt,
                info: userInfo(for: slot)
            )
            try? await center.add(request)
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
        let request = makeRequest(
            id: soon.id,
            title: soon.medicationName,
            body: body(for: soon),
            fireAt: soon.fireAt,
            info: userInfo(for: soon)
        )
        try? await UNUserNotificationCenter.current().add(request)
        presentAfterDelay(soon, delay: delay)
    }

    private func presentAfterDelay(_ slot: ReminderSlot, delay: Int) {
        testFire?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.present(slot)
        }
        testFire = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(max(1, delay)), execute: work)
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
        testFire?.cancel()
        testFire = nil
        markTaken(
            medicationId: reminder.medicationId,
            scheduleId: reminder.scheduleId,
            date: reminder.date,
            time: reminder.timeOfDay
        )
        app?.pendingReminder = nil
        refresh()
    }

    func snooze(reminder: PendingReminder) {
        app?.pendingReminder = nil
        Task {
            let fireAt = Date().addingTimeInterval(TimeInterval(ReminderLogic.snoozeMinutes * 60))
            let id = ReminderSlot.snoozeId(
                scheduleId: reminder.scheduleId,
                date: reminder.date,
                timeOfDay: reminder.timeOfDay
            )
            let request = makeRequest(
                id: id,
                title: reminder.medicationName,
                body: app?.t("reminder.body", ["dose": reminder.doseLabel, "time": reminder.timeOfDay])
                    ?? "\(reminder.doseLabel) · \(reminder.timeOfDay)",
                fireAt: fireAt,
                info: [
                    "medicationId": reminder.medicationId,
                    "scheduleId": reminder.scheduleId,
                    "date": reminder.date,
                    "timeOfDay": reminder.timeOfDay,
                ]
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    private func body(for slot: ReminderSlot) -> String {
        app?.t("reminder.body", ["dose": slot.doseLabel, "time": slot.timeOfDay])
            ?? "\(slot.doseLabel) · \(slot.timeOfDay)"
    }

    private func userInfo(for slot: ReminderSlot) -> [AnyHashable: Any] {
        [
            "medicationId": slot.medicationId,
            "scheduleId": slot.scheduleId,
            "date": slot.date,
            "timeOfDay": slot.timeOfDay,
        ]
    }

    private func makeRequest(
        id: String,
        title: String,
        body: String,
        fireAt: Date,
        info: [AnyHashable: Any]
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = ReminderSound.current.notificationSound
        content.categoryIdentifier = Self.categoryId
        content.interruptionLevel = .timeSensitive
        content.userInfo = info
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireAt
        )
        let trigger: UNNotificationTrigger
        let interval = fireAt.timeIntervalSinceNow
        if interval > 0, interval < 90 {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
        } else {
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        }
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
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
            markTaken(medicationId: medicationId, scheduleId: scheduleId, date: date, time: time)
        case Self.snoozeAction:
            await snooze(response.notification)
        default:
            app?.selectedDate = date
            app?.selectedTab = .cycle
        }
        refresh()
    }

    private func markTaken(medicationId: String, scheduleId: String, date: String, time: String) {
        guard let store else { return }
        let existingId = store.doseLogs.first { log in
            log.scheduleId == scheduleId
                && DateKeys.toDateKey(log.plannedFor) == date
                && timeFromPlanned(log.plannedFor) == time
        }?.id
        store.setDoseStatus(
            medicationId: medicationId,
            scheduleId: scheduleId,
            date: date,
            timeOfDay: time,
            status: .taken,
            existingLogId: existingId
        )
        let ids = [
            ReminderSlot.doseId(scheduleId: scheduleId, date: date, timeOfDay: time),
            ReminderSlot.snoozeId(scheduleId: scheduleId, date: date, timeOfDay: time),
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    private func timeFromPlanned(_ plannedFor: String) -> String {
        if plannedFor.count >= 16 {
            let start = plannedFor.index(plannedFor.startIndex, offsetBy: 11)
            let end = plannedFor.index(start, offsetBy: 5)
            return String(plannedFor[start..<end])
        }
        return "08:00"
    }

    private func snooze(_ notification: UNNotification) async {
        let info = notification.request.content.userInfo
        let fireAt = Date().addingTimeInterval(TimeInterval(ReminderLogic.snoozeMinutes * 60))
        let scheduleId = info["scheduleId"] as? String ?? ""
        let date = info["date"] as? String ?? ""
        let time = info["timeOfDay"] as? String ?? ""
        let id = ReminderSlot.snoozeId(scheduleId: scheduleId, date: date, timeOfDay: time)
        let request = makeRequest(
            id: id,
            title: notification.request.content.title,
            body: notification.request.content.body,
            fireAt: fireAt,
            info: info
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
