import SwiftUI
import PeriMediDomain

struct MonthView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @State private var monthAnchor: Date = DateKeys.parseDateKey(DateKeys.todayKey()) ?? Date()

    var body: some View {
        let model = MonthGridModel.build(
            monthAnchor: monthAnchor,
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
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    pager
                    legend
                    calendar(model)
                }
                .padding(12)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .onChange(of: app.todayFocusNonce) { _, _ in
            monthAnchor = DateKeys.parseDateKey(DateKeys.todayKey()) ?? Date()
        }
    }

    private var pager: some View {
        HStack(spacing: 4) {
            PillButton(title: app.t("common.today"), kind: .secondary, identifier: A11yID.pagerToday) {
                monthAnchor = DateKeys.parseDateKey(DateKeys.todayKey()) ?? Date()
                app.goToToday()
            }
            Button {
                monthAnchor = DateKeys.addMonths(monthAnchor, -1)
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.blush700).frame(width: 32, height: 32)
            }
            .accessibilityLabel(app.t("month.prevMonth"))
            .buttonStyle(.plain)
            Button {
                monthAnchor = DateKeys.addMonths(monthAnchor, 1)
            } label: {
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.blush700).frame(width: 32, height: 32)
            }
            .accessibilityLabel(app.t("month.nextMonth"))
            .buttonStyle(.plain)
            Text(monthTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
    }

    private var legend: some View {
        FlowLegend(app: app)
    }

    private func calendar(_ model: MonthGridModel) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(app.t("weekday.\(i)"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.inkMuted)
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            .background(Theme.blush50)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(model.cells) { item in
                    cell(item)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.blush100, lineWidth: 1))
    }

    private func cell(_ item: MonthDayCell) -> some View {
        let key = item.key
        let inMonth = item.inMonth
        let info = item.info
        let mark = item.mark
        let hasSymptom = item.hasSymptom
        let dayDoses = item.dayDoses
        let selected = item.selected
        let isToday = item.isToday
        let date = item.date

        return Button {
            app.selectedDate = key
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 2) {
                    Text("\(DateKeys.calendar.component(.day, from: date))")
                        .font(.caption.weight(isToday || selected ? .bold : .regular))
                        .foregroundStyle(isToday ? .white : Theme.ink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(isToday ? Theme.blush600 : .clear))
                    if info.isLoggedPeriod || info.isPredictedPeriod {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(info.isLoggedPeriod ? Color.red : Color.pink.opacity(0.55))
                    }
                }
                if let day = info.cycleDay {
                    Text("D\(day)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.slate)
                        .padding(.horizontal, 4)
                        .background(Capsule().fill(Color.black.opacity(0.06)))
                }
                HStack(spacing: 2) {
                    if hasSymptom {
                        Image(systemName: "bolt.fill").font(.system(size: 7)).foregroundStyle(Theme.symptom)
                    }
                    ForEach(dayDoses.prefix(3)) { dose in
                        Circle()
                            .fill(dose.status == .taken ? Theme.taken : Theme.pending)
                            .frame(width: 5, height: 5)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
            .padding(4)
            .background(
                info.isLoggedPeriod ? Color.red.opacity(0.16)
                    : info.isPredictedPeriod ? Color.pink.opacity(0.08)
                    : Color.white.opacity(0.5)
            )
            .overlay {
                if mark?.isStart == true {
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.slate).frame(height: 2)
                        HStack(spacing: 0) {
                            Rectangle().fill(Color.slate).frame(width: 2, height: 10)
                            Spacer(minLength: 0)
                        }
                        Spacer(minLength: 0)
                    }
                    .allowsHitTesting(false)
                }
            }
            .overlay {
                if mark?.isEnd == true {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Rectangle().fill(Color.slate.opacity(0.7)).frame(width: 2, height: 10)
                        }
                        Rectangle().fill(Color.slate.opacity(0.7)).frame(height: 2)
                    }
                    .allowsHitTesting(false)
                }
            }
            .overlay(
                Rectangle().stroke(selected ? Theme.blush500 : Theme.blush50, lineWidth: selected ? 2 : 0.5)
            )
            .opacity(inMonth ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(A11yID.monthDay(key))
        .accessibilityValue(monthValue(
            selected: selected,
            isPeriod: info.isLoggedPeriod,
            hasSymptom: hasSymptom,
            hasTaken: dayDoses.contains { $0.status == .taken }
        ))
    }

    private func monthValue(
        selected: Bool,
        isPeriod: Bool,
        hasSymptom: Bool,
        hasTaken: Bool
    ) -> String {
        var parts: [String] = []
        if selected { parts.append("selected") }
        if isPeriod { parts.append("period") }
        if hasTaken { parts.append("taken") }
        if hasSymptom { parts.append("symptom") }
        return parts.joined(separator: ",")
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.blush700)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .overlay(Capsule().stroke(Theme.blush300, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var monthTitle: String {
        DateFormatCache.monthYear(monthAnchor, locale: app.locale.language.locale)
    }
}

private struct MonthDayCell: Identifiable {
    let date: Date
    let key: String
    var id: String { key }
    let inMonth: Bool
    let info: DayCycleInfo
    let mark: CycleBoundaryMark?
    let hasSymptom: Bool
    let dayDoses: [PlannedDose]
    let selected: Bool
    let isToday: Bool
}

private struct MonthGridModel {
    let cells: [MonthDayCell]

    static func build(
        monthAnchor: Date,
        selectedDate: String,
        today: String,
        medications: [Medication],
        schedules: [Schedule],
        doseLogs: [DoseLog],
        remarks: [Remark],
        periods: [Period],
        settings: CycleSettings
    ) -> MonthGridModel {
        let grid = DateKeys.monthGridDays(anchor: monthAnchor)
        let from = DateKeys.toDateKey(grid.first!)
        let to = DateKeys.toDateKey(grid.last!)
        let range = DoseRangeLogic.doseExpansionRange(
            today: today,
            selectedDate: selectedDate,
            periods: periods,
            settings: settings,
            extraFrom: [from],
            extraTo: [to]
        )
        let doses = ScheduleLogic.expandPlannedDoses(
            from: range.from,
            to: range.to,
            medications: medications,
            schedules: schedules,
            doseLogs: doseLogs,
            periods: periods,
            settings: settings
        )
        var dosesByDay: [String: [PlannedDose]] = [:]
        dosesByDay.reserveCapacity(grid.count)
        for dose in doses {
            dosesByDay[dose.date, default: []].append(dose)
        }
        let lookup = CycleLogic.dayCycleLookup(periods: periods, settings: settings)
        let marks = CycleLogic.cycleBoundaryMarkers(from: from, to: to, periods: periods, settings: settings)
        let symptomDays = Set(
            remarks.compactMap { remark -> String? in
                guard remark.kind == .cycle || remark.kind == .side_effect || remark.kind == .note else {
                    return nil
                }
                return DateKeys.toDateKey(remark.occurredOn)
            }
        )
        let cells = grid.map { date -> MonthDayCell in
            let key = DateKeys.toDateKey(date)
            return MonthDayCell(
                date: date,
                key: key,
                inMonth: DateKeys.calendar.isDate(date, equalTo: monthAnchor, toGranularity: .month),
                info: lookup.info(dateKey: key),
                mark: marks[key],
                hasSymptom: symptomDays.contains(key),
                dayDoses: dosesByDay[key] ?? [],
                selected: key == selectedDate,
                isToday: key == today
            )
        }
        return MonthGridModel(cells: cells)
    }
}

private struct FlowLegend: View {
    @ObservedObject var app: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.slate).frame(width: 12, height: 2)
                        HStack { Rectangle().fill(Color.slate).frame(width: 2, height: 6); Spacer() }
                    }
                    .frame(width: 12, height: 10)
                    Text(app.t("legend.cycleStart")).font(.caption2).foregroundStyle(Theme.inkSoft)
                }
                HStack(spacing: 4) {
                    VStack(spacing: 0) {
                        HStack { Spacer(); Rectangle().fill(Color.slate).frame(width: 2, height: 6) }
                        Rectangle().fill(Color.slate).frame(width: 12, height: 2)
                    }
                    .frame(width: 12, height: 10)
                    Text(app.t("legend.cycleEnd")).font(.caption2).foregroundStyle(Theme.inkSoft)
                }
                HStack(spacing: 4) {
                    Text("D12").font(.system(size: 9, weight: .semibold)).padding(.horizontal, 4).background(Capsule().fill(Color.black.opacity(0.06)))
                    Text(app.t("legend.cycleDay")).font(.caption2).foregroundStyle(Theme.inkSoft)
                }
            }
            HStack(spacing: 10) {
                legend(app.t("legend.period"), Color.red)
                legend(app.t("legend.predicted"), Color.pink.opacity(0.6))
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill").font(.system(size: 8)).foregroundStyle(Theme.symptom)
                    Text(app.t("legend.symptom")).font(.caption2).foregroundStyle(Theme.inkSoft)
                }
                legend(app.t("legend.taken"), Theme.taken)
                legend(app.t("legend.notTaken"), Theme.pending)
            }
        }
    }

    private func legend(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title).font(.caption2).foregroundStyle(Theme.inkSoft)
        }
    }
}

private extension Color {
    static let slate = Color(hex: "#64748b")
}
