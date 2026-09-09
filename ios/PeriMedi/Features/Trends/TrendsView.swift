import SwiftUI
import PeriMediDomain

struct TrendsView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @AppStorage("perimedi.trends.selected") private var selectedStorage = ""
    @State private var selected: SelectedDot?
    @State private var selectedTick: CycleChangeTick?

    private struct SelectedDot: Equatable {
        var id: String
        var point: SymptomTrendPoint
        var colorIndex: Int
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
        ScrollView {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
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
                .frame(maxWidth: .infinity, alignment: .topLeading)
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
        VStack(alignment: .leading, spacing: 6) {
            Text(app.t("\(key)Title"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(app.t(key))
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(A11yID.trendsEmpty)
                .accessibilityValue(value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chartBody(_ chart: SymptomTrendChart) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(app.t("trends.axis"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
                .accessibilityIdentifier(A11yID.trendsAxis)
                .accessibilityValue("days-scored")
            plot(chart)
            legend(chart)
            Text(app.t("trends.sizeKey"))
                .font(.caption2)
                .foregroundStyle(Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(A11yID.trendsSizeKey)
            if let selected {
                detail(selected)
            }
            if let selectedTick {
                tickCopy(selectedTick)
            }
            HStack {
                Spacer(minLength: 0)
                PillButton(
                    title: app.t("trends.change"),
                    kind: .secondary,
                    identifier: A11yID.trendsChange
                ) {
                    app.showTrendsPicker = true
                }
            }
        }
        .onAppear {
            guard ProcessInfo.processInfo.arguments.contains("-trendsTap") else { return }
            guard let series = chart.series.first,
                  let point = series.points.last
            else { return }
            selected = SelectedDot(id: series.id, point: point, colorIndex: 0)
            selectedTick = nil
        }
    }

    private func legend(_ chart: SymptomTrendChart) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(chart.series.enumerated()), id: \.element.id) { index, series in
                let color = Self.seriesColors[index % Self.seriesColors.count]
                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(app.t("symptom.id.\(series.id)"))
                        .font(.caption)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(A11yID.trendsSeries(series.id))
                .accessibilityValue("on")
            }
        }
    }

    private func parseStored() -> [String]? {
        let raw = selectedStorage.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return nil }
        if raw == "-" { return [] }
        return raw.split(separator: ",").map(String.init)
    }

    private func plot(_ chart: SymptomTrendChart) -> some View {
        let yMax = max(1, chart.series.flatMap(\.points).map(\.dayCount).max() ?? 1)
        let n = max(chart.cycles.count, 1)
        return GeometryReader { geo in
            let yAxisW: CGFloat = 28
            let pad: CGFloat = 16
            let trailPad: CGFloat = 32
            let available = max(40, geo.size.width - yAxisW)
            let innerW: CGFloat = {
                if n <= 1 { return max(8, available - pad - trailPad) }
                let fitStep = max(8, available - pad - trailPad) / CGFloat(n - 1)
                return max(72, fitStep) * CGFloat(n - 1)
            }()
            let contentW = innerW + pad + trailPad
            let plot = CGRect(x: pad, y: 10, width: innerW, height: max(8, geo.size.height - 36))
            let xs = xPositions(cycles: chart.cycles, in: plot)
            HStack(alignment: .top, spacing: 0) {
                yAxis(yMax: yMax, plot: plot)
                    .frame(width: yAxisW, height: geo.size.height)
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: contentW > available + 1) {
                        plotBoard(chart, yMax: yMax, plot: plot, xs: xs)
                            .frame(width: contentW, height: geo.size.height)
                            .id("trends-plot-trail")
                    }
                    .accessibilityIdentifier(A11yID.trendsPlot)
                    .onAppear {
                        if contentW > available + 1 {
                            proxy.scrollTo("trends-plot-trail", anchor: .trailing)
                        }
                    }
                }
            }
        }
        .frame(height: 176)
        .accessibilityElement(children: .contain)
    }

    private func yAxis(yMax: Int, plot: CGRect) -> some View {
        ZStack {
            ForEach([0, yMax], id: \.self) { value in
                Text("\(value)")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.inkMuted)
                    .position(x: 12, y: yPos(value, yMax: yMax, plot: plot))
            }
        }
    }

    private func plotBoard(
        _ chart: SymptomTrendChart,
        yMax: Int,
        plot: CGRect,
        xs: [String: CGFloat]
    ) -> some View {
        ZStack(alignment: .topLeading) {
            Canvas { ctx, _ in
                drawAxes(ctx, plot: plot)
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
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    selected = nil
                    selectedTick = nil
                }
            ForEach(Array(chart.series.enumerated()), id: \.element.id) { index, series in
                ForEach(series.points, id: \.cycleStart) { point in
                    if let x = xs[point.cycleStart] {
                        let y = yPos(point.dayCount, yMax: yMax, plot: plot)
                        let d = dotDiameter(point.meanIntensity)
                        let color = Self.seriesColors[index % Self.seriesColors.count]
                        let on = self.selected?.id == series.id
                            && self.selected?.point.cycleStart == point.cycleStart
                        Button {
                            selectDot(
                                SelectedDot(id: series.id, point: point, colorIndex: index),
                                in: chart
                            )
                        } label: {
                            ZStack {
                                if on {
                                    Circle()
                                        .stroke(Theme.ink, lineWidth: 3)
                                        .frame(width: d + 14, height: d + 14)
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                        .frame(width: d + 6, height: d + 6)
                                }
                                Circle()
                                    .fill(color)
                                    .frame(width: d, height: d)
                            }
                            .frame(width: max(d + 16, 28), height: max(d + 16, 28))
                            .shadow(color: on ? color.opacity(0.5) : .clear, radius: on ? 5 : 0)
                            .contentShape(Rectangle())
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
            ForEach(chart.ticks, id: \.cycleStart) { tick in
                if let x = xs[tick.cycleStart] {
                    let on = selectedTick?.cycleStart == tick.cycleStart
                    Button {
                        selectedTick = tick
                        selected = nil
                    } label: {
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(on ? Theme.blush800 : Theme.blush600)
                            .rotationEffect(.degrees(180))
                            .frame(width: 32, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x: x, y: plot.maxY - 10)
                    .accessibilityLabel(tick.nameSnapshot)
                    .accessibilityIdentifier(A11yID.trendsTick(tick.cycleStart))
                    .accessibilityValue("\(tick.nameSnapshot):\(tick.newValue)")
                }
            }
            ForEach(chart.cycles, id: \.start) { cycle in
                if let x = xs[cycle.start] {
                    Text(shortDate(cycle.start))
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.inkMuted)
                        .position(x: x, y: plot.maxY + 12)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private func selectDot(_ candidate: SelectedDot, in chart: SymptomTrendChart) {
        let group = overlappingDots(
            cycleStart: candidate.point.cycleStart,
            dayCount: candidate.point.dayCount,
            chart: chart
        )
        if let selected,
           let idx = group.firstIndex(where: {
               $0.id == selected.id && $0.point.cycleStart == selected.point.cycleStart
           }) {
            self.selected = group[(idx + 1) % group.count]
        } else {
            self.selected = candidate
        }
        selectedTick = nil
    }

    private func overlappingDots(
        cycleStart: String,
        dayCount: Int,
        chart: SymptomTrendChart
    ) -> [SelectedDot] {
        var out: [SelectedDot] = []
        for (index, series) in chart.series.enumerated() {
            if let point = series.points.first(where: {
                $0.cycleStart == cycleStart && $0.dayCount == dayCount
            }) {
                out.append(SelectedDot(id: series.id, point: point, colorIndex: index))
            }
        }
        return out
    }

    private func detail(_ selected: SelectedDot) -> some View {
        let point = selected.point
        let name = app.t("symptom.id.\(selected.id)")
        let color = Self.seriesColors[selected.colorIndex % Self.seriesColors.count]
        let text = app.t("trends.detail", [
            "name": name,
            "start": pretty(point.cycleStart),
            "end": pretty(point.cycleEnd),
            "count": "\(point.dayCount)",
            "mean": formatMean(point.meanIntensity),
        ])
        return HStack(alignment: .top, spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityIdentifier(A11yID.trendsDetail)
        .accessibilityValue(
            "id:\(selected.id),cycle:\(point.cycleStart),count:\(point.dayCount),mean:\(formatMean(point.meanIntensity))"
        )
    }

    private func tickCopy(_ tick: CycleChangeTick) -> some View {
        let key = tick.field == .dose ? "trends.tick.dose" : "trends.tick.schedule"
        let text = app.t(key, [
            "name": tick.nameSnapshot,
            "value": displayDoseValue(tick.newValue),
            "date": tickDate(tick.effectiveDate),
        ])
        return Text(text)
            .font(.caption)
            .foregroundStyle(Theme.inkMuted)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(A11yID.trendsTickCopy)
            .accessibilityValue("\(tick.nameSnapshot):\(tick.newValue)")
    }

    private func displayDoseValue(_ value: String) -> String {
        guard app.locale.language == .de else { return value }
        var out = value
        out = out.replacingOccurrences(of: "pumps", with: "Hub", options: .caseInsensitive)
        out = out.replacingOccurrences(of: "pump", with: "Hub", options: .caseInsensitive)
        return out
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

    private func drawAxes(_ ctx: GraphicsContext, plot: CGRect) {
        var axis = Path()
        axis.move(to: CGPoint(x: plot.minX, y: plot.minY))
        axis.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
        axis.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        ctx.stroke(axis, with: .color(Theme.inkMuted.opacity(0.35)), lineWidth: 0.8)
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

    private func tickDate(_ key: String) -> String {
        guard let date = DateKeys.parseDateKey(key) else { return key }
        let f = DateFormatter()
        f.locale = app.locale.language.locale
        f.setLocalizedDateFormatFromTemplate("d MMM")
        return f.string(from: date)
    }
}
