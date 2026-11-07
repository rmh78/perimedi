import SwiftUI
import PeriMediDomain
import PeriDesign

struct DoctorVisitRangeSheet: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.dialogClose) private var dialogClose

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
                        .foregroundStyle(PeriColor.inkSoft)
                } else {
                    Text(app.t("visit.range.hint"))
                        .font(.subheadline)
                        .foregroundStyle(PeriColor.inkSoft)
                    VStack(spacing: 0) {
                        ForEach(Array(cycles.reversed().enumerated()), id: \.element.start) { index, cycle in
                            if index > 0 {
                                Rectangle().fill(PeriColor.blush100).frame(height: 1)
                            }
                            cycleRow(cycle)
                        }
                    }
                    if previousCycle != nil {
                        Toggle(isOn: Binding(
                            get: { app.pickingChoice?.includePrevious ?? false },
                            set: { app.setIncludePrevious($0) }
                        )) {
                            Text(app.t("visit.range.previous"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PeriColor.ink)
                        }
                        .tint(PeriColor.blush600)
                        .accessibilityIdentifier(A11yID.visitRangePrevious)
                    }
                }
                if let error {
                    Text(error).font(.caption).foregroundStyle(PeriColor.blush700)
                }
            }
        } footer: {
            DialogActions(
                cancel: DialogAction(
                    id: "cancel",
                    title: app.t("common.cancel"),
                    action: { app.closeDialog() }
                ),
                primary: DialogAction(
                    id: "continue",
                    title: app.t("visit.range.continue"),
                    accessibilityIdentifier: A11yID.visitRangeContinue,
                    action: continueToPreview
                )
            )
            .dialogFooterInset()
        }
        .onAppear {
            app.seedVisitPicker(lastStart: cycles.last?.start, cycleCount: cycles.count)
        }
    }

    private var previousCycle: LoggedCycle? {
        guard let selectedStart = app.pickingChoice?.start,
              let index = cycles.firstIndex(where: { $0.start == selectedStart }),
              index > 0 else {
            return nil
        }
        return cycles[index - 1]
    }

    private func cycleRow(_ cycle: LoggedCycle) -> some View {
        let selected = app.pickingChoice?.start == cycle.start
        return Button {
            app.selectVisitCycle(cycle.start)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(DateCopy.closed(
                        startKey: cycle.start,
                        endKey: cycle.end,
                        locale: app.locale.language.locale
                    ))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PeriColor.ink)
                    Text(app.t("visit.range.completed"))
                        .font(.caption)
                        .foregroundStyle(PeriColor.inkMuted)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? PeriColor.blush600 : PeriColor.inkMuted)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(A11yID.visitRangeCycle(cycle.start))
        .accessibilityValue(selected ? "on" : "off")
    }

    private func continueToPreview() {
        let choice = app.pickingChoice
        var selected: [LoggedCycle] = []
        if let selectedStart = choice?.start, let cycle = cycles.first(where: { $0.start == selectedStart }) {
            selected.append(cycle)
            if choice?.includePrevious == true, let previousCycle {
                selected.insert(previousCycle, at: 0)
            }
        }
        do {
            let url = try DoctorVisitShare.file(store: store, app: app, selectedCycles: selected)
            error = nil
            app.continueVisit(to: url)
        } catch {
            self.error = app.t("more.visitFailed")
        }
    }
}
