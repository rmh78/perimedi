import Foundation
import SwiftUI
import PeriMediDomain

struct ChosenVisit: Equatable {
    var start: String?
    var includePrevious: Bool
}

enum VisitDraft: Equatable {
    case unseeded
    case chosen(ChosenVisit)
}

enum VisitStep: Equatable {
    case picking(VisitDraft)
    case preview(URL, restoring: ChosenVisit)
}

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedDate: String
    @Published var selectedTab: Tab = .cycle
    @Published var launchSheet: String?
    @Published var launchPeriodEditor = false
    @Published var medSheet: MedSheetState?
    @Published var showPeriod = false
    @Published var showSymptom = false
    @Published var showTrendsPicker = false
    @Published private(set) var visit: VisitStep?
    @Published var confirm: ConfirmPrompt?
    @Published var pendingReminder: PendingReminder?
    /// Bumped when Cycle should snap the plot to today (launch / return from background).
    @Published private(set) var todayFocusNonce = 0
    /// Launch flags (`-clear`, `-en`, …) apply once. Language change recreates RootView.
    var didApplyLaunchFlags = false

    enum Tab: Hashable {
        case cycle, trends, month, more
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

    func symptomTitle(_ storageId: String) -> String {
        if let name = store.symptomDirectory.name(for: storageId) {
            return name
        }
        guard SymptomId(rawValue: storageId) != nil else { return "" }
        return t("symptom.id.\(storageId)")
    }

    func symptomLevelWord(_ storageId: String, severity: Int) -> String {
        let key = CustomSymptomId(rawValue: storageId) == nil
            ? "symptom.level.\(storageId).\(severity)"
            : "symptom.level.custom.\(severity)"
        let word = t(key)
        return word == key ? "\(severity)" : word
    }

    func closeDialog() {
        medSheet = nil
        showPeriod = false
        showSymptom = false
        showTrendsPicker = false
        visit = nil
        launchPeriodEditor = false
    }

    var pickingChoice: ChosenVisit? {
        guard case .picking(.chosen(let choice)) = visit else { return nil }
        return choice
    }

    func openVisitPicker() {
        visit = .picking(.unseeded)
    }

    func seedVisitPicker(lastStart: String?, cycleCount: Int) {
        guard case .picking(.unseeded) = visit else { return }
        if cycleCount == 0 || lastStart == nil {
            visit = .picking(.chosen(ChosenVisit(start: nil, includePrevious: false)))
            return
        }
        visit = .picking(.chosen(ChosenVisit(start: lastStart, includePrevious: cycleCount >= 2)))
    }

    func selectVisitCycle(_ start: String) {
        guard case .picking(.chosen) = visit else { return }
        visit = .picking(.chosen(ChosenVisit(start: start, includePrevious: false)))
    }

    func setIncludePrevious(_ on: Bool) {
        guard case .picking(.chosen(var choice)) = visit else { return }
        choice.includePrevious = on
        visit = .picking(.chosen(choice))
    }

    func continueVisit(to url: URL) {
        guard case .picking(.chosen(let choice)) = visit else { return }
        visit = .preview(url, restoring: choice)
    }

    func backToVisitPicker() {
        guard case .preview(_, let restoring) = visit else { return }
        visit = .picking(.chosen(restoring))
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

    var identity: PlannedSlotIdentity {
        PlannedSlotIdentity(
            medicationId: medicationId,
            scheduleId: scheduleId,
            date: date,
            timeOfDay: timeOfDay
        )
    }
}

struct ConfirmPrompt: Identifiable {
    let id = UUID()
    var message: String
    var confirmLabel: String
    var destructive: Bool
    var action: () -> Void
}
