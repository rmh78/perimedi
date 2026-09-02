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

    public static func hasChanges(
        previousMed: Medication?,
        newMed: Medication,
        previousSchedule: Schedule?,
        newSchedule: Schedule
    ) -> Bool {
        !diffs(
            previousMed: previousMed,
            newMed: newMed,
            previousSchedule: previousSchedule,
            newSchedule: newSchedule
        ).isEmpty
    }

    public static func events(
        previousMed: Medication?,
        newMed: Medication,
        previousSchedule: Schedule?,
        newSchedule: Schedule,
        effectiveDate: String,
        loggedAt: String
    ) -> [MedicationChange] {
        diffs(
            previousMed: previousMed,
            newMed: newMed,
            previousSchedule: previousSchedule,
            newSchedule: newSchedule
        ).map { field, previousValue, newValue in
            MedicationChange(
                id: createId(),
                medicationId: newMed.id,
                nameSnapshot: newMed.name,
                field: field,
                previousValue: previousValue,
                newValue: newValue,
                effectiveDate: DateKeys.toDateKey(effectiveDate),
                loggedAt: loggedAt
            )
        }
    }

    private static func diffs(
        previousMed: Medication?,
        newMed: Medication,
        previousSchedule: Schedule?,
        newSchedule: Schedule
    ) -> [(MedicationChangeField, String, String)] {
        var out: [(MedicationChangeField, String, String)] = []
        let prevDose = previousMed?.doseLabel.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nextDose = newMed.doseLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if prevDose != nextDose {
            out.append((.dose, prevDose, nextDose))
        }
        let prevSched = previousSchedule.map(snapshot) ?? ""
        let nextSched = snapshot(for: newSchedule)
        if prevSched != nextSched {
            out.append((.schedule, prevSched, nextSched))
        }
        return out
    }
}
