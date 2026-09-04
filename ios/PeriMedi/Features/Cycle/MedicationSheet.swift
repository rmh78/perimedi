import SwiftUI
import PeriMediDomain

struct MedicationSheet: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dialogClose) private var dialogClose

    let isNew: Bool
    let medication: Medication?

    @State private var name = ""
    @State private var form: MedForm = .PILL
    @State private var doseLabel = ""
    @State private var color: String? = MedColors.formDefaults[.PILL]
    @State private var times: [String] = ["20:00"]
    @State private var daysOfWeek: [Int] = []
    @State private var mode: Mode = .everyDay
    @State private var onDays = 21
    @State private var offDays = 7
    @State private var startDate = DateKeys.todayKey()
    @State private var endDate = ""
    @State private var remindersEnabled = true
    @State private var effectiveDate = DateKeys.todayKey()
    @State private var error: String?

    enum Mode: String, CaseIterable { case everyDay, specificDays, cyclic }

    var body: some View {
        DialogChrome(
            title: app.t(isNew ? "med.addTitle" : "med.editTitle"),
            icon: medFormImage(form),
            iconAccent: Color(hex: resolvedColor),
            identifier: A11yID.sheetMed,
            onClose: {
                dialogClose()
                dismiss()
            }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                FieldLabel(text: app.t("med.name"))
                SoftField {
                    TextField("", text: $name)
                        .foregroundStyle(Theme.ink)
                        .accessibilityIdentifier(A11yID.medName)
                }

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
                            .accessibilityIdentifier(A11yID.medForm)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: app.t("med.defaultDose"))
                        SoftField {
                            TextField(app.t("med.dosePlaceholder"), text: $doseLabel)
                                .foregroundStyle(Theme.ink)
                                .accessibilityIdentifier(A11yID.medDose)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: app.t("med.color"))
                    palette
                }

                Rectangle().fill(Theme.blush100).frame(height: 1)

                SectionLabel(text: app.t("med.sectionSchedule"))

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: app.t("med.start"))
                        SoftField {
                            DateKeyPicker(key: $startDate, identifier: A11yID.medStart)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: app.t("med.endOptional"))
                        SoftField {
                            DateKeyPicker(key: $endDate, allowEmpty: true)
                        }
                    }
                }

                takeAtRow

                Toggle(isOn: $remindersEnabled) {
                    Text(app.t("med.remind"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.blush600)
                .accessibilityIdentifier(A11yID.medRemind)

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: app.t("med.scheduleType"))
                    SoftField {
                        Picker("", selection: $mode) {
                            Text(app.t("sched.everyDay")).tag(Mode.everyDay)
                                .accessibilityIdentifier(A11yID.medModeEveryday)
                            Text(app.t("sched.specificDays")).tag(Mode.specificDays)
                            Text(app.t("sched.cyclic")).tag(Mode.cyclic)
                                .accessibilityIdentifier(A11yID.medModeCyclic)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .tint(Theme.ink)
                        .accessibilityIdentifier(A11yID.medMode)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }

                if mode == .specificDays {
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: app.t("med.days"))
                        weekdayRow
                    }
                }
                if mode == .cyclic {
                    cyclicBlock
                }

                if showsSinceDate {
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: app.t("med.since"))
                        SoftField {
                            DateKeyPicker(key: $effectiveDate, identifier: A11yID.medSince)
                        }
                    }
                }

                if let error {
                    Text(error).font(.caption).foregroundStyle(Theme.blush700)
                }

                HStack(spacing: 10) {
                    PillButton(
                        title: app.t(isNew ? "med.saveNew" : "med.saveChanges"),
                        kind: .primary,
                        identifier: A11yID.medSave,
                        action: save
                    )
                    if !isNew, let medication {
                        PillButton(
                            title: app.t("common.delete"),
                            kind: .destructive,
                            identifier: A11yID.medDelete
                        ) {
                            app.askConfirm(
                                message: app.t("med.deleteConfirm", ["name": medication.name]),
                                confirmLabel: app.t("common.delete"),
                                destructive: true
                            ) {
                                do {
                                    try store.deleteMedication(id: medication.id)
                                    dialogClose()
                                    dismiss()
                                } catch {
                                    self.error = app.t("persist.saveFailed")
                                }
                            }
                        }
                    }
                    Spacer()
                }
            }
        }
        .onAppear(perform: hydrate)
        .onChange(of: mode) { _, new in
            if new == .specificDays, daysOfWeek.isEmpty {
                daysOfWeek = [1, 3, 5]
            }
            if new == .cyclic, offDays < 1 {
                offDays = 7
            }
        }
        .onChange(of: form) { old, new in
            let oldDefault = MedColors.formDefaults[old]
            if color == nil || color == oldDefault {
                color = MedColors.formDefaults[new]
            }
        }
    }

    private var resolvedColor: String {
        MedColors.resolve(form: form, color: color)
    }

    private var palette: some View {
        GeometryReader { geo in
            let count = CGFloat(MedColors.palette.count)
            let spacing: CGFloat = 4
            let size = min(22, max(14, (geo.size.width - spacing * (count - 1)) / count))
            HStack(spacing: spacing) {
                ForEach(MedColors.palette, id: \.self) { hex in
                    let selected = resolvedColor.lowercased() == hex.lowercased()
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: size, height: size)
                        .overlay(
                            Circle().stroke(
                                selected ? Theme.ink : Color.white.opacity(0.7),
                                lineWidth: selected ? 2 : 1
                            )
                        )
                        .onTapGesture { color = hex }
                        .accessibilityLabel(hex)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 22)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(app.t("med.color"))
    }

    private var takeAtRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: app.t("med.takeAt"))
            WrappingHStack(spacing: 8, lineSpacing: 8) {
                ForEach(times.indices, id: \.self) { i in
                    HStack(spacing: 4) {
                        TimeOfDayPicker(time: $times[i], compact: true)
                        if times.count > 1 {
                            Button {
                                times.remove(at: i)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Theme.inkMuted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.blush200, lineWidth: 1)
                    )
                }
                Button {
                    times.append("08:00")
                } label: {
                    Text("+")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.blush600)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Theme.blush50))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(app.t("med.anotherTime"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
        HStack(spacing: 10) {
            dayCountField(app.t("med.applyDays"), $onDays, 1...60)
            dayCountField(app.t("med.pauseDays"), $offDays, 1...60)
        }
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

    private func hydrate() {
        guard let medication else { return }
        effectiveDate = DateKeys.todayKey()
        name = medication.name
        form = medication.form
        doseLabel = medication.doseLabel
        color = MedColors.resolve(form: medication.form, color: medication.color)
        remindersEnabled = medication.remindersEnabled
        if let schedule = store.schedules.first(where: { $0.medicationId == medication.id }) {
            times = TherapyCycleLogic.getScheduleTimes(schedule)
            daysOfWeek = schedule.daysOfWeek
            startDate = schedule.startDate ?? DateKeys.todayKey()
            endDate = schedule.endDate ?? ""
            if let tc = TherapyCycleLogic.getTherapyCycle(schedule), tc.enabled, tc.mode != .continuous {
                mode = .cyclic
                onDays = min(max(tc.onDays, 1), 60)
                offDays = min(max(tc.offDays, 1), 60)
            } else if !schedule.daysOfWeek.isEmpty {
                mode = .specificDays
            }
        }
    }

    private var showsSinceDate: Bool {
        guard let draft = changeDraft() else { return false }
        return MedicationChangeLog.hasChanges(
            previousMed: medication,
            newMed: draft.med,
            previousSchedule: draft.previousSchedule,
            newSchedule: draft.schedule
        )
    }

    private func changeDraft() -> (med: Medication, schedule: Schedule, previousSchedule: Schedule?)? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDose = doseLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDose.isEmpty else { return nil }
        let cleanedTimes = TherapyCycleLogic.normalizeTimes(times, fallback: "08:00")
        guard !cleanedTimes.isEmpty else { return nil }
        let medId = medication?.id ?? "new"
        let med = Medication(
            id: medId,
            name: trimmedName.isEmpty ? medId : trimmedName,
            form: form,
            doseLabel: trimmedDose,
            color: color,
            createdAt: medication?.createdAt ?? "",
            remindersEnabled: remindersEnabled
        )
        let previousSchedule = medication.flatMap { existing in
            store.schedules.first { $0.medicationId == existing.id }
        }
        return (
            med,
            makeSchedule(medicationId: medId, times: cleanedTimes),
            previousSchedule
        )
    }

    private func makeSchedule(medicationId: String, times cleanedTimes: [String], newId: String = "draft") -> Schedule {
        var therapy: TherapyCycle?
        if mode == .cyclic {
            therapy = TherapyCycleLogic.normalizeTherapyCycle(
                TherapyCycle(enabled: true, mode: .on_off_days, anchorDate: startDate, onDays: onDays, offDays: offDays),
                fallbackAnchor: startDate
            )
        }
        let existing = store.schedules.first(where: { $0.medicationId == medicationId })
        return Schedule(
            id: existing?.id ?? newId,
            medicationId: medicationId,
            daysOfWeek: mode == .specificDays ? daysOfWeek.sorted() : [],
            timeOfDay: cleanedTimes[0],
            times: cleanedTimes,
            active: true,
            startDate: startDate.isEmpty ? nil : startDate,
            endDate: endDate.isEmpty ? nil : endDate,
            cycleRule: .none,
            therapyCycle: therapy
        )
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
        let loggedAt = ISO8601DateFormatter().string(from: Date())
        let med = Medication(
            id: medication?.id ?? createId(),
            name: trimmedName,
            form: form,
            doseLabel: trimmedDose,
            color: color,
            createdAt: medication?.createdAt ?? loggedAt,
            remindersEnabled: remindersEnabled
        )
        let previousSchedule = store.schedules.first(where: { $0.medicationId == med.id })
        let schedule = makeSchedule(medicationId: med.id, times: cleanedTimes, newId: createId())
        let changes = MedicationChangeLog.events(
            previousMed: medication,
            newMed: med,
            previousSchedule: previousSchedule,
            newSchedule: schedule,
            effectiveDate: effectiveDate,
            loggedAt: loggedAt
        )
        do {
            try store.upsertMedication(med)
            if remindersEnabled {
                Task { await DoseReminderCenter.shared.requestAuthorizationIfNeeded() }
            }
            try store.upsertSchedule(schedule)
            try store.appendMedicationChanges(changes)
            dialogClose()
            dismiss()
        } catch {
            self.error = app.t("persist.saveFailed")
        }
    }
}
