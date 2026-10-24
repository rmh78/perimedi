import SwiftUI
import PeriMediDomain

struct TrendsPickerSheet: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.dialogClose) private var dialogClose
    @AppStorage("perimedi.trends.selected") private var selectedStorage = ""

    var body: some View {
        let storedIds = TrendsSelectionStorage.parse(selectedStorage)
        let result = SymptomTrendLogic.summarize(
            today: DateKeys.todayKey(),
            periods: store.periods,
            settings: store.settings,
            scores: store.symptomScores,
            changes: store.medicationChanges,
            directory: store.symptomDirectory,
            selectedIds: storedIds
        )
        let chart: SymptomTrendChart? = {
            if case .chart(let chart) = result.kind { return chart }
            return nil
        }()
        let ranked = chart?.defaultIds ?? []
        let selectedIds = storedIds ?? ranked
        return DialogChrome(
            title: app.t("trends.sheet"),
            identifier: A11yID.sheetTrends,
            onClose: close
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(store.symptomDirectory.blocks.enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .catalog(let group, let ids):
                        groupTitle(app.t("symptom.group.\(group.rawValue)"), id: group.rawValue)
                        WrappingHStack(spacing: 6, lineSpacing: 6) {
                            ForEach(ids, id: \.self) { id in
                                chip(id.rawValue, title: app.symptomTitle(id.rawValue), selectedIds: selectedIds, ranked: ranked)
                            }
                        }
                    case .custom(let rows):
                        if !rows.isEmpty {
                            groupTitle(app.t("symptom.group.custom"), id: "custom")
                            WrappingHStack(spacing: 6, lineSpacing: 6) {
                                ForEach(rows) { symptom in
                                    chip(symptom.id.rawValue, title: symptom.name, selectedIds: selectedIds, ranked: ranked)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func close() {
        dialogClose()
    }

    private func groupTitle(_ title: String, id: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.inkMuted)
            .textCase(.uppercase)
            .tracking(0.6)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .accessibilityIdentifier(A11yID.trendsGroup(id))
    }

    private func chip(_ id: String, title: String, selectedIds: [String], ranked: [String]) -> some View {
        let on = selectedIds.contains(id)
        let wide = title.count > 22
        return PillButton(
            title: title,
            kind: on ? .primary : .secondary,
            identifier: A11yID.trendsSeries(id),
            fillsWidth: wide,
            lines: wide ? 2 : 1,
            barHeight: 28,
            labelScale: 0.8
        ) {
            let next = SymptomTrendLogic.toggling(
                id,
                in: selectedIds,
                ranked: ranked,
                directory: store.symptomDirectory
            )
            selectedStorage = next.isEmpty ? "-" : next.joined(separator: ",")
        }
        .frame(width: wide ? 220 : nil, alignment: .leading)
        .accessibilityValue(on ? "on" : "off")
    }
}
