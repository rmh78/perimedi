import Foundation
import PeriMediDomain

struct DoseDayCell {
    var cycleDay: Int
    var dateKey: String?
    var doseLabel: String
    var statuses: [DoseStatus]
    var summary: String
}

struct DoseSegment {
    var fromDay: Int
    var toDay: Int
    var doseLabel: String
    var taken: Int
    var pending: Int
    var total: Int
}

struct MedLane: Identifiable {
    var medicationId: String
    var name: String
    var form: MedForm
    var defaultDose: String
    var color: String
    var days: [DoseDayCell]
    var segments: [DoseSegment]
    var id: String { medicationId }
}

enum MedLaneBuilder {
    static func build(doses: [PlannedDose], cycleStart: String, cycleLen: Int) -> [MedLane] {
        var dateToDay: [String: Int] = [:]
        for day in 1...cycleLen {
            dateToDay[DateKeys.addDaysKey(cycleStart, day - 1)] = day
        }

        struct Acc {
            var medication: Medication
            var color: String
            var byDay: [Int: (labels: Set<String>, statuses: [DoseStatus])]
        }
        var byMed: [String: Acc] = [:]

        for dose in doses {
            guard let cycleDay = dateToDay[dose.date], cycleDay >= 1, cycleDay <= cycleLen else { continue }
            var acc = byMed[dose.medication.id] ?? Acc(
                medication: dose.medication,
                color: MedColors.resolve(form: dose.medication.form, color: dose.medication.color),
                byDay: [:]
            )
            var cell = acc.byDay[cycleDay] ?? (labels: [], statuses: [])
            cell.labels.insert(dose.doseLabel)
            cell.statuses.append(dose.status)
            acc.byDay[cycleDay] = cell
            byMed[dose.medication.id] = acc
        }

        var lanes: [MedLane] = []
        for acc in byMed.values {
            var days: [DoseDayCell] = []
            for day in 1...cycleLen {
                guard let cell = acc.byDay[day] else { continue }
                days.append(
                    DoseDayCell(
                        cycleDay: day,
                        dateKey: DateKeys.addDaysKey(cycleStart, day - 1),
                        doseLabel: cell.labels.sorted().joined(separator: " + "),
                        statuses: cell.statuses,
                        summary: summarize(cell.statuses)
                    )
                )
            }
            days.sort { $0.cycleDay < $1.cycleDay }
            let segments = group(days)
            guard !segments.isEmpty else { continue }
            lanes.append(
                MedLane(
                    medicationId: acc.medication.id,
                    name: acc.medication.name,
                    form: acc.medication.form,
                    defaultDose: acc.medication.doseLabel,
                    color: acc.color,
                    days: days,
                    segments: segments
                )
            )
        }
        return lanes.sorted { $0.name < $1.name }
    }

    private static func summarize(_ statuses: [DoseStatus]) -> String {
        if statuses.isEmpty { return "open" }
        if statuses.allSatisfy({ $0 == .taken }) { return "taken" }
        if statuses.allSatisfy({ $0 == .pending }) { return "open" }
        return "mixed"
    }

    private static func group(_ days: [DoseDayCell]) -> [DoseSegment] {
        var segments: [DoseSegment] = []
        var current: DoseSegment?
        for day in days {
            let taken = day.statuses.filter { $0 == .taken }.count
            let pending = day.statuses.filter { $0 == .pending }.count
            let total = day.statuses.count
            if var cur = current, cur.doseLabel == day.doseLabel, day.cycleDay == cur.toDay + 1 {
                cur.toDay = day.cycleDay
                cur.taken += taken
                cur.pending += pending
                cur.total += total
                current = cur
            } else {
                if let existing = current { segments.append(existing) }
                current = DoseSegment(
                    fromDay: day.cycleDay, toDay: day.cycleDay, doseLabel: day.doseLabel,
                    taken: taken, pending: pending, total: total
                )
            }
        }
        if let existing = current { segments.append(existing) }
        return segments
    }
}
