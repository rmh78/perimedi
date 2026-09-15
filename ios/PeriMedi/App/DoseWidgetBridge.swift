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
        MarkDoseTakenRuntime.run = { identity in
            try DoseReminderCenter.shared.markSlotTaken(identity)
        }
        publish()
    }

    static func publish() {
        guard let store, let locale else { return }
        let chrome = DoseWidgetChrome.make(t: locale.t)
        let snapshot: DoseWidgetSnapshot
        if let dose = NextPendingDose.select(
            now: Date(),
            medications: store.medications,
            schedules: store.schedules,
            doseLogs: store.doseLogs,
            periods: store.periods,
            settings: store.settings
        ) {
            snapshot = DoseWidgetSnapshot.occupied(chrome: chrome, dose: dose)
        } else {
            snapshot = DoseWidgetSnapshot.empty(chrome: chrome)
        }
        try? DoseWidgetSnapshotFile.write(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: DoseWidgetKind.id)
    }
}
