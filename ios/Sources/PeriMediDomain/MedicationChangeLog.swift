import Foundation

public enum MedicationChangeLog {
    public static func snapshot(for schedule: Schedule) -> String {
        let times = TherapyCycleLogic.getScheduleTimes(schedule).joined(separator: ",")
        let start = schedule.startDate ?? ""
        let end = schedule.endDate ?? ""
        let range = end.isEmpty ? start : "\(start)..\(end)"
        if let tc = schedule.therapyCycle, tc.enabled, tc.mode == .on_off_days {
            return "\(tc.onDays)/\(tc.offDays) @ \(times) | \(range)"
        }
        if !schedule.daysOfWeek.isEmpty {
            let days = schedule.daysOfWeek.sorted().map(String.init).joined(separator: ",")
            return "days \(days) @ \(times) | \(range)"
        }
        return "every day @ \(times) | \(range)"
    }

    public static func events(
        previousMed: Medication?,
        newMed: Medication,
        previousSchedule: Schedule?,
        newSchedule: Schedule,
        effectiveDate: String,
        loggedAt: String
    ) -> [MedicationChange] {
        var out: [MedicationChange] = []
        let prevDose = previousMed?.doseLabel.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nextDose = newMed.doseLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if prevDose != nextDose {
            out.append(
                MedicationChange(
                    id: createId(),
                    medicationId: newMed.id,
                    nameSnapshot: newMed.name,
                    field: .dose,
                    previousValue: prevDose,
                    newValue: nextDose,
                    effectiveDate: DateKeys.toDateKey(effectiveDate),
                    loggedAt: loggedAt
                )
            )
        }
        let prevSched = previousSchedule.map(snapshot) ?? ""
        let nextSched = snapshot(for: newSchedule)
        if prevSched != nextSched {
            out.append(
                MedicationChange(
                    id: createId(),
                    medicationId: newMed.id,
                    nameSnapshot: newMed.name,
                    field: .schedule,
                    previousValue: prevSched,
                    newValue: nextSched,
                    effectiveDate: DateKeys.toDateKey(effectiveDate),
                    loggedAt: loggedAt
                )
            )
        }
        return out
    }
}
