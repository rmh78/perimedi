import Foundation
import SwiftUI
import PeriMediDomain

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedDate: String
    @Published var selectedTab: Tab = .cycle
    @Published var launchSheet: String?
    @Published var launchPeriodEditor = false
    @Published var medSheet: MedSheetState?
    @Published var showPeriod = false
    @Published var showSymptom = false
    @Published var confirm: ConfirmPrompt?
    @Published var pendingReminder: PendingReminder?
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

    func closeDialog() {
        medSheet = nil
        showPeriod = false
        showSymptom = false
        launchPeriodEditor = false
    }

    func askConfirm(
        message: String,
        confirmLabel: String,
        destructive: Bool = true,
        action: @escaping () -> Void
    ) {
        confirm = ConfirmPrompt(
            message: message,
            confirmLabel: confirmLabel,
            destructive: destructive,
            action: action
        )
    }

    func dismissConfirm() {
        confirm = nil
    }
}

struct PendingReminder: Identifiable, Equatable {
    var medicationId: String
    var scheduleId: String
    var date: String
    var timeOfDay: String
    var medicationName: String
    var doseLabel: String

    var id: String { "\(scheduleId)|\(date)|\(timeOfDay)" }
}

struct ConfirmPrompt: Identifiable {
    let id = UUID()
    var message: String
    var confirmLabel: String
    var destructive: Bool
    var action: () -> Void
}
