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
        let color = seriesColor(for: id, selectedIds: selectedIds)
        return Button {
            let next = SymptomTrendLogic.toggling(
                id,
                in: selectedIds,
                ranked: ranked,
                directory: store.symptomDirectory
            )
            selectedStorage = next.isEmpty ? "-" : next.joined(separator: ",")
        } label: {
            HStack(spacing: 4) {
                if on {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                chipTitle(title, on: on)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(on ? color.opacity(0.16) : Theme.blush50))
            .overlay(Capsule().stroke(on ? color.opacity(0.45) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(A11yID.trendsSeries(id))
        .accessibilityValue(on ? "on" : "off")
    }

    @ViewBuilder
    private func chipTitle(_ title: String, on: Bool) -> some View {
        let text = Text(title)
            .font(.caption)
            .foregroundStyle(on ? Theme.ink : Theme.inkSoft)
            .multilineTextAlignment(.leading)
        if title.count > 22 {
            text
                .lineLimit(2)
                .frame(width: 220, alignment: .leading)
        } else {
            text.lineLimit(1)
        }
    }

    private func seriesColor(for id: String, selectedIds: [String]) -> Color {
        let ordered = store.symptomDirectory.rankedIds.filter { selectedIds.contains($0) }
        let index = ordered.firstIndex(of: id) ?? 0
        return TrendsStyle.seriesColors[index % TrendsStyle.seriesColors.count]
    }
}
