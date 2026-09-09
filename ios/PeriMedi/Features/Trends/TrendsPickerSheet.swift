import SwiftUI
import PeriMediDomain

struct TrendsPickerSheet: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.dialogClose) private var dialogClose
    @AppStorage("perimedi.trends.selected") private var selectedStorage = ""

    private static let seriesColors: [Color] = [
        Color(hex: "#c47f00"),
        Color(hex: "#d43d6c"),
        Color(hex: "#6b5ca5"),
    ]

    var body: some View {
        let storedIds = parseStored()
        let result = SymptomTrendLogic.summarize(
            today: DateKeys.todayKey(),
            periods: store.periods,
            settings: store.settings,
            scores: store.symptomScores,
            changes: store.medicationChanges,
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
                ForEach(SymptomGroup.allCases, id: \.self) { group in
                    Text(app.t("symptom.group.\(group.rawValue)"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkMuted)
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier(A11yID.trendsGroup(group.rawValue))
                    WrappingHStack(spacing: 6, lineSpacing: 6) {
                        ForEach(group.ids, id: \.self) { id in
                            chip(id, selectedIds: selectedIds, ranked: ranked)
                        }
                    }
                }
            }
        }
    }

    private func close() {
        dialogClose()
    }

    private func chip(_ id: SymptomId, selectedIds: [String], ranked: [String]) -> some View {
        let on = selectedIds.contains(id.rawValue)
        let color = seriesColor(for: id.rawValue, selectedIds: selectedIds)
        return Button {
            let next = SymptomTrendLogic.toggling(id.rawValue, in: selectedIds, ranked: ranked)
            selectedStorage = next.isEmpty ? "-" : next.joined(separator: ",")
        } label: {
            HStack(spacing: 4) {
                if on {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                Text(app.t("symptom.id.\(id.rawValue)"))
                    .font(.caption)
                    .foregroundStyle(on ? Theme.ink : Theme.inkSoft)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(on ? color.opacity(0.16) : Theme.blush50))
            .overlay(Capsule().stroke(on ? color.opacity(0.45) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(app.t("symptom.id.\(id.rawValue)"))
        .accessibilityIdentifier(A11yID.trendsSeries(id.rawValue))
        .accessibilityValue(on ? "on" : "off")
    }

    private func seriesColor(for id: String, selectedIds: [String]) -> Color {
        let ordered = SymptomId.allCases.map(\.rawValue).filter { selectedIds.contains($0) }
        let index = ordered.firstIndex(of: id) ?? 0
        return Self.seriesColors[index % Self.seriesColors.count]
    }

    private func parseStored() -> [String]? {
        let raw = selectedStorage.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return nil }
        if raw == "-" { return [] }
        return raw.split(separator: ",").map(String.init)
    }
}
