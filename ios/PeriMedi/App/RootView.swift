import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.accessibilityLanguage) private var a11yLang

    var body: some View {
        VStack(spacing: 0) {
            BrandHeader()
            Group {
                switch app.selectedTab {
                case .cycle: CycleView()
                case .month: MonthView()
                case .more: MoreView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            PillTabBar()
        }
        .background(Theme.pageBackground)
        .environment(\.locale, app.locale.language.locale)
        .id(app.locale.language)
        .onAppear {
            applyLaunchFlags()
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
        .accessibilityHint(a11yLang)
    }

    private func applyLaunchFlags() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-en") {
            app.locale.language = .en
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
        if args.contains("-sheetMed") { app.launchSheet = "med" }
        if args.contains("-sheetPeriod") { app.launchSheet = "period" }
        if args.contains("-sheetSymptom") { app.launchSheet = "symptom" }
    }

    private func journeyStep(from args: [String]) -> Int? {
        if let raw = args.first(where: { $0.hasPrefix("-journeyStep=") }) {
            return Int(raw.split(separator: "=").last.map(String.init) ?? "")
        }
        if let idx = args.firstIndex(of: "-journeyStep"), args.indices.contains(idx + 1) {
            return Int(args[idx + 1])
        }
        return nil
    }
}
