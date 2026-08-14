import Foundation
import PeriMediDomain

struct StripDay: Identifiable, Equatable {
    let dateKey: String
    let index: Int
    let info: DayCycleInfo
    let hasSymptom: Bool
    var id: String { dateKey }
}

struct CycleSnapshot: Equatable {
    let today: String
    let selectedDate: String
    let windowStart: String
    let windowLength: Int
    let days: [String]
    let strip: [StripDay]
    let lanes: [MedLane]
    let selectedDosesByMed: [String: [PlannedDose]]
    let selectedNotes: [Remark]
    let selectedInfo: DayCycleInfo
    let plotRevision: Int

    var selectedIndex: Int {
        days.firstIndex(of: selectedDate) ?? 0
    }

    var hasDayBadges: Bool {
        selectedInfo.isLoggedPeriod || selectedInfo.isPredictedPeriod || !selectedNotes.isEmpty
    }

    static func build(
        selectedDate: String,
        today: String,
        medications: [Medication],
        schedules: [Schedule],
        doseLogs: [DoseLog],
        remarks: [Remark],
        periods: [Period],
        settings: CycleSettings
    ) -> CycleSnapshot {
        let window = CycleLogic.cycleWindowForDate(
            dateKey: selectedDate,
            periods: periods,
            settings: settings
        )
        let days = (0..<window.length).map { DateKeys.addDaysKey(window.start, $0) }
        let lookup = CycleLogic.dayCycleLookup(periods: periods, settings: settings)
        let symptomDays = Set(
            remarks.compactMap { remark -> String? in
                guard remark.kind == .cycle || remark.kind == .side_effect || remark.kind == .note else {
                    return nil
                }
                return DateKeys.toDateKey(remark.occurredOn)
            }
        )
        let strip = days.enumerated().map { index, day in
            StripDay(
                dateKey: day,
                index: index,
                info: lookup.info(dateKey: day),
                hasSymptom: symptomDays.contains(day)
            )
        }
        let range = DoseRangeLogic.doseExpansionRange(
            today: today,
            selectedDate: selectedDate,
            periods: periods,
            settings: settings
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
        let lanes = MedLaneBuilder.build(doses: doses, cycleStart: window.start, cycleLen: window.length)
        var selectedDosesByMed: [String: [PlannedDose]] = [:]
        for dose in doses where dose.date == selectedDate {
            selectedDosesByMed[dose.medication.id, default: []].append(dose)
        }
        let selectedNotes = remarks.filter {
            DateKeys.toDateKey($0.occurredOn) == selectedDate
                && ($0.kind == .cycle || $0.kind == .side_effect || $0.kind == .note)
        }
        let selectedInfo = lookup.info(dateKey: selectedDate)
        var hasher = Hasher()
        hasher.combine(today)
        hasher.combine(selectedDate)
        hasher.combine(window.start)
        hasher.combine(window.length)
        for day in strip {
            hasher.combine(day.dateKey)
            hasher.combine(day.info.isLoggedPeriod)
            hasher.combine(day.info.isPredictedPeriod)
            hasher.combine(day.hasSymptom)
        }
        for lane in lanes {
            hasher.combine(lane.medicationId)
            hasher.combine(lane.color)
            for seg in lane.segments {
                hasher.combine(seg.fromDay)
                hasher.combine(seg.toDay)
                hasher.combine(seg.doseLabel)
                hasher.combine(seg.taken)
                hasher.combine(seg.pending)
            }
            for cell in lane.days {
                hasher.combine(cell.cycleDay)
                hasher.combine(cell.summary)
            }
        }
        return CycleSnapshot(
            today: today,
            selectedDate: selectedDate,
            windowStart: window.start,
            windowLength: window.length,
            days: days,
            strip: strip,
            lanes: lanes,
            selectedDosesByMed: selectedDosesByMed,
            selectedNotes: selectedNotes,
            selectedInfo: selectedInfo,
            plotRevision: hasher.finalize()
        )
    }
}

enum DateFormatCache {
    private static var weekdayMonth: DateFormatter?
    private static var weekdayMonthLocale: Locale?
    private static var monthYear: DateFormatter?
    private static var monthYearLocale: Locale?

    static func weekdayMonth(_ key: String, locale: Locale) -> String {
        if weekdayMonth == nil || weekdayMonthLocale != locale {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.setLocalizedDateFormatFromTemplate("EEE MMMd")
            weekdayMonth = formatter
            weekdayMonthLocale = locale
        }
        guard let date = DateKeys.parseDateKey(key) else { return key }
        return weekdayMonth?.string(from: date) ?? key
    }

    static func monthYear(_ date: Date, locale: Locale) -> String {
        if monthYear == nil || monthYearLocale != locale {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
            monthYear = formatter
            monthYearLocale = locale
        }
        return monthYear?.string(from: date) ?? ""
    }
}
