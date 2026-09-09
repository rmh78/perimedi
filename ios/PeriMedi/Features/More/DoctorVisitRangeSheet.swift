import SwiftUI
import PeriMediDomain

struct DoctorVisitRangeSheet: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.dialogClose) private var dialogClose

    @State private var selectedStart: String?
    @State private var includePrevious = true
    @State private var error: String?

    private var cycles: [LoggedCycle] {
        DoctorVisitLogic.completedCycles(
            today: DateKeys.todayKey(),
            periods: store.periods,
            settings: store.settings
        )
    }

    var body: some View {
        DialogChrome(
            title: app.t("visit.range.sheet"),
            identifier: A11yID.visitRange,
            onClose: { app.closeDialog() }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if cycles.isEmpty {
                    Text(app.t("visit.range.empty"))
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    Text(app.t("visit.range.hint"))
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                    VStack(spacing: 0) {
                        ForEach(Array(cycles.reversed().enumerated()), id: \.element.start) { index, cycle in
                            if index > 0 {
                                Rectangle().fill(Theme.blush100).frame(height: 1)
                            }
                            cycleRow(cycle)
                        }
                    }
                    if previousCycle != nil {
                        Toggle(isOn: $includePrevious) {
                            Text(app.t("visit.range.previous"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        .tint(Theme.blush600)
                        .accessibilityIdentifier(A11yID.visitRangePrevious)
                    }
                }
                if let error {
                    Text(error).font(.caption).foregroundStyle(Theme.blush700)
                }
            }
        } footer: {
            HStack {
                Spacer()
                PillButton(
                    title: app.t("visit.range.continue"),
                    kind: .primary,
                    identifier: A11yID.visitRangeContinue,
                    action: continueToPreview
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .onAppear {
            selectedStart = cycles.last?.start
            includePrevious = cycles.count >= 2
        }
    }

    private var previousCycle: LoggedCycle? {
        guard let selectedStart, let index = cycles.firstIndex(where: { $0.start == selectedStart }), index > 0 else {
            return nil
        }
        return cycles[index - 1]
    }

    private func cycleRow(_ cycle: LoggedCycle) -> some View {
        let selected = selectedStart == cycle.start
        return Button {
            selectedStart = cycle.start
            includePrevious = false
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rangeLabel(cycle))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(app.t("visit.range.completed"))
                        .font(.caption)
                        .foregroundStyle(Theme.inkMuted)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Theme.blush600 : Theme.inkMuted)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(A11yID.visitRangeCycle(cycle.start))
        .accessibilityValue(selected ? "on" : "off")
    }

    private func rangeLabel(_ cycle: LoggedCycle) -> String {
        "\(format(cycle.start)) – \(format(cycle.end))"
    }

    private func format(_ key: String) -> String {
        guard let date = DateKeys.parseDateKey(key) else { return key }
        let formatter = DateFormatter()
        formatter.locale = app.locale.language.locale
        formatter.setLocalizedDateFormatFromTemplate("yMMMd")
        return formatter.string(from: date)
    }

    private func continueToPreview() {
        var selected: [LoggedCycle] = []
        if let selectedStart, let cycle = cycles.first(where: { $0.start == selectedStart }) {
            selected.append(cycle)
            if includePrevious, let previousCycle {
                selected.insert(previousCycle, at: 0)
            }
        }
        do {
            let url = try DoctorVisitShare.file(store: store, app: app, selectedCycles: selected)
            error = nil
            app.visitPdfURL = url
            app.showVisitRange = false
        } catch {
            self.error = app.t("more.visitFailed")
        }
    }
}
