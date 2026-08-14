import SwiftUI
import PeriMediDomain

struct MedicationSheet: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    let isNew: Bool
    let medication: Medication?

    @State private var name = ""
    @State private var form: MedForm = .PILL
    @State private var doseLabel = ""
    @State private var color: String?
    @State private var times: [String] = ["20:00"]
    @State private var daysOfWeek: [Int] = []
    @State private var mode: Mode = .everyDay
    @State private var preset: TherapyPresetId = .continuous
    @State private var onDays = 21
    @State private var offDays = 7
    @State private var startDate = DateKeys.todayKey()
    @State private var endDate = ""
    @State private var error: String?

    enum Mode: String, CaseIterable { case everyDay, specificDays, cyclic }

    var body: some View {
        DialogChrome(
            title: app.t(isNew ? "med.addTitle" : "med.editTitle"),
            icon: medFormImage(form),
            onClose: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                SectionLabel(text: app.t("med.sectionMed"))
                FieldLabel(text: app.t("med.name"))
                SoftField { TextField("", text: $name).foregroundStyle(Theme.ink) }

                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: app.t("med.form"))
                        SoftField {
                            Picker("", selection: $form) {
                                ForEach(MedForm.allCases, id: \.self) { f in
                                    Text(app.t("form.\(f.rawValue)")).tag(f)
                                }
                            }
                            .labelsHidden()
                            .tint(Theme.ink)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: app.t("med.defaultDose"))
                        SoftField {
                            TextField(app.t("med.dosePlaceholder"), text: $doseLabel)
                                .foregroundStyle(Theme.ink)
                        }
                    }
                }

                FieldLabel(text: app.t("med.color"))
                palette

                Rectangle().fill(Theme.blush100).frame(height: 1)

                SectionLabel(text: app.t("med.sectionSchedule"))
                modePicker

                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel(text: app.t("med.takeAt"))
                    Text(app.t("med.takeAtHint"))
                        .font(.caption)
                        .foregroundStyle(Theme.inkMuted)
                    ForEach(times.indices, id: \.self) { i in
                        SoftField {
                            TextField("08:00", text: $times[i])
                                .keyboardType(.numbersAndPunctuation)
                        }
                    }
                    Button(app.t("med.anotherTime")) { times.append("08:00") }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.blush600)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.blush25))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.blush100))

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: app.t("med.start"))
                        SoftField { TextField("YYYY-MM-DD", text: $startDate) }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: app.t("med.endOptional"))
                        SoftField { TextField("YYYY-MM-DD", text: $endDate) }
                    }
                }

                if mode == .specificDays {
                    weekdayRow
                }
                if mode == .cyclic {
                    cyclicBlock
                }

                if let error {
                    Text(error).font(.caption).foregroundStyle(Theme.blush700)
                }

                HStack(spacing: 10) {
                    PillButton(title: app.t(isNew ? "med.saveNew" : "med.saveChanges"), filled: true, action: save)
                    if !isNew, medication != nil {
                        Button(app.t("common.delete"), role: .destructive) {
                            if let medication { store.deleteMedication(id: medication.id) }
                            dismiss()
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                }
            }
        }
        .onAppear(perform: hydrate)
    }

    private var palette: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)
        return LazyVGrid(columns: cols, spacing: 8) {
            Image(medFormImage(form))
                .resizable().scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.blush600, lineWidth: 2))
            ForEach(MedColors.palette, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(color == hex ? Theme.blush800 : Color.white.opacity(0.6), lineWidth: color == hex ? 2 : 1))
                    .onTapGesture { color = hex }
            }
        }
    }

    private var modePicker: some View {
        HStack(spacing: 0) {
            modeTab(.everyDay, app.t("sched.everyDay"))
            modeTab(.specificDays, app.t("sched.specificDays"))
            modeTab(.cyclic, app.t("sched.cyclic"))
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.blush50))
    }

    private func modeTab(_ value: Mode, _ title: String) -> some View {
        Button {
            mode = value
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(mode == value ? .white : Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(mode == value ? Theme.blush600 : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private var weekdayRow: some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { d in
                let on = daysOfWeek.contains(d)
                Button(app.t("weekday.\(d)")) {
                    if on { daysOfWeek.removeAll { $0 == d } } else { daysOfWeek.append(d) }
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(on ? .white : Theme.blush700)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(Capsule().fill(on ? Theme.blush600 : Theme.blush50))
                .buttonStyle(.plain)
            }
        }
    }

    private var cyclicBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: app.t("med.preset"))
            SoftField {
                Picker("", selection: $preset) {
                    Text(app.t("therapy.preset.continuous")).tag(TherapyPresetId.continuous)
                    Text(app.t("therapy.preset.21_7")).tag(TherapyPresetId.days21_7)
                    Text(app.t("therapy.preset.14_7")).tag(TherapyPresetId.days14_7)
                    Text(app.t("therapy.preset.7_7")).tag(TherapyPresetId.days7_7)
                    Text(app.t("therapy.preset.5_2")).tag(TherapyPresetId.days5_2)
                    Text(app.t("therapy.preset.custom_days")).tag(TherapyPresetId.custom_days)
                }
                .labelsHidden()
            }
            if preset != .continuous {
                HStack {
                    Stepper("\(app.t("med.applyDays")): \(onDays)", value: $onDays, in: 1...60)
                    Stepper("\(app.t("med.pauseDays")): \(offDays)", value: $offDays, in: 0...60)
                }
                .font(.caption)
            }
        }
    }

    private func hydrate() {
        guard let medication else { return }
        name = medication.name
        form = medication.form
        doseLabel = medication.doseLabel
        color = medication.color
        if let schedule = store.schedules.first(where: { $0.medicationId == medication.id }) {
            times = TherapyCycleLogic.getScheduleTimes(schedule)
            daysOfWeek = schedule.daysOfWeek
            startDate = schedule.startDate ?? DateKeys.todayKey()
            endDate = schedule.endDate ?? ""
            if let tc = TherapyCycleLogic.getTherapyCycle(schedule), tc.enabled, tc.mode != .continuous {
                mode = .cyclic
                onDays = tc.onDays
                offDays = tc.offDays
                if tc.onDays == 21 && tc.offDays == 7 { preset = .days21_7 }
                else if tc.onDays == 14 && tc.offDays == 7 { preset = .days14_7 }
                else if tc.onDays == 7 && tc.offDays == 7 { preset = .days7_7 }
                else if tc.onDays == 5 && tc.offDays == 2 { preset = .days5_2 }
                else { preset = .custom_days }
            } else if !schedule.daysOfWeek.isEmpty {
                mode = .specificDays
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDose = doseLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedDose.isEmpty else {
            error = app.t("med.errorNameDose")
            return
        }
        let cleanedTimes = TherapyCycleLogic.normalizeTimes(times, fallback: "08:00")
        guard !cleanedTimes.isEmpty else {
            error = app.t("med.errorTime")
            return
        }
        applyPreset()
        let med = Medication(
            id: medication?.id ?? createId(),
            name: trimmedName,
            form: form,
            doseLabel: trimmedDose,
            color: color,
            createdAt: medication?.createdAt ?? ISO8601DateFormatter().string(from: Date())
        )
        store.upsertMedication(med)
        var therapy: TherapyCycle?
        if mode == .cyclic, preset != .continuous {
            therapy = TherapyCycleLogic.normalizeTherapyCycle(
                TherapyCycle(enabled: true, mode: .on_off_days, anchorDate: startDate, onDays: onDays, offDays: offDays),
                fallbackAnchor: startDate
            )
        }
        let existing = store.schedules.first(where: { $0.medicationId == med.id })
        store.upsertSchedule(
            Schedule(
                id: existing?.id ?? createId(),
                medicationId: med.id,
                daysOfWeek: mode == .specificDays ? daysOfWeek.sorted() : [],
                timeOfDay: cleanedTimes[0],
                times: cleanedTimes,
                active: true,
                startDate: startDate.isEmpty ? nil : startDate,
                endDate: endDate.isEmpty ? nil : endDate,
                cycleRule: .none,
                therapyCycle: therapy
            )
        )
        dismiss()
    }

    private func applyPreset() {
        switch preset {
        case .days21_7: onDays = 21; offDays = 7
        case .days14_7: onDays = 14; offDays = 7
        case .days7_7: onDays = 7; offDays = 7
        case .days5_2: onDays = 5; offDays = 2
        default: break
        }
    }
}
