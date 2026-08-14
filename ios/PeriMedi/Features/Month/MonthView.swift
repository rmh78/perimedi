import SwiftUI
import PeriMediDomain

struct MonthView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @State private var monthAnchor = Date()

    private var grid: [Date] { DateKeys.monthGridDays(anchor: monthAnchor) }
    private var today: String { DateKeys.todayKey() }

    private var doses: [PlannedDose] {
        let from = DateKeys.toDateKey(grid.first!)
        let to = DateKeys.toDateKey(grid.last!)
        let range = DoseRangeLogic.doseExpansionRange(
            today: today,
            selectedDate: app.selectedDate,
            periods: store.periods,
            settings: store.settings,
            extraFrom: [from],
            extraTo: [to]
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

    var body: some View {
        ScrollView {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    pager
                    legend
                    calendar
                }
                .padding(12)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
    }

    private var pager: some View {
        HStack(spacing: 4) {
            PillButton(title: app.t("common.today"), filled: false) {
                monthAnchor = Date()
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

    private var calendar: some View {
        let marks = CycleLogic.cycleBoundaryMarkers(
            from: DateKeys.toDateKey(grid.first!),
            to: DateKeys.toDateKey(grid.last!),
            periods: store.periods,
            settings: store.settings
        )
        return VStack(spacing: 0) {
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
                ForEach(grid, id: \.self) { date in
                    cell(date, marks: marks)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.blush100, lineWidth: 1))
    }

    private func cell(_ date: Date, marks: [String: CycleBoundaryMark]) -> some View {
        let key = DateKeys.toDateKey(date)
        let inMonth = DateKeys.calendar.isDate(date, equalTo: monthAnchor, toGranularity: .month)
        let info = CycleLogic.getDayCycleInfo(dateKey: key, periods: store.periods, settings: store.settings)
        let mark = marks[key]
        let hasSymptom = store.remarks.contains {
            DateKeys.toDateKey($0.occurredOn) == key
                && ($0.kind == .cycle || $0.kind == .side_effect || $0.kind == .note)
        }
        let dayDoses = doses.filter { $0.date == key }
        let selected = key == app.selectedDate
        let isToday = key == today

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
                        Image(systemName: "bolt.fill").font(.system(size: 7)).foregroundStyle(Color(hex: "#7c3aed"))
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
            .overlay(alignment: .top) {
                if mark?.isStart == true {
                    Rectangle().fill(Color.slate).frame(height: 2)
                }
            }
            .overlay(alignment: .bottom) {
                if mark?.isEnd == true {
                    Rectangle().fill(Color.slate.opacity(0.7)).frame(height: 2)
                }
            }
            .overlay(
                Rectangle().stroke(selected ? Theme.blush500 : Theme.blush50, lineWidth: selected ? 2 : 0.5)
            )
            .opacity(inMonth ? 1 : 0.35)
        }
        .buttonStyle(.plain)
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
        let f = DateFormatter()
        f.locale = app.locale.language.locale
        f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return f.string(from: monthAnchor)
    }

    private func formatted(_ key: String) -> String {
        guard let date = DateKeys.parseDateKey(key) else { return key }
        let f = DateFormatter()
        f.locale = app.locale.language.locale
        f.setLocalizedDateFormatFromTemplate("EEE MMMd")
        return f.string(from: date)
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
                    Image(systemName: "bolt.fill").font(.system(size: 8)).foregroundStyle(Color(hex: "#7c3aed"))
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
