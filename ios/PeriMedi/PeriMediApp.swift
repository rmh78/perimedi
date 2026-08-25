import SwiftUI
import SwiftData
import UIKit
import UserNotifications

@main
struct PeriMediApp: App {
    private let container: ModelContainer
    @StateObject private var appModel: AppModel

    @MainActor
    init() {
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            UIView.setAnimationsEnabled(false)
        }
        let container = PersistenceController.makeContainer()
        self.container = container
        let store = Store(container: container)
        let locale = LocaleController()
        let model = AppModel(store: store, locale: locale)
        _appModel = StateObject(wrappedValue: model)
        UNUserNotificationCenter.current().delegate = DoseReminderCenter.shared
        DoseReminderCenter.shared.attach(store: store, app: model)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .environmentObject(appModel.store)
                .environmentObject(appModel.locale)
                .environment(\.locale, appModel.locale.language.locale)
                .environment(\.accessibilityLanguage, appModel.locale.language.rawValue)
        }
        .modelContainer(container)
    }
}

private struct AccessibilityLanguageKey: EnvironmentKey {
    static let defaultValue: String = "en"
}

extension EnvironmentValues {
    var accessibilityLanguage: String {
        get { self[AccessibilityLanguageKey.self] }
        set { self[AccessibilityLanguageKey.self] = newValue }
    }
}
