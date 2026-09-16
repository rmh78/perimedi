import WidgetKit
import PeriMediDomain

@MainActor
enum DoseWidgetBridge {
    private static weak var store: Store?
    private static weak var locale: LocaleController?

    static func install(store: Store, locale: LocaleController) {
        self.store = store
        self.locale = locale
        store.addAfterChange { publish() }
        locale.addOnLanguageChange { publish() }
        MarkTodayMedicationTakenRuntime.run = { medicationId in
            try DoseReminderCenter.shared.markMedicationTaken(medicationId: medicationId)
        }
        publish()
    }

    static func publish() {
        guard let store, let locale else { return }
        let today = DateKeys.todayKey()
        guard let todayDate = DateKeys.parseDateKey(today) else { return }
        let tomorrowDate = DateKeys.addDays(todayDate, 1)
        let chrome = DoseWidgetChrome.make(t: locale.t)
        func pending(now: Date) -> [TodayPendingMedication] {
            TodayPendingMeds.list(
                now: now,
                medications: store.medications,
                schedules: store.schedules,
                doseLogs: store.doseLogs,
                periods: store.periods,
                settings: store.settings
            )
        }
        let snapshot = DoseWidgetSnapshot.make(
            chrome: chrome,
            date: today,
            meds: pending(now: todayDate),
            nextDate: DateKeys.toDateKey(tomorrowDate),
            nextMeds: pending(now: tomorrowDate)
        )
        try? DoseWidgetSnapshotFile.write(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: DoseWidgetKind.id)
    }
}
