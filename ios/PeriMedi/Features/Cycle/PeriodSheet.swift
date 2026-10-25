import SwiftUI
import PeriMediDomain

struct PeriodSheet: View {
    var startInAddEditor = false

    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dialogClose) private var dialogClose

    private enum PeriodDraft: Equatable {
        case create
        case edit(String)
        case confirmDelete(String)
    }

    @State private var tracksPeriods = true
    @State private var cycleLen: Int = 28
    @State private var periodLen: Int = 5
    @State private var draft: PeriodDraft?
    @State private var start = DateKeys.todayKey()
    @State private var end = ""
    @State private var flow: FlowNote = .medium

    private var nextPeriod: String? {
        CycleLogic.nextPredictedPeriodStart(periods: store.periods, settings: store.settings)
    }

    var body: some View {
        DialogChrome(title: app.t("period.title"), icon: "ActionPeriod", identifier: A11yID.sheetPeriod, onClose: close) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $tracksPeriods) {
                    Text(app.t("period.track"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.blush600)
                .onChange(of: tracksPeriods) { _, on in
                    persistSettings(tracks: on)
                    if !on { closeDraft() }
                }

                if tracksPeriods {
                    Text("\(app.t("period.intro")) \(formatted(nextPeriod) ?? "—")")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)

                    HStack(alignment: .top, spacing: 10) {
                        dayCountField(app.t("period.avgCycle"), $cycleLen, 15...45)
                        dayCountField(app.t("period.avgPeriod"), $periodLen, 1...15)
                    }

                    if draft == nil {
                        PillButton(
                            title: app.t("period.add"),
                            kind: .secondary,
                            identifier: A11yID.periodAdd
                        ) {
                            openCreate()
                        }
                    }

                    Text(app.t("period.history")).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    if store.periods.isEmpty {
                        Text(app.t("period.none")).font(.caption).foregroundStyle(Theme.inkMuted)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(store.periods.enumerated()), id: \.element.id) { index, period in
                            Button {
                                openEdit(period)
                            } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(rangeLabel(period))
                                        .font(.subheadline.weight(.semibold))
                                        .underline()
                                        .foregroundStyle(Theme.blush700)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(meta(period))
                                        .font(.caption)
                                        .foregroundStyle(Theme.inkMuted)
                                        .lineLimit(1)
                                        .layoutPriority(1)
                                }
                                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(A11yID.periodHistory(period.id))
                            .accessibilityLabel(rangeLabel(period))
                            .accessibilityValue(meta(period))
                            .padding(.vertical, 8)
                            if index < store.periods.count - 1 {
                                Rectangle().fill(Theme.blush100).frame(height: 1)
                            }
                        }
                    }
                } else {
                    Text(app.t("period.trackOffHint"))
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .overlay {
            if draft != nil {
                periodCard
            }
        }
        .onAppear {
            tracksPeriods = store.settings.tracksPeriods
            cycleLen = min(max(store.settings.averageCycleLength, 15), 45)
            periodLen = min(max(store.settings.averagePeriodLength, 1), 15)
            if startInAddEditor {
                start = JourneyScript.periodStart(today: app.selectedDate)
                end = JourneyScript.periodEnd(today: app.selectedDate)
                flow = .medium
                draft = .create
            }
        }
        .onDisappear { persistSettings(tracks: tracksPeriods) }
    }

    private var periodCard: some View {
        ZStack {
            Theme.ink.opacity(0.28)
            GeometryReader { geo in
                ScrollView {
                    cardSurface
                        .frame(minHeight: geo.size.height, alignment: .bottom)
                        .background {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { closeDraft() }
                        }
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    private var cardSurface: some View {
        Group {
            if case .confirmDelete(let id) = draft {
                periodDeletePrompt(id)
            } else {
                periodFields
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Theme.blush100, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var periodFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(draft == .create ? app.t("period.new") : app.t("period.edit"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            PeriodDatePair(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: app.t("period.startDate"))
                    SoftField {
                        DateKeyPicker(key: $start, identifier: A11yID.periodStart, usesTextWidth: true)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: app.t("period.endDate"))
                    SoftField {
                        DateKeyPicker(key: $end, allowEmpty: true, identifier: A11yID.periodEnd, usesTextWidth: true)
                    }
                    Text(app.t("period.endHint"))
                        .font(.caption2)
                        .foregroundStyle(Theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            FieldLabel(text: app.t("period.flow"))
            SoftField {
                Picker("", selection: $flow) {
                    ForEach(FlowNote.allCases, id: \.self) { note in
                        Text(app.t("flow.\(note.rawValue)")).tag(note)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            EqualWidthPillRow(items: periodActions)
        }
    }

    private var periodActions: [EqualWidthPillRow.Item] {
        var items = [
            EqualWidthPillRow.Item(
                id: "cancel",
                title: app.t("common.cancel"),
                kind: .secondary,
                identifier: A11yID.confirmCancel,
                action: closeDraft
            )
        ]
        if case .edit(let id) = draft {
            items.append(
                EqualWidthPillRow.Item(
                    id: "delete",
                    title: app.t("common.delete"),
                    kind: .destructive,
                    identifier: A11yID.periodDelete
                ) {
                    draft = .confirmDelete(id)
                }
            )
        }
        items.append(
            EqualWidthPillRow.Item(
                id: "save",
                title: app.t("common.save"),
                kind: .primary,
                identifier: A11yID.periodSave,
                action: saveDraft
            )
        )
        return items
    }

    private func periodDeletePrompt(_ id: String) -> some View {
        let name = store.periods.first { $0.id == id }.map(rangeLabel) ?? id
        return VStack(alignment: .leading, spacing: 12) {
            Text(app.t("confirm.title"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(app.t("period.deleteNamed", ["name": name]))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
            HStack(spacing: 8) {
                PillButton(title: app.t("common.cancel"), kind: .secondary, identifier: A11yID.confirmCancel) {
                    draft = .edit(id)
                }
                Spacer(minLength: 0)
                PillButton(
                    title: app.t("common.delete"),
                    kind: .destructive,
                    identifier: A11yID.confirmDelete
                ) {
                    try? store.deletePeriod(id: id)
                    closeDraft()
                }
            }
        }
    }

    private func openCreate() {
        start = app.selectedDate
        end = ""
        flow = .medium
        draft = .create
    }

    private func openEdit(_ period: Period) {
        start = period.startDate
        end = period.endDate ?? ""
        flow = period.flowNote ?? .medium
        draft = .edit(period.id)
    }

    private func closeDraft() {
        draft = nil
    }

    private func saveDraft() {
        let existing = store.periods.first { period in
            if case .edit(let id) = draft { return period.id == id }
            return false
        }
        let id: String
        if case .edit(let existingId) = draft {
            id = existingId
        } else {
            id = createId()
        }
        do {
            try store.upsertPeriod(
                Period(
                    id: id,
                    startDate: DateKeys.toDateKey(start),
                    endDate: end.isEmpty ? nil : DateKeys.toDateKey(end),
                    flowNote: flow,
                    notes: existing?.notes
                )
            )
            closeDraft()
        } catch {}
    }

    private func dayCountField(_ label: String, _ value: Binding<Int>, _ range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: label)
            SoftField {
                Picker("", selection: value) {
                    ForEach(Array(range), id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func close() {
        persistSettings(tracks: tracksPeriods)
        dialogClose()
        dismiss()
    }

    private func persistSettings(tracks: Bool) {
        try? store.saveSettings(CycleSettings(
            averageCycleLength: cycleLen,
            averagePeriodLength: periodLen,
            tracksPeriods: tracks
        ))
    }

    private func meta(_ period: Period) -> String {
        let days = CycleLogic.periodLengthDays(period, defaultLen: store.settings.averagePeriodLength)
        let flow = period.flowNote.map { app.t("flow.\($0.rawValue)") } ?? ""
        return ["~\(days)d", flow].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func rangeLabel(_ period: Period) -> String {
        DateCopy.periodHistory(
            startKey: period.startDate,
            endKey: period.endDate,
            locale: app.locale.language.locale
        )
    }

    private func formatted(_ key: String?) -> String? {
        key.map { DateCopy.day($0, locale: app.locale.language.locale) }
    }
}

struct PeriodDatePair: Layout {
    var spacing: CGFloat = 10

    enum Axis: Equatable {
        case row
        case stack
    }

    static func axis(minimumWidths: [CGFloat], offeredWidth: CGFloat, spacing: CGFloat) -> Axis {
        let half = (offeredWidth - spacing) / 2
        if minimumWidths.allSatisfy({ $0 <= half }) {
            return .row
        }
        return .stack
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let mins = subviews.map { minimumWidth(of: $0) }
        let offered = finiteWidth(proposal.width, minimumWidths: mins)
        switch Self.axis(minimumWidths: mins, offeredWidth: offered, spacing: spacing) {
        case .row:
            let column = columnWidth(offered)
            let height = subviews.map { $0.sizeThatFits(ProposedViewSize(width: column, height: nil)).height }.max() ?? 0
            return CGSize(width: offered, height: height)
        case .stack:
            let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: offered, height: nil)).height }
            let gaps = spacing * CGFloat(max(subviews.count - 1, 0))
            return CGSize(width: offered, height: heights.reduce(0, +) + gaps)
        }
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let mins = subviews.map { minimumWidth(of: $0) }
        let offered = bounds.width
        switch Self.axis(minimumWidths: mins, offeredWidth: offered, spacing: spacing) {
        case .row:
            let column = columnWidth(offered)
            var x = bounds.minX
            for subview in subviews {
                let height = subview.sizeThatFits(ProposedViewSize(width: column, height: nil)).height
                subview.place(
                    at: CGPoint(x: x, y: bounds.minY),
                    proposal: ProposedViewSize(width: column, height: height)
                )
                x += column + spacing
            }
        case .stack:
            var y = bounds.minY
            for subview in subviews {
                let height = subview.sizeThatFits(ProposedViewSize(width: offered, height: nil)).height
                subview.place(
                    at: CGPoint(x: bounds.minX, y: y),
                    proposal: ProposedViewSize(width: offered, height: height)
                )
                y += height + spacing
            }
        }
    }

    private func columnWidth(_ offered: CGFloat) -> CGFloat {
        max(0, (offered - spacing) / 2)
    }

    private func finiteWidth(_ proposed: CGFloat?, minimumWidths: [CGFloat]) -> CGFloat {
        if let proposed, proposed.isFinite {
            return proposed
        }
        let gaps = spacing * CGFloat(max(minimumWidths.count - 1, 0))
        return minimumWidths.reduce(0, +) + gaps
    }

    private func minimumWidth(of subview: LayoutSubview) -> CGFloat {
        subview.sizeThatFits(ProposedViewSize(width: 0, height: nil)).width
    }
}
