import SwiftUI
import UIKit
import PeriMediDomain

struct RootView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.accessibilityLanguage) private var a11yLang

    var body: some View {
        VStack(spacing: 0) {
            BrandHeader()
                .zIndex(0)
            ZStack {
                tabPane(CycleView(), tab: .cycle)
                if app.selectedTab == .month {
                    MonthView()
                }
                if app.selectedTab == .more {
                    MoreView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(1)
            PillTabBar()
                .zIndex(2)
        }
        .background(Theme.pageBackground)
        .ignoresSafeArea(edges: [.top, .bottom])
        .overlay {
            if app.medSheet != nil || app.showPeriod || app.showSymptom {
                DialogBackdrop(onClose: { app.closeDialog() }) {
                    if let state = app.medSheet {
                        MedicationSheet(isNew: state.isNew, medication: state.medication)
                    } else if app.showPeriod {
                        PeriodSheet(startInAddEditor: app.launchPeriodEditor)
                    } else if app.showSymptom {
                        SymptomSheet(dateKey: app.selectedDate)
                    }
                }
            }
        }
        .overlay {
            if let prompt = app.confirm {
                ConfirmCard(prompt: prompt)
            }
        }
        .overlay {
            if let reminder = app.pendingReminder {
                ReminderCard(reminder: reminder)
            }
        }
        .environment(\.locale, app.locale.language.locale)
        .id(app.locale.language)
        .onAppear {
            applyLaunchFlags()
            DoseReminderCenter.shared.attach(store: store, app: app)
            if ProcessInfo.processInfo.arguments.contains("-clear") {
                DoseReminderCenter.shared.clearAll()
            }
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            app.focusTodayAfterForeground()
            DoseReminderCenter.shared.refresh()
        }
        .onChange(of: app.locale.language) { _, _ in
            DoseReminderCenter.shared.registerCategories()
        }
        .accessibilityHint(a11yLang)
    }

    @ViewBuilder
    private func tabPane<Content: View>(_ view: Content, tab: AppModel.Tab) -> some View {
        let selected = app.selectedTab == tab
        view
            .opacity(selected ? 1 : 0)
            .allowsHitTesting(selected)
            .accessibilityHidden(!selected)
            .zIndex(selected ? 1 : 0)
    }

    private func applyLaunchFlags() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uiTesting") {
            UIView.setAnimationsEnabled(false)
        }
        if args.contains("-en") {
            app.locale.language = .en
        }
        if let today = pinnedToday(from: args) {
            DateKeys.pinnedTodayKey = today
            app.selectedDate = today
        }
        if args.contains("-clear") {
            store.clearAll()
        }
        if args.contains("-loadSample") {
            try? store.loadSample()
        }
        if let step = journeyStep(from: args) {
            let snap = JourneyScript.apply(store: store, step: step)
            app.selectedDate = snap.selectedDate
            app.selectedTab = snap.tab
            app.launchSheet = snap.launchSheet
            app.launchPeriodEditor = snap.openPeriodEditor
        }
        if args.contains("-tabMonth") { app.selectedTab = .month }
        if args.contains("-tabMore") { app.selectedTab = .more }
        if args.contains("-sheetMed") {
            app.medSheet = MedSheetState(isNew: true, medication: nil)
        }
        if args.contains("-sheetPeriod") {
            app.showPeriod = true
            app.launchPeriodEditor = false
        }
        if args.contains("-sheetSymptom") { app.showSymptom = true }
    }

    private func journeyStep(from args: [String]) -> Int? {
        intArg("-journeyStep", from: args)
    }

    private func pinnedToday(from args: [String]) -> String? {
        stringArg("-today", from: args).flatMap { raw in
            DateKeys.parseDateKey(raw).map { DateKeys.toDateKey($0) }
        }
    }

    private func stringArg(_ name: String, from args: [String]) -> String? {
        if let raw = args.first(where: { $0.hasPrefix("\(name)=") }) {
            return String(raw.dropFirst(name.count + 1))
        }
        if let idx = args.firstIndex(of: name), args.indices.contains(idx + 1) {
            return args[idx + 1]
        }
        return nil
    }

    private func intArg(_ name: String, from args: [String]) -> Int? {
        stringArg(name, from: args).flatMap(Int.init)
    }

}
