import SwiftUI
import PeriMediDomain

struct PeriodSheet: View {
    var startInAddEditor = false

    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dialogClose) private var dialogClose

    @State private var tracksPeriods = true
    @State private var cycleLen: Int = 28
    @State private var periodLen: Int = 5
    @State private var editing: Period?
    @State private var start = DateKeys.todayKey()
    @State private var end = ""
    @State private var flow: FlowNote = .medium
    @State private var showEditor = false

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
                    if !on { showEditor = false }
                }

                if tracksPeriods {
                    Text("\(app.t("period.intro")) \(formatted(nextPeriod) ?? "—")")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)

                    HStack(alignment: .top, spacing: 10) {
                        dayCountField(app.t("period.avgCycle"), $cycleLen, 15...45)
                        dayCountField(app.t("period.avgPeriod"), $periodLen, 1...15)
                    }

                    if showEditor {
                        periodEditor
                    } else {
                        PillButton(
                            title: app.t("period.add"),
                            kind: .secondary,
                            identifier: A11yID.periodAdd
                        ) {
                            editing = nil
                            start = app.selectedDate
                            end = ""
                            flow = .medium
                            showEditor = true
                        }
                    }

                    Text(app.t("period.history")).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    if store.periods.isEmpty {
                        Text(app.t("period.none")).font(.caption).foregroundStyle(Theme.inkMuted)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(store.periods.enumerated()), id: \.element.id) { index, period in
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(rangeLabel(period))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.ink)
                                        .lineLimit(1)
                                    Text(meta(period))
                                        .font(.caption)
                                        .foregroundStyle(Theme.inkMuted)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                IconCircleButton(systemName: "pencil", label: app.t("common.edit")) {
                                    editing = period
                                    start = period.startDate
                                    end = period.endDate ?? ""
                                    flow = period.flowNote ?? .medium
                                    showEditor = true
                                }
                                IconCircleButton(systemName: "trash", label: app.t("common.delete"), tint: Theme.blush800) {
                                    app.askConfirm(
                                        message: app.t("period.deleteConfirm"),
                                        confirmLabel: app.t("common.delete"),
                                        destructive: true
                                    ) {
                                        store.deletePeriod(id: period.id)
                                    }
                                }
                            }
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
        .onAppear {
            tracksPeriods = store.settings.tracksPeriods
            cycleLen = min(max(store.settings.averageCycleLength, 15), 45)
            periodLen = min(max(store.settings.averagePeriodLength, 1), 15)
            if startInAddEditor {
                editing = nil
                start = JourneyScript.periodStart(today: app.selectedDate)
                end = JourneyScript.periodEnd(today: app.selectedDate)
                flow = .medium
                showEditor = true
            }
        }
        .onDisappear { persistSettings(tracks: tracksPeriods) }
    }

    private var periodEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(editing == nil ? app.t("period.new") : app.t("period.edit"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkMuted)
                .textCase(.uppercase)
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
                    ForEach(FlowNote.allCases, id: \.self) { f in
                        Text(app.t("flow.\(f.rawValue)")).tag(f)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            HStack(spacing: 10) {
                PillButton(title: app.t(editing == nil ? "period.addPeriod" : "period.saveChanges"), kind: .primary, identifier: A11yID.periodSave) {
                    store.upsertPeriod(
                        Period(
                            id: editing?.id ?? createId(),
                            startDate: DateKeys.toDateKey(start),
                            endDate: end.isEmpty ? nil : DateKeys.toDateKey(end),
                            flowNote: flow,
                            notes: editing?.notes
                        )
                    )
                    showEditor = false
                    editing = nil
                }
                PillButton(title: app.t("common.cancel"), kind: .secondary) {
                    showEditor = false
                    editing = nil
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.blush100))
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
        store.saveSettings(CycleSettings(
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
