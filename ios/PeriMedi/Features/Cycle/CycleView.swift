import SwiftUI
import PeriMediDomain

struct CycleView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store

    @State private var medSheet: MedSheetState?
    @State private var showPeriod = false
    @State private var showSymptom = false
    @State private var openPeriodEditor = false
    @StateObject private var plotScroll = PlotScrollHandle()

    private let dayMin: CGFloat = 22
    private let labelCol: CGFloat = 156
    private let stripH: CGFloat = 46
    private let laneH: CGFloat = 44
    private let laneGap: CGFloat = 12
    private let laneBottomPad: CGFloat = 12
    private let cellInset: CGFloat = 1.5
    private let cellInsetY: CGFloat = 6

    var body: some View {
        let snap = CycleSnapshot.build(
            selectedDate: app.selectedDate,
            today: DateKeys.todayKey(),
            medications: store.medications,
            schedules: store.schedules,
            doseLogs: store.doseLogs,
            remarks: store.remarks,
            periods: store.periods,
            settings: store.settings
        )
        ScrollView {
            VStack(spacing: 12) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        pager(snap)
                        medsTitleRow
                        miniLegend
                        chart(snap)
                        if snap.hasDayBadges {
                            symptomChips(snap)
                        }
                    }
                    .padding(12)
                }
                if store.medications.isEmpty && store.periods.isEmpty {
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

    private func pager(_ snap: CycleSnapshot) -> some View {
        HStack(spacing: 4) {
            PillButton(title: app.t("common.today"), filled: false, identifier: A11yID.pagerToday) {
                app.goToToday()
                plotScroll.centerDay(snap.days.firstIndex(of: snap.today) ?? snap.selectedIndex)
            }
            chevron("left", app.t("diagram.prevDay"), snap.selectedIndex <= 0) { page(snap, -1) }
            chevron("right", app.t("diagram.nextDay"), snap.selectedIndex >= snap.days.count - 1) { page(snap, 1) }
            Text(pagerLabel(snap))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .accessibilityIdentifier(A11yID.pagerLabel)
                .accessibilityValue(pagerLabel(snap))
            Spacer(minLength: 0)
        }
    }

    private func chevron(_ dir: String, _ label: String, _ disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.\(dir)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.blush700)
                .frame(width: 36, height: 36)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .accessibilityLabel(label)
        .accessibilityIdentifier(dir == "left" ? A11yID.pagerPrev : A11yID.pagerNext)
        .buttonStyle(.plain)
    }

    private func symptomChips(_ snap: CycleSnapshot) -> some View {
        let info = snap.selectedInfo
        let notes = snap.selectedNotes
        return VStack(alignment: .leading, spacing: 6) {
            if info.isLoggedPeriod {
                chip(app.t("diagram.periodTitle"), Theme.blush600, identifier: A11yID.chipPeriod)
            } else if info.isPredictedPeriod {
                chip(app.t("diagram.predictedPeriodTitle"), Theme.blush400)
            }
            ForEach(notes.prefix(2)) { note in
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: "#7c3aed")).frame(width: 6, height: 6)
                    Text(note.body)
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#4c1d95"))
                        .lineLimit(1)
                    Button {
                        store.deleteRemark(id: note.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(hex: "#6d28d9"))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(app.t("common.delete"))
                }
                .padding(.leading, 10)
                .padding(.trailing, 4)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(hex: "#f5f3ff")))
                .overlay(Capsule().stroke(Color(hex: "#ede9fe"), lineWidth: 1))
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
                actionIcon("ActionPeriod", app.t("diagram.cycleSettings"), identifier: A11yID.actionPeriod) { showPeriod = true }
                actionIcon("ActionMed", app.t("diagram.addMed"), plus: true, identifier: A11yID.actionMed) {
                    medSheet = MedSheetState(isNew: true, medication: nil)
                }
                actionIcon("ActionSymptom", app.t("diagram.addSymptom"), plus: true, identifier: A11yID.actionSymptom) { showSymptom = true }
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

    private var showCyclePlot: Bool {
        !store.medications.isEmpty || !store.periods.isEmpty
    }

    private func chart(_ snap: CycleSnapshot) -> some View {
        VStack(spacing: 12) {
            if needsPeriod || needsMed {
                requirementsCard
            }
            if showCyclePlot {
                let plotHeight = stripH
                    + CGFloat(max(snap.lanes.count, 0)) * (laneH + laneGap)
                    + (snap.lanes.isEmpty ? 0 : laneBottomPad)
                HStack(alignment: .top, spacing: 0) {
                    stickyLabels(snap)
                        .frame(width: labelCol)
                        .background(Theme.cream)
                    GeometryReader { geo in
                        let colW = fittedColumnWidth(available: geo.size.width)
                        let plotWidth = max(CGFloat(snap.days.count) * colW, colW)
                        ZStack(alignment: .topLeading) {
                            CyclePlotScroll(
                                contentWidth: plotWidth,
                                contentHeight: plotHeight,
                                columnWidth: colW,
                                columnCount: snap.days.count,
                                contentRevision: snap.plotRevision,
                                focusColumn: snap.days.firstIndex(of: snap.today) ?? snap.selectedIndex,
                                focusToken: "\(snap.windowStart)#\(app.todayFocusNonce)",
                                onOffset: { plotScroll.state.offsetX = $0 },
                                scrollState: plotScroll.state,
                                onSelectDayIndex: { index in
                                    guard snap.days.indices.contains(index) else { return }
                                    app.selectedDate = snap.days[index]
                                }
                            ) {
                                plotCanvas(snap, width: plotWidth, columnWidth: colW, height: plotHeight)
                            }
                            .id("cycle-plot")
                            .transaction { $0.animation = nil }
                            DoseLabelOverlay(
                                lanes: snap.lanes,
                                plotWidth: plotWidth,
                                dayMin: colW,
                                stripH: stripH,
                                laneH: laneH,
                                laneGap: laneGap,
                                scroll: plotScroll.state,
                                daysRange: { from, to in
                                    app.t("diagram.daysRange", ["from": "\(from)", "to": "\(to)"])
                                }
                            )
                        }
                    }
                    .frame(height: plotHeight)
                    .clipped()
                }
            }
        }
    }

    private func fittedColumnWidth(available: CGFloat) -> CGFloat {
        guard available > 1 else { return dayMin }
        let count = max(1, Int(floor(available / dayMin)))
        return available / CGFloat(count)
    }

    private func stickyLabels(_ snap: CycleSnapshot) -> some View {
        VStack(alignment: .leading, spacing: laneGap) {
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
            .frame(height: stripH, alignment: .center)

            ForEach(snap.lanes) { lane in
                HStack(spacing: 6) {
                    Button {
                        toggleLane(lane, snap: snap)
                    } label: {
                        medAvatar(lane, snap: snap)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(A11yID.lane(lane.name))
                    .accessibilityLabel(lane.name)

                    Button {
                        if let med = store.medications.first(where: { $0.id == lane.medicationId }) {
                            medSheet = MedSheetState(isNew: false, medication: med)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(lane.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(2)
                            Text(statusLabel(for: lane, snap: snap))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(statusColor(for: lane, snap: snap))
                                .accessibilityIdentifier(A11yID.laneStatus(lane.name))
                                .accessibilityValue(statusValue(for: lane, snap: snap))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(A11yID.laneEdit(lane.name))
                }
                .frame(height: laneH, alignment: .leading)
            }
        }
        .padding(.bottom, snap.lanes.isEmpty ? 0 : laneBottomPad)
        .padding(.trailing, 6)
    }

    private func plotCanvas(_ snap: CycleSnapshot, width: CGFloat, columnWidth: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: laneGap) {
                dayStrip(snap, columnWidth: columnWidth)
                ForEach(snap.lanes) { lane in
                    doseTrack(lane, plotWidth: width, columnWidth: columnWidth)
                        .frame(height: laneH)
                }
            }
            .padding(.bottom, snap.lanes.isEmpty ? 0 : laneBottomPad)
            selectedColumn(snap, width: width, height: height)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func dayStrip(_ snap: CycleSnapshot, columnWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(snap.strip) { day in
                let info = day.info
                let isToday = day.dateKey == snap.today
                let isSelected = day.dateKey == snap.selectedDate
                VStack(spacing: 1) {
                    Group {
                        if info.isLoggedPeriod || info.isPredictedPeriod {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundStyle(info.isLoggedPeriod ? Color.red : Color.pink.opacity(0.55))
                        } else {
                            Color.clear
                        }
                    }
                    .frame(height: 13)
                    Group {
                        if day.hasSymptom {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundStyle(Color(hex: "#7c3aed"))
                        } else {
                            Color.clear
                        }
                    }
                    .frame(height: 10)
                    Text("\(day.index + 1)")
                        .font(.system(size: 11, weight: isToday || isSelected ? .semibold : .regular).monospacedDigit())
                        .foregroundStyle(isToday ? .white : isSelected ? Theme.blush700 : info.isLoggedPeriod ? Color(hex: "#9f1239") : Theme.inkMuted)
                        .frame(width: 18, height: 18)
                        .background {
                            if isToday {
                                Circle().fill(Theme.blush600)
                            }
                        }
                }
                .frame(width: columnWidth, height: stripH)
                .overlay(alignment: .trailing) {
                    Rectangle().fill(Theme.blush50).frame(width: 1)
                }
                .background(
                    info.isLoggedPeriod
                        ? Color.red.opacity(0.22)
                        : info.isPredictedPeriod
                            ? Color.red.opacity(0.08)
                            : Color.clear
                )
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(A11yID.stripDay(day.dateKey))
                .accessibilityLabel("\(day.index + 1)")
                .accessibilityValue(stripValue(info: info, hasSymptom: day.hasSymptom))
            }
        }
        .background(Rectangle().fill(Color.white.opacity(0.82)))
        .overlay(Rectangle().stroke(Theme.blush100, lineWidth: 1))
    }

    private func doseTrack(_ lane: MedLane, plotWidth: CGFloat, columnWidth colW: CGFloat) -> some View {
        let laneColor = Color(hex: lane.color)
        return Canvas { context, size in
            let track = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 6)
            context.fill(
                track,
                with: .linearGradient(
                    Gradient(colors: [Theme.blush50.opacity(0.4), Theme.lilac50.opacity(0.3)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: 0)
                )
            )
            context.stroke(track, with: .color(Theme.blush100.opacity(0.8)), lineWidth: 1)
            for seg in lane.segments {
                let x = CGFloat(seg.fromDay - 1) * colW + 1.5
                let w = max(CGFloat(seg.toDay - seg.fromDay + 1) * colW - 3, 6)
                let rect = CGRect(x: x, y: 0, width: w, height: size.height)
                let path = Path(roundedRect: rect, cornerRadius: 6)
                context.fill(path, with: .color(Color(hex: "#fffafb")))
                context.stroke(path, with: .color(laneColor.opacity(0.33)), lineWidth: 1)
            }
            for cell in lane.days where !cell.statuses.isEmpty && cell.statuses.allSatisfy({ $0 == .taken }) {
                let rect = CGRect(
                    x: CGFloat(cell.cycleDay - 1) * colW + 1,
                    y: 0,
                    width: max(colW - 2, 6),
                    height: size.height
                )
                context.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(laneColor.opacity(0.42)))
            }
        }
        .frame(width: plotWidth, height: laneH, alignment: .leading)
    }

    private func statusColor(for lane: MedLane, snap: CycleSnapshot) -> Color {
        let label = statusLabel(for: lane, snap: snap)
        if label == app.t("diagram.taken") { return Color(hex: lane.color) }
        if label == app.t("diagram.noDose") { return Theme.inkMuted }
        return Color(hex: "#64748b")
    }

    private func selectedColumn(_ snap: CycleSnapshot, width: CGFloat, height: CGFloat) -> some View {
        let colW = width / CGFloat(max(snap.days.count, 1))
        return Rectangle()
            .fill(Color(red: 232 / 255, green: 90 / 255, blue: 132 / 255).opacity(0.16))
            .frame(width: colW, height: height)
            .offset(x: CGFloat(snap.selectedIndex) * colW)
            .allowsHitTesting(false)
    }

    private func medAvatar(_ lane: MedLane, snap: CycleSnapshot) -> some View {
        let selectedDoses = snap.selectedDosesByMed[lane.medicationId] ?? []
        let allTaken = !selectedDoses.isEmpty && selectedDoses.allSatisfy { $0.status == .taken }
        let hasDose = !selectedDoses.isEmpty
        let ringColor: Color = {
            if allTaken { return Color(hex: lane.color) }
            if hasDose { return Color(hex: lane.color).opacity(0.6) }
            return Color(hex: "#f0d0da")
        }()
        return ZStack(alignment: .bottomTrailing) {
            Image(medFormImage(lane.form))
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .padding(3)
                .background(Circle().fill(ringColor))
                .opacity(hasDose ? 1 : 0.7)
            if allTaken {
                Text("✓")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color(hex: lane.color)))
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .offset(x: 2, y: 2)
            }
        }
    }

    private func toggleLane(_ lane: MedLane, snap: CycleSnapshot) {
        let selectedDoses = snap.selectedDosesByMed[lane.medicationId] ?? []
        guard !selectedDoses.isEmpty else { return }
        let allTaken = selectedDoses.allSatisfy { $0.status == .taken }
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

    private func statusValue(for lane: MedLane, snap: CycleSnapshot) -> String {
        let selectedDoses = snap.selectedDosesByMed[lane.medicationId] ?? []
        if selectedDoses.isEmpty { return "no-dose" }
        if selectedDoses.allSatisfy({ $0.status == .taken }) { return "taken" }
        return "not-taken"
    }

    private func stripValue(info: DayCycleInfo, hasSymptom: Bool) -> String {
        var parts: [String] = []
        if info.isLoggedPeriod { parts.append("period") }
        else if info.isPredictedPeriod { parts.append("predicted") }
        if hasSymptom { parts.append("symptom") }
        return parts.joined(separator: ",")
    }

    private func statusLabel(for lane: MedLane, snap: CycleSnapshot) -> String {
        let selectedDoses = snap.selectedDosesByMed[lane.medicationId] ?? []
        if selectedDoses.isEmpty { return app.t("diagram.noDose") }
        if selectedDoses.allSatisfy({ $0.status == .taken }) { return app.t("diagram.taken") }
        return app.t("diagram.notTaken")
    }

    private func pagerLabel(_ snap: CycleSnapshot) -> String {
        let dayPart = app.t("diagram.dayBadge", ["day": "\(snap.selectedInfo.cycleDay ?? snap.selectedIndex + 1)"])
        return "\(dayPart) · \(formatted(snap.selectedDate))"
    }

    private func page(_ snap: CycleSnapshot, _ delta: Int) {
        let next = snap.selectedIndex + delta
        guard snap.days.indices.contains(next) else { return }
        app.selectedDate = snap.days[next]
        plotScroll.centerIfAtBoundary(next)
    }

    private func actionIcon(
        _ image: String,
        _ label: String,
        plus: Bool = false,
        identifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                Image(image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
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
        .a11y(identifier)
        .buttonStyle(.plain)
    }

    private func chip(_ text: String, _ color: Color, identifier: String? = nil) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text).font(.caption.weight(.semibold)).foregroundStyle(Theme.blush800)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.blush100))
        .a11y(identifier)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.inkMuted)
        }
    }

    private var needsPeriod: Bool { store.periods.isEmpty }
    private var needsMed: Bool { store.medications.isEmpty }

    private var requirementsTitle: String {
        if needsPeriod && needsMed { return app.t("diagram.emptyMedsTitle") }
        if needsPeriod { return app.t("diagram.needPeriodTitle") }
        return app.t("diagram.needMedTitle")
    }

    private var requirementsValue: String {
        [needsPeriod ? "need-period" : nil, needsMed ? "need-med" : nil]
            .compactMap { $0 }
            .joined(separator: ",")
    }

    private var requirementsCard: some View {
        Text(requirementsTitle)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundStyle(Theme.blush200)
            )
            .accessibilityIdentifier(A11yID.emptyMeds)
            .accessibilityValue(requirementsValue)
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
        .accessibilityIdentifier(A11yID.intro)
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
        DateFormatCache.weekdayMonth(key, locale: app.locale.language.locale)
    }
}

private extension Color {
    static let slate = Color(hex: "#94a3b8")
}

/// Sticky dose meta lives outside the UIScrollView so scrolling stays native.
private struct DoseLabelOverlay: View {
    let lanes: [MedLane]
    let plotWidth: CGFloat
    let dayMin: CGFloat
    let stripH: CGFloat
    let laneH: CGFloat
    let laneGap: CGFloat
    @ObservedObject var scroll: PlotScrollState
    var daysRange: (Int, Int) -> String

    private let labelW: CGFloat = 120

    var body: some View {
        let colW = dayMin
        ZStack(alignment: .topLeading) {
            ForEach(Array(lanes.enumerated()), id: \.element.id) { index, lane in
                ForEach(lane.segments, id: \.fromDay) { seg in
                    if seg.toDay > seg.fromDay {
                        let startX = CGFloat(seg.fromDay - 1) * colW + 3
                        let endX = CGFloat(seg.toDay) * colW - 3
                        let stickX = scroll.offsetX + 4
                        let x = min(max(stickX, startX), max(startX, endX - labelW)) - scroll.offsetX
                        let y = stripH + laneGap + CGFloat(index) * (laneH + laneGap) + 6
                        VStack(alignment: .leading, spacing: 0) {
                            Text(seg.doseLabel)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Text(daysRange(seg.fromDay, seg.toDay))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Theme.inkSoft)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .frame(maxWidth: labelW, alignment: .leading)
                        .fixedSize()
                        .background(Color(hex: "#fffafb").opacity(0.45))
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Color(hex: lane.color)).frame(width: 2)
                        }
                        .offset(x: x, y: y)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

struct MedSheetState: Identifiable {
    let id = UUID()
    let isNew: Bool
    let medication: Medication?
}
