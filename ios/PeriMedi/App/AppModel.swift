import Foundation
import SwiftUI
import PeriMediDomain

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedDate: String
    @Published var selectedTab: Tab = .cycle
    @Published var launchSheet: String?
    @Published var launchPeriodEditor = false
    /// Bumped when Cycle should snap the plot to today (launch / return from background).
    @Published private(set) var todayFocusNonce = 0

    enum Tab: Hashable {
        case cycle, month, more
    }

    let store: Store
    let locale: LocaleController

    init(store: Store, locale: LocaleController) {
        self.store = store
        self.locale = locale
        self.selectedDate = DateKeys.todayKey()
    }

    func goToToday() {
        selectedDate = DateKeys.todayKey()
    }

    func focusTodayAfterForeground() {
        goToToday()
        todayFocusNonce += 1
    }

    func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        locale.t(key, vars)
    }
}
