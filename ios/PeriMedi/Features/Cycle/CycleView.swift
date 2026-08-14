import SwiftUI
import PeriMediDomain

struct CycleView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store

    @State private var medSheet: MedSheetState?
    @State private var showPeriod = false
    @State private var showSymptom = false
    @State private var openPeriodEditor = false

    private let dayMin: CGFloat = 22
    private let labelCol: CGFloat = 148

    private var today: String { DateKeys.todayKey() }

    private var window: (start: String, length: Int) {
        CycleLogic.cycleWindowForDate(
            dateKey: app.selectedDate,
            periods: store.periods,
            settings: store.settings
        )
    }

    private var days: [String] {
        (0..<window.length).map { DateKeys.addDaysKey(window.start, $0) }
    }

    private var doses: [PlannedDose] {
        let range = DoseRangeLogic.doseExpansionRange(
            today: today,
            selectedDate: app.selectedDate,
            periods: store.periods,
            settings: store.settings
        )
        return ScheduleLogic.expandPlannedDoses(
            from: range.from,
            to: range.to,
            medications: store.medications,
            schedules: store.schedules,
            doseLogs: store.doseLogs,
            periods: store.periods,
            settings: store.settings
        )
    }

    private var lanes: [MedLane] {
        MedLaneBuilder.build(doses: doses, cycleStart: window.start, cycleLen: window.length)
    }

    private var selectedIndex: Int {
        days.firstIndex(of: app.selectedDate) ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        pager
                        symptomChips
                        medsTitleRow
                        miniLegend
                        chart
                    }
                    .padding(12)
                }
                if store.medications.isEmpty {
                    introCard
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $medSheet) { state in
            MedicationSheet(isNew: state.isNew, medication: state.medication)
                .periDialog()
        }
        .sheet(isPresented: $showPeriod) {
            PeriodSheet(startInAddEditor: openPeriodEditor).periDialog()
        }
        .sheet(isPresented: $showSymptom) { SymptomSheet(dateKey: app.selectedDate).periDialog() }
        .onAppear {
            switch app.launchSheet {
            case "med": medSheet = MedSheetState(isNew: true, medication: nil)
            case "period":
                openPeriodEditor = app.launchPeriodEditor
                showPeriod = true
            case "symptom": showSymptom = true
            default: break
            }
            app.launchSheet = nil
            app.launchPeriodEditor = false
        }
    }

    private var pager: some View {
        HStack(spacing: 4) {
            PillButton(title: app.t("common.today"), filled: false, action: app.goToToday)
            chevron("left", app.t("diagram.prevDay"), selectedIndex <= 0) { page(-1) }
            chevron("right", app.t("diagram.nextDay"), selectedIndex >= days.count - 1) { page(1) }
            Text(pagerLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
    }

    private func chevron(_ dir: String, _ label: String, _ disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.\(dir)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.blush700)
                .frame(width: 32, height: 32)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .accessibilityLabel(label)
        .buttonStyle(.plain)
    }

    private var symptomChips: some View {
        let info = CycleLogic.getDayCycleInfo(
            dateKey: app.selectedDate, periods: store.periods, settings: store.settings
        )
        let notes = store.remarks.filter {
            DateKeys.toDateKey($0.occurredOn) == app.selectedDate
                && ($0.kind == .cycle || $0.kind == .side_effect || $0.kind == .note)
        }
        return VStack(alignment: .leading, spacing: 6) {
            if info.isLoggedPeriod {
                chip(app.t("diagram.periodTitle"), Theme.blush600)
            } else if info.isPredictedPeriod {
                chip(app.t("diagram.predictedPeriodTitle"), Theme.blush400)
            }
            ForEach(notes.prefix(2)) { note in
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: "#7c3aed")).frame(width: 6, height: 6)
                    Text(note.body).font(.caption).foregroundStyle(Color(hex: "#4c1d95")).lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(hex: "#f5f3ff")))
            }
        }
    }

    private var medsTitleRow: some View {
        HStack(alignment: .center) {
            Text(app.t("diagram.medsAndDoses"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.inkMuted)
                .textCase(.uppercase)
                .tracking(1.1)
            Spacer()
            HStack(spacing: 8) {
                actionIcon("ActionPeriod", app.t("diagram.cycleSettings")) { showPeriod = true }
                actionIcon("ActionMed", app.t("diagram.addMed"), plus: true) {
                    medSheet = MedSheetState(isNew: true, medication: nil)
                }
                actionIcon("ActionSymptom", app.t("diagram.addSymptom"), plus: true) { showSymptom = true }
            }
        }
    }

    private var miniLegend: some View {
        HStack(spacing: 10) {
            legendDot(Theme.taken, app.t("diagram.taken"))
            legendDot(Color.slate, app.t("diagram.notTaken"))
            HStack(spacing: 4) {
                Image(systemName: "drop.fill").font(.system(size: 9)).foregroundStyle(.red)
                Text(app.t("diagram.periodTitle")).font(.system(size: 11)).foregroundStyle(Theme.inkMuted)
            }
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill").font(.system(size: 9)).foregroundStyle(Color(hex: "#7c3aed"))
                Text(app.t("legend.symptom")).font(.system(size: 11)).foregroundStyle(Theme.inkMuted)
            }
        }
    }

    private var chart: some View {
        let plotWidth = max(CGFloat(days.count) * dayMin, dayMin)
        return Group {
            if store.medications.isEmpty {
                VStack(spacing: 12) {
                    VStack(spacing: 6) {
                        Text(app.t("diagram.emptyMedsTitle")).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                        Text(app.t("diagram.emptyMedsBody")).font(.caption).foregroundStyle(Theme.inkMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5])).foregroundStyle(Theme.blush200))
                }
            } else {
                HStack(alignment: .top, spacing: 0) {
                    stickyLabels
                        .frame(width: labelCol)
                        .background(Theme.cream)
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            ZStack(alignment: .topLeading) {
                                selectedColumn(width: plotWidth)
                                VStack(alignment: .leading, spacing: 10) {
                                    dayStrip
                                    ForEach(lanes) { lane in
                                        doseTrack(lane, plotWidth: plotWidth)
                                            .frame(height: 44)
                                    }
                                }
                            }
                            .frame(width: plotWidth)
                        }
                        .onAppear { proxy.scrollTo(app.selectedDate, anchor: .center) }
                        .onChange(of: app.selectedDate) { _, new in
                            withAnimation { proxy.scrollTo(new, anchor: .center) }
                        }
                    }
                }
            }
        }
    }

    private var stickyLabels: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(app.t("diagram.cycleDays"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
                    .textCase(.uppercase)
                Text(app.t("diagram.cyclePeriodMeta", [
                    "cycle": "\(store.settings.averageCycleLength)",
                    "period": "\(store.settings.averagePeriodLength)",
                ]))
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkMuted)
            }
            .frame(height: 40, alignment: .center)

            ForEach(lanes) { lane in
                Button {
                    if let med = store.medications.first(where: { $0.id == lane.medicationId }) {
                        medSheet = MedSheetState(isNew: false, medication: med)
                    }
                } label: {
                    HStack(spacing: 8) {
                        medAvatar(lane)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(lane.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(2)
                            Text(statusLabel(for: lane))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(statusColor(for: lane))
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(height: 44, alignment: .leading)
            }
        }
        .padding(.trailing, 6)
    }

    private var dayStrip: some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element) { index, day in
                let info = CycleLogic.getDayCycleInfo(dateKey: day, periods: store.periods, settings: store.settings)
                let hasSymptom = store.remarks.contains {
                    DateKeys.toDateKey($0.occurredOn) == day
                        && ($0.kind == .cycle || $0.kind == .side_effect || $0.kind == .note)
                }
                Button { app.selectedDate = day } label: {
                    VStack(spacing: 1) {
                        Group {
                            if info.isLoggedPeriod || info.isPredictedPeriod {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(info.isLoggedPeriod ? Color.red : Color.pink.opacity(0.6))
                            } else {
                                Color.clear
                            }
                        }
                        .frame(height: 10)
                        Group {
                            if hasSymptom {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(Color(hex: "#7c3aed"))
                            } else {
                                Color.clear
                            }
                        }
                        .frame(height: 10)
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: day == app.selectedDate ? .bold : .regular).monospacedDigit())
                            .foregroundStyle(day == app.selectedDate ? .white : Theme.ink)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(day == app.selectedDate ? Theme.blush600 : .clear))
                    }
                    .frame(width: dayMin, height: 40)
                    .background(info.isLoggedPeriod ? Color.red.opacity(0.16) : Color.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .id(day)
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.85)))
    }

    private func doseTrack(_ lane: MedLane, plotWidth: CGFloat) -> some View {
        let colW = plotWidth / CGFloat(max(days.count, 1))
        let selectedDay = selectedIndex + 1
        return ZStack(alignment: .leading) {
            ForEach(lane.segments, id: \.fromDay) { seg in
                let x = CGFloat(seg.fromDay - 1) * colW + 2
                let w = CGFloat(seg.toDay - seg.fromDay + 1) * colW - 4
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#fffafb"))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: lane.color).opacity(0.35), lineWidth: 1))
                    .frame(width: max(w, 8), height: 36)
                    .offset(x: x)
            }
            ForEach(lane.days, id: \.cycleDay) { cell in
                if cell.statuses.contains(where: { $0 == .taken }) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: lane.color).opacity(0.42))
                        .frame(width: max(colW - 2, 6), height: 34)
                        .offset(x: CGFloat(cell.cycleDay - 1) * colW + 1)
                }
            }
            ForEach(lane.segments, id: \.fromDay) { seg in
                if seg.toDay - seg.fromDay >= 1 {
                    let pinDay = min(max(seg.fromDay, selectedDay), seg.toDay)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(seg.doseLabel).font(.system(size: 11, weight: .bold)).lineLimit(1)
                        Text(app.t("diagram.daysRange", ["from": "\(seg.fromDay)", "to": "\(seg.toDay)"]))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.inkMuted)
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#fffafb").opacity(0.9))
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Color(hex: lane.color)).frame(width: 2)
                    }
                    .offset(x: CGFloat(pinDay - 1) * colW + 4)
                }
            }
        }
        .frame(width: plotWidth, height: 44, alignment: .leading)
    }

    private func statusColor(for lane: MedLane) -> Color {
        let label = statusLabel(for: lane)
        if label == app.t("diagram.taken") { return Color(hex: lane.color) }
        if label == app.t("diagram.noDose") { return Theme.inkMuted }
        return Color(hex: "#64748b")
    }

    private func selectedColumn(width: CGFloat) -> some View {
        let colW = width / CGFloat(max(days.count, 1))
        return Rectangle()
            .fill(Theme.blush400.opacity(0.22))
            .frame(width: colW, height: 40 + CGFloat(max(lanes.count, 1)) * 54)
            .offset(x: CGFloat(selectedIndex) * colW)
            .allowsHitTesting(false)
    }

    private func medAvatar(_ lane: MedLane) -> some View {
        let selectedDoses = doses.filter { $0.date == app.selectedDate && $0.medication.id == lane.medicationId }
        let allTaken = !selectedDoses.isEmpty && selectedDoses.allSatisfy { $0.status == .taken }
        return ZStack(alignment: .bottomTrailing) {
            Image(medFormImage(lane.form))
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .padding(3)
                .background(Circle().fill(Color(hex: lane.color)))
            if allTaken {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white, Color(hex: lane.color))
                    .offset(x: 2, y: 2)
            }
        }
        .onTapGesture {
            guard !selectedDoses.isEmpty else { return }
            let next: DoseStatus = allTaken ? .pending : .taken
            for slot in selectedDoses {
                store.setDoseStatus(
                    medicationId: lane.medicationId,
                    scheduleId: slot.schedule.id,
                    date: slot.date,
                    timeOfDay: slot.timeOfDay,
                    status: next,
                    existingLogId: slot.log?.id
                )
            }
        }
    }

    private func statusLabel(for lane: MedLane) -> String {
        let selectedDoses = doses.filter { $0.date == app.selectedDate && $0.medication.id == lane.medicationId }
        if selectedDoses.isEmpty { return app.t("diagram.noDose") }
        if selectedDoses.allSatisfy({ $0.status == .taken }) { return app.t("diagram.taken") }
        return app.t("diagram.notTaken")
    }

    private var pagerLabel: String {
        let info = CycleLogic.getDayCycleInfo(
            dateKey: app.selectedDate, periods: store.periods, settings: store.settings
        )
        let dayPart = app.t("diagram.dayBadge", ["day": "\(info.cycleDay ?? selectedIndex + 1)"])
        return "\(dayPart) · \(formatted(app.selectedDate))"
    }

    private func page(_ delta: Int) {
        let next = selectedIndex + delta
        guard days.indices.contains(next) else { return }
        app.selectedDate = days[next]
    }

    private func actionIcon(_ image: String, _ label: String, plus: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                Image(image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.blush200, lineWidth: 1))
                if plus {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.blush600)
                        .background(Circle().fill(.white).padding(2))
                }
            }
        }
        .accessibilityLabel(label)
        .buttonStyle(.plain)
    }

    private func chip(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text).font(.caption.weight(.semibold)).foregroundStyle(Theme.blush800)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.blush100))
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.inkMuted)
        }
    }

    private var introCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(app.t("diagram.emptyTitle"))
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(app.t("diagram.emptyBody"))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                hintRow("ActionPeriod", app.t("diagram.emptyAddPeriod"), plus: false) { showPeriod = true }
                hintRow("ActionMed", app.t("diagram.emptyAddMedHint"), plus: true) {
                    medSheet = MedSheetState(isNew: true, medication: nil)
                }
                hintRow("ActionSymptom", app.t("diagram.emptyAddSymptomHint"), plus: true) { showSymptom = true }
            }
            .padding(16)
        }
    }

    private func hintRow(_ image: String, _ text: String, plus: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    Image(image).resizable().scaledToFill().frame(width: 34, height: 34).clipShape(Circle())
                    if plus {
                        Image(systemName: "plus.circle.fill").font(.system(size: 12)).foregroundStyle(Theme.blush600)
                    }
                }
                Text(text).font(.subheadline).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func formatted(_ key: String) -> String {
        guard let date = DateKeys.parseDateKey(key) else { return key }
        let f = DateFormatter()
        f.locale = app.locale.language.locale
        f.setLocalizedDateFormatFromTemplate("EEE MMMd")
        return f.string(from: date)
    }
}

private extension Color {
    static let slate = Color(hex: "#94a3b8")
}

struct MedSheetState: Identifiable {
    let id = UUID()
    let isNew: Bool
    let medication: Medication?
}
