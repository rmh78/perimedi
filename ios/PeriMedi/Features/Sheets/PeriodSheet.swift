import SwiftUI
import PeriMediDomain

struct PeriodSheet: View {
    var startInAddEditor = false

    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var cycleLen: Int = 28
    @State private var periodLen: Int = 5
    @State private var editing: Period?
    @State private var start = DateKeys.todayKey()
    @State private var end = ""
    @State private var flow: FlowNote = .medium
    @State private var notes = ""
    @State private var showEditor = false

    private var nextPeriod: String? {
        CycleLogic.nextPredictedPeriodStart(periods: store.periods, settings: store.settings)
    }

    var body: some View {
        DialogChrome(title: app.t("period.title"), icon: "ActionPeriod", onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(app.t("period.intro")) \(formatted(nextPeriod) ?? "—")")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)

                FieldLabel(text: app.t("period.avgCycle"))
                SoftField {
                    TextField("", value: $cycleLen, format: .number)
                        .keyboardType(.numberPad)
                }
                FieldLabel(text: app.t("period.avgPeriod"))
                SoftField {
                    TextField("", value: $periodLen, format: .number)
                        .keyboardType(.numberPad)
                }
                PillButton(title: app.t("period.saveSettings"), filled: true) {
                    store.saveSettings(CycleSettings(averageCycleLength: cycleLen, averagePeriodLength: periodLen))
                }

                HStack {
                    Text(app.t("period.history")).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Spacer()
                    if !showEditor {
                        Button(app.t("period.add")) {
                            editing = nil
                            start = app.selectedDate
                            end = ""
                            flow = .medium
                            notes = ""
                            showEditor = true
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.blush600)
                    }
                }

                if showEditor {
                    periodEditor
                } else if store.periods.isEmpty {
                    Text(app.t("period.none")).font(.caption).foregroundStyle(Theme.inkMuted)
                }
                ForEach(store.periods) { period in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(pretty(period.startDate)) → \(period.endDate.map(pretty) ?? "…")")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text(meta(period))
                            .font(.caption)
                            .foregroundStyle(Theme.inkMuted)
                        HStack(spacing: 16) {
                            Button(app.t("common.edit")) {
                                editing = period
                                start = period.startDate
                                end = period.endDate ?? ""
                                flow = period.flowNote ?? .medium
                                notes = period.notes ?? ""
                                showEditor = true
                            }
                            Button(app.t("common.delete")) { store.deletePeriod(id: period.id) }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.blush600)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.blush50))
                }
            }
        }
        .onAppear {
            cycleLen = store.settings.averageCycleLength
            periodLen = store.settings.averagePeriodLength
            if startInAddEditor {
                editing = nil
                start = JourneyScript.periodStart(today: app.selectedDate)
                end = JourneyScript.periodEnd(today: app.selectedDate)
                flow = .medium
                notes = ""
                showEditor = true
            }
        }
    }

    private var periodEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(editing == nil ? app.t("period.new") : app.t("period.edit"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkMuted)
                .textCase(.uppercase)
            FieldLabel(text: app.t("period.startDate"))
            SoftField { TextField("YYYY-MM-DD", text: $start) }
            FieldLabel(text: app.t("period.endDate"))
            SoftField { TextField("YYYY-MM-DD", text: $end) }
            Text(app.t("period.endHint"))
                .font(.caption2)
                .foregroundStyle(Theme.inkMuted)
            FieldLabel(text: app.t("period.flow"))
            SoftField {
                Picker("", selection: $flow) {
                    ForEach(FlowNote.allCases, id: \.self) { f in
                        Text(app.t("flow.\(f.rawValue)")).tag(f)
                    }
                }
                .labelsHidden()
            }
            FieldLabel(text: app.t("period.notes"))
            SoftField { TextField(app.t("common.optional"), text: $notes) }
            HStack(spacing: 10) {
                PillButton(title: app.t(editing == nil ? "period.addPeriod" : "period.saveChanges"), filled: true) {
                    store.upsertPeriod(
                        Period(
                            id: editing?.id ?? createId(),
                            startDate: DateKeys.toDateKey(start),
                            endDate: end.isEmpty ? nil : DateKeys.toDateKey(end),
                            flowNote: flow,
                            notes: notes.isEmpty ? nil : notes
                        )
                    )
                    showEditor = false
                    editing = nil
                }
                PillButton(title: app.t("common.cancel"), filled: false) {
                    showEditor = false
                    editing = nil
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.blush100))
    }

    private func meta(_ period: Period) -> String {
        let days = CycleLogic.periodLengthDays(period, defaultLen: store.settings.averagePeriodLength)
        let flow = period.flowNote.map { app.t("flow.\($0.rawValue)") } ?? ""
        let extra = period.notes ?? ""
        return ["~\(days)d", flow, extra].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func pretty(_ key: String) -> String {
        guard let date = DateKeys.parseDateKey(key) else { return key }
        let f = DateFormatter()
        f.locale = app.locale.language.locale
        f.setLocalizedDateFormatFromTemplate("MMMMd yyyy")
        return f.string(from: date)
    }

    private func formatted(_ key: String?) -> String? {
        key.map(pretty)
    }
}
