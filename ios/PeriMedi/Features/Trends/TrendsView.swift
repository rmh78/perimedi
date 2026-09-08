import SwiftUI
import PeriMediDomain

struct TrendsView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @AppStorage("perimedi.trends.selected") private var selectedStorage = ""
    @State private var selected: SelectedDot?

    private struct SelectedDot: Equatable {
        var id: String
        var point: SymptomTrendPoint
    }

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
        let selectedIds = storedIds ?? chart?.defaultIds ?? []
        ScrollView {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    catalogPicker(selectedIds: selectedIds, ranked: chart?.defaultIds ?? [])
                    switch result.kind {
                    case .hidden, .needCycles:
                        emptyCopy("need-cycles", key: "trends.needCycles")
                    case .noScores:
                        emptyCopy("no-scores", key: "trends.noScores")
                    case .chart(let chart):
                        chartBody(chart)
                    }
                    Text(containerValue(result))
                        .font(.caption2)
                        .foregroundStyle(.clear)
                        .accessibilityIdentifier(A11yID.trendsStatus)
                        .accessibilityValue(containerValue(result))
                }
                .padding(12)
                .accessibilityElement(children: .contain)
            }
            .accessibilityIdentifier(A11yID.trendsScreen)
            .accessibilityElement(children: .contain)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .transaction { $0.animation = nil }
        }
        .scrollIndicators(.hidden)
    }

    private func emptyCopy(_ value: String, key: String) -> some View {
        Text(app.t(key))
            .font(.caption)
            .foregroundStyle(Theme.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(A11yID.trendsEmpty)
            .accessibilityValue(value)
    }

    private func chartBody(_ chart: SymptomTrendChart) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            plot(chart)
            if let selected {
                detail(selected)
            }
            ticks(chart)
        }
    }

    private func catalogPicker(selectedIds: [String], ranked: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(SymptomGroup.allCases, id: \.self) { group in
                Text(app.t("symptom.group.\(group.rawValue)"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkMuted)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .accessibilityIdentifier(A11yID.trendsGroup(group.rawValue))
                WrappingHStack(spacing: 6, lineSpacing: 6) {
                    ForEach(group.ids, id: \.self) { id in
                        seriesChip(id, selectedIds: selectedIds, ranked: ranked)
                    }
                }
            }
        }
    }

    private func seriesChip(
        _ id: SymptomId,
        selectedIds: [String],
        ranked: [String]
    ) -> some View {
        let on = selectedIds.contains(id.rawValue)
        let color = seriesColor(for: id.rawValue, selectedIds: selectedIds)
        return Button {
            let next = SymptomTrendLogic.toggling(id.rawValue, in: selectedIds, ranked: ranked)
            writeStored(next)
            selected = nil
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

    private func writeStored(_ ids: [String]) {
        selectedStorage = ids.isEmpty ? "-" : ids.joined(separator: ",")
    }

    private func plot(_ chart: SymptomTrendChart) -> some View {
        let yMax = max(1, chart.series.flatMap(\.points).map(\.dayCount).max() ?? 1)
        return GeometryReader { geo in
            let plot = CGRect(x: 26, y: 10, width: max(8, geo.size.width - 34), height: max(8, geo.size.height - 36))
            let xs = xPositions(cycles: chart.cycles, in: plot)
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    drawAxes(ctx, plot: plot, yMax: yMax)
                    for (index, series) in chart.series.enumerated() {
                        let color = Self.seriesColors[index % Self.seriesColors.count]
                        for segment in lineSegments(series, cycles: chart.cycles) where segment.count >= 2 {
                            var path = Path()
                            for (i, point) in segment.enumerated() {
                                guard let x = xs[point.cycleStart] else { continue }
                                let y = yPos(point.dayCount, yMax: yMax, plot: plot)
                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                            ctx.stroke(path, with: .color(color.opacity(0.7)), lineWidth: 1.2)
                        }
                    }
                }
                ForEach(Array(chart.series.enumerated()), id: \.element.id) { index, series in
                    ForEach(series.points, id: \.cycleStart) { point in
                        if let x = xs[point.cycleStart] {
                            let y = yPos(point.dayCount, yMax: yMax, plot: plot)
                            let d = dotDiameter(point.meanIntensity)
                            let color = Self.seriesColors[index % Self.seriesColors.count]
                            Button {
                                selected = SelectedDot(id: series.id, point: point)
                            } label: {
                                Circle()
                                    .fill(color)
                                    .frame(width: d, height: d)
                                    .overlay {
                                        if self.selected?.id == series.id,
                                           self.selected?.point.cycleStart == point.cycleStart {
                                            Circle().stroke(Theme.ink, lineWidth: 1.2)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .position(x: x, y: y)
                            .accessibilityLabel(app.t("symptom.id.\(series.id)"))
                            .accessibilityIdentifier(A11yID.trendsDot(series.id, point.cycleStart))
                            .accessibilityValue(
                                "count:\(point.dayCount),mean:\(formatMean(point.meanIntensity))"
                            )
                        }
                    }
                }
                ForEach(chart.cycles, id: \.start) { cycle in
                    if let x = xs[cycle.start] {
                        Text(shortDate(cycle.start))
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.inkMuted)
                            .position(x: x, y: plot.maxY + 12)
                    }
                }
            }
        }
        .frame(height: 168)
        .accessibilityElement(children: .contain)
    }

    private func detail(_ selected: SelectedDot) -> some View {
        let point = selected.point
        let text = app.t("trends.detail", [
            "start": pretty(point.cycleStart),
            "end": pretty(point.cycleEnd),
            "count": "\(point.dayCount)",
            "mean": formatMean(point.meanIntensity),
        ])
        return Text(text)
            .font(.caption)
            .foregroundStyle(Theme.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(A11yID.trendsDetail)
            .accessibilityValue(
                "cycle:\(point.cycleStart),count:\(point.dayCount),mean:\(formatMean(point.meanIntensity))"
            )
    }

    private func ticks(_ chart: SymptomTrendChart) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(chart.ticks, id: \.cycleStart) { tick in
                Text(app.t("trends.tick", [
                    "name": tick.nameSnapshot,
                    "value": tick.newValue,
                    "date": shortDate(tick.cycleStart),
                ]))
                .font(.caption2)
                .foregroundStyle(Theme.inkMuted)
                .accessibilityIdentifier(A11yID.trendsTick(tick.cycleStart))
                .accessibilityValue("\(tick.nameSnapshot):\(tick.newValue)")
            }
        }
    }

    private func containerValue(_ result: SymptomTrendResult) -> String {
        switch result.kind {
        case .hidden, .needCycles:
            return "need-cycles"
        case .noScores:
            return "no-scores"
        case .chart(let chart):
            return "ids:" + chart.series.map(\.id).joined(separator: ",")
        }
    }

    private func xPositions(cycles: [LoggedCycle], in plot: CGRect) -> [String: CGFloat] {
        let n = max(cycles.count, 1)
        let step = n == 1 ? 0 : plot.width / CGFloat(n - 1)
        var map: [String: CGFloat] = [:]
        for (i, cycle) in cycles.enumerated() {
            let x = n == 1 ? plot.midX : plot.minX + CGFloat(i) * step
            map[cycle.start] = x
        }
        return map
    }

    private func yPos(_ count: Int, yMax: Int, plot: CGRect) -> CGFloat {
        let t = CGFloat(count) / CGFloat(yMax)
        return plot.maxY - t * plot.height
    }

    private func dotDiameter(_ mean: Double) -> CGFloat {
        let t = min(1, max(0, (mean - 1) / 3))
        return 8 + CGFloat(t) * 14
    }

    private func lineSegments(
        _ series: SymptomTrendSeries,
        cycles: [LoggedCycle]
    ) -> [[SymptomTrendPoint]] {
        var out: [[SymptomTrendPoint]] = []
        var current: [SymptomTrendPoint] = []
        for cycle in cycles {
            if let point = series.points.first(where: { $0.cycleStart == cycle.start }) {
                current.append(point)
            } else if !current.isEmpty {
                out.append(current)
                current = []
            }
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    private func drawAxes(_ ctx: GraphicsContext, plot: CGRect, yMax: Int) {
        var axis = Path()
        axis.move(to: CGPoint(x: plot.minX, y: plot.minY))
        axis.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
        axis.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        ctx.stroke(axis, with: .color(Theme.inkMuted.opacity(0.35)), lineWidth: 0.8)
        let labels = [0, yMax]
        for value in labels {
            let y = yPos(value, yMax: yMax, plot: plot)
            let text = Text("\(value)")
                .font(.system(size: 9))
                .foregroundColor(Theme.inkMuted)
            ctx.draw(text, at: CGPoint(x: plot.minX - 12, y: y), anchor: .center)
        }
    }

    private func formatMean(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if abs(rounded - rounded.rounded()) < 0.05 {
            return "\(Int(rounded.rounded()))"
        }
        return String(format: "%.1f", rounded)
    }

    private func pretty(_ key: String) -> String {
        guard let date = DateKeys.parseDateKey(key) else { return key }
        let f = DateFormatter()
        f.locale = app.locale.language.locale
        f.setLocalizedDateFormatFromTemplate("MMMMd yyyy")
        return f.string(from: date)
    }

    private func shortDate(_ key: String) -> String {
        guard let date = DateKeys.parseDateKey(key) else { return key }
        let f = DateFormatter()
        f.locale = app.locale.language.locale
        f.setLocalizedDateFormatFromTemplate("d MMM")
        return f.string(from: date)
    }
}
