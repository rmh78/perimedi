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
        let status = ReminderAuthStatus(settings.authorizationStatus)
        let ours = pending.filter { $0.identifier.hasPrefix("dose.") || $0.identifier.hasPrefix("snooze.") }
        guard ReminderPermissionPolicy.shouldScheduleDoseReminders(
            masterEnabled: true,
            status: status
        ) else {
            center.removePendingNotificationRequests(withIdentifiers: ours.filter { $0.identifier.hasPrefix("dose.") }.map(\.identifier))
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
        // Rebuild every dose request so a broken trigger (no time zone) is not kept.
        center.removePendingNotificationRequests(
            withIdentifiers: ours.filter { $0.identifier.hasPrefix("dose.") }.map(\.identifier)
        )

        for slot in slots {
            guard let request = makeRequest(
                id: slot.id,
                medicationName: slot.medicationName,
                doseLabel: slot.doseLabel,
                timeOfDay: slot.timeOfDay,
                fireAt: slot.fireAt,
                info: userInfo(for: slot)
            ) else { continue }
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
        if let request = makeRequest(
            id: soon.id,
            medicationName: soon.medicationName,
            doseLabel: soon.doseLabel,
            timeOfDay: soon.timeOfDay,
            fireAt: soon.fireAt,
            info: userInfo(for: soon)
        ) {
            try? await UNUserNotificationCenter.current().add(request)
        }
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
            if let request = makeRequest(
                id: id,
                medicationName: reminder.medicationName,
                doseLabel: reminder.doseLabel,
                timeOfDay: reminder.timeOfDay,
                fireAt: fireAt,
                info: userInfo(
                    medicationId: reminder.medicationId,
                    scheduleId: reminder.scheduleId,
                    date: reminder.date,
                    timeOfDay: reminder.timeOfDay,
                    medicationName: reminder.medicationName,
                    doseLabel: reminder.doseLabel
                )
            ) {
                try? await UNUserNotificationCenter.current().add(request)
            }
        }
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
        try? store.setDoseStatus(
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
        let medicationName = (info["medicationName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? {
                let subtitle = notification.request.content.subtitle
                return subtitle.isEmpty ? notification.request.content.title : subtitle
            }()
        let doseLabel = info["doseLabel"] as? String ?? ""
        if let request = makeRequest(
            id: id,
            medicationName: medicationName,
            doseLabel: doseLabel,
            timeOfDay: time,
            fireAt: fireAt,
            info: info
        ) {
            try? await UNUserNotificationCenter.current().add(request)
        }
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
