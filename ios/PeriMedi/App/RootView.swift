import SwiftUI
import UIKit
import PeriMediDomain

struct RootView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.accessibilityLanguage) private var a11yLang
    @State private var topBleed: CGFloat = 59

    var body: some View {
        VStack(spacing: 0) {
            BrandHeader(topBleed: topBleed)
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
            PillTabBar()
                .zIndex(2)
        }
        .background(Theme.pageBackground)
        .ignoresSafeArea(edges: [.top, .bottom])
        .environment(\.locale, app.locale.language.locale)
        .id(app.locale.language)
        .onAppear {
            let top = Self.windowTopInset()
            if top > 0 { topBleed = top }
            applyLaunchFlags()
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            app.focusTodayAfterForeground()
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
        if args.contains("-sheetMed") { app.launchSheet = "med" }
        if args.contains("-sheetPeriod") { app.launchSheet = "period" }
        if args.contains("-sheetSymptom") { app.launchSheet = "symptom" }
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

    private static func windowTopInset() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.first?.windows.first
        return window?.safeAreaInsets.top ?? 0
    }
}
