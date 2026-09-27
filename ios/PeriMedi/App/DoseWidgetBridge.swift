import WidgetKit
import PeriMediDomain

@MainActor
enum DoseWidgetBridge {
    private static weak var store: Store?
    private static weak var locale: LocaleController?
    private static var stagedAck: DoseWidgetAck?

    static func install(store: Store, locale: LocaleController) {
        self.store = store
        self.locale = locale
        store.addAfterChange { publish() }
        locale.addOnLanguageChange { publish() }
        MarkTodayMedicationTakenRuntime.run = { medicationId in
            try takeFromWidget(medicationId)
        }
        publish()
    }

    static func takeFromWidget(_ medicationId: String) throws -> MarkMedicationTakenResult {
        let before = pendingToday()
        let result = try DoseReminderCenter.shared.markMedicationTaken(medicationId: medicationId)
        guard result == .taken,
              let index = before.firstIndex(where: { $0.medication.id == medicationId }),
              let row = DoseWidgetSnapshot.rows(from: [before[index]]).first
        else {
            return result
        }
        stagedAck = DoseWidgetAck(
            row: row,
            index: index,
            until: Date().addingTimeInterval(DoseWidgetAck.duration)
        )
        publish()
        return result
    }

    static func publish() {
        guard let store, let locale else { return }
        let today = DateKeys.todayKey()
        guard let todayDate = DateKeys.parseDateKey(today) else { return }
        let tomorrowDate = DateKeys.addDays(todayDate, 1)
        let chrome = DoseWidgetChrome.make(t: locale.t)
        let todayMeds = pending(now: todayDate, store: store)
        var snapshot = DoseWidgetSnapshot.make(
            chrome: chrome,
            date: today,
            meds: todayMeds,
            nextDate: DateKeys.toDateKey(tomorrowDate),
            nextMeds: pending(now: tomorrowDate, store: store)
        )
        snapshot.finishedToday = todayMeds.isEmpty && TodayPendingMeds.hasPlanned(
            now: todayDate,
            medications: store.medications,
            schedules: store.schedules,
            doseLogs: store.doseLogs,
            periods: store.periods,
            settings: store.settings
        )
        let staged = stagedAck
        stagedAck = nil
        if let candidate = staged ?? DoseWidgetSnapshotFile.read().ack {
            snapshot.ack = candidate
            if !snapshot.face(at: Date()).showsCheck {
                snapshot.ack = nil
            }
        }
        try? DoseWidgetSnapshotFile.write(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: DoseWidgetKind.id)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func pendingToday() -> [TodayPendingMedication] {
        guard let store, let today = DateKeys.parseDateKey(DateKeys.todayKey()) else { return [] }
        return pending(now: today, store: store)
    }

    private static func pending(now: Date, store: Store) -> [TodayPendingMedication] {
        TodayPendingMeds.list(
            now: now,
            medications: store.medications,
            schedules: store.schedules,
            doseLogs: store.doseLogs,
            periods: store.periods,
            settings: store.settings
        )
    }
}
