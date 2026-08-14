import SwiftUI
import SwiftData

@main
struct PeriMediApp: App {
    private let container: ModelContainer
    @StateObject private var appModel: AppModel

    @MainActor
    init() {
        let container = PersistenceController.makeContainer()
        self.container = container
        let store = Store(container: container)
        let locale = LocaleController()
        _appModel = StateObject(wrappedValue: AppModel(store: store, locale: locale))
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
