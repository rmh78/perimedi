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
        ZStack(alignment: .bottom) {
            Theme.ink.opacity(0.28)
                .onTapGesture { closeDraft() }
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
        .accessibilityAddTraits(.isModal)
    }

    private var periodFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(draft == .create ? app.t("period.new") : app.t("period.edit"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: app.t("period.startDate"))
                    SoftField {
                        DateKeyPicker(key: $start, identifier: A11yID.periodStart)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: app.t("period.endDate"))
                    SoftField {
                        DateKeyPicker(key: $end, allowEmpty: true, identifier: A11yID.periodEnd)
                    }
                    Text(app.t("period.endHint"))
                        .font(.caption2)
                        .foregroundStyle(Theme.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
            HStack(spacing: 8) {
                PillButton(title: app.t("common.cancel"), kind: .secondary, identifier: A11yID.confirmCancel, fillsWidth: true) {
                    closeDraft()
                }
                if case .edit(let id) = draft {
                    PillButton(
                        title: app.t("common.delete"),
                        kind: .destructive,
                        identifier: A11yID.periodDelete,
                        fillsWidth: true
                    ) {
                        draft = .confirmDelete(id)
                    }
                }
                PillButton(
                    title: app.t("common.save"),
                    kind: .primary,
                    identifier: A11yID.periodSave,
                    fillsWidth: true,
                    action: saveDraft
                )
            }
        }
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

    private func pretty(_ key: String) -> String {
        guard let date = DateKeys.parseDateKey(key) else { return key }
        let f = DateFormatter()
        f.locale = app.locale.language.locale
        f.setLocalizedDateFormatFromTemplate("MMMMd yyyy")
        return f.string(from: date)
    }

    private func rangeLabel(_ period: Period) -> String {
        guard let start = DateKeys.parseDateKey(period.startDate) else { return period.startDate }
        let cal = DateKeys.calendar
        func part(_ date: Date, _ template: String) -> String {
            let f = DateFormatter()
            f.locale = app.locale.language.locale
            f.calendar = cal
            f.setLocalizedDateFormatFromTemplate(template)
            return f.string(from: date)
        }
        guard let end = period.endDate.flatMap(DateKeys.parseDateKey) else {
            return "\(part(start, "d MMM yyyy")) → …"
        }
        let sameYear = cal.component(.year, from: start) == cal.component(.year, from: end)
        let sameMonth = sameYear && cal.component(.month, from: start) == cal.component(.month, from: end)
        if sameMonth {
            if app.locale.language == .de {
                let month = part(end, "MMMM yyyy")
                return "\(cal.component(.day, from: start)).–\(cal.component(.day, from: end)). \(month)"
            }
            return "\(cal.component(.day, from: start))–\(cal.component(.day, from: end)) \(part(end, "MMM yyyy"))"
        }
        if sameYear {
            return "\(part(start, "d MMM")) – \(part(end, "d MMM yyyy"))"
        }
        return "\(part(start, "d MMM yyyy")) – \(part(end, "d MMM yyyy"))"
    }

    private func formatted(_ key: String?) -> String? {
        key.map(pretty)
    }
}
