import Foundation

public enum ScheduleLogic {
    public static func logKey(scheduleId: String, dateKey: String, timeOfDay: String) -> String {
        "\(scheduleId)|\(dateKey)|\(timeOfDay)"
    }

    public static func expandPlannedDoses(
        from: String,
        to: String,
        medications: [Medication],
        schedules: [Schedule],
        doseLogs: [DoseLog],
        periods: [Period],
        settings: CycleSettings
    ) -> [PlannedDose] {
        let medById = Dictionary(uniqueKeysWithValues: medications.map { ($0.id, $0) })
        var logBySlot: [String: DoseLog] = [:]
        for log in doseLogs {
            guard let scheduleId = log.scheduleId else { continue }
            let dateKey = DateKeys.toDateKey(log.plannedFor)
            let time: String
            if log.plannedFor.count >= 16 {
                let idx = log.plannedFor.index(log.plannedFor.startIndex, offsetBy: 11)
                let end = log.plannedFor.index(idx, offsetBy: 5)
                time = String(log.plannedFor[idx..<end])
            } else {
                time = "08:00"
            }
            logBySlot[logKey(scheduleId: scheduleId, dateKey: dateKey, timeOfDay: time)] = log
        }

        var result: [PlannedDose] = []
        for day in DateKeys.eachDay(from: from, to: to) {
            let dateKey = DateKeys.toDateKey(day)
            let weekday = DateKeys.weekdaySundayZero(day)
            let cycleInfo = CycleLogic.getDayCycleInfo(dateKey: dateKey, periods: periods, settings: settings)

            for schedule in schedules {
                if !schedule.active { continue }
                if let start = schedule.startDate, dateKey < DateKeys.toDateKey(start) { continue }
                if let end = schedule.endDate, dateKey > DateKeys.toDateKey(end) { continue }
                if !schedule.daysOfWeek.isEmpty && !schedule.daysOfWeek.contains(weekday) { continue }
                if !CycleLogic.matchesCycleRule(
                    cycleInfo,
                    cycleRule: schedule.cycleRule,
                    cycleDayFrom: schedule.cycleDayFrom,
                    cycleDayTo: schedule.cycleDayTo
                ) { continue }

                let therapy = TherapyCycleLogic.matchTherapyCycle(schedule: schedule, dateKey: dateKey)
                if let therapy, !therapy.take { continue }
                guard let med = medById[schedule.medicationId] else { continue }

                for timeOfDay in TherapyCycleLogic.getScheduleTimes(schedule) {
                    let log = logBySlot[logKey(scheduleId: schedule.id, dateKey: dateKey, timeOfDay: timeOfDay)]
                    result.append(
                        PlannedDose(
                            key: "\(schedule.id)-\(dateKey)-\(timeOfDay)",
                            date: dateKey,
                            timeOfDay: timeOfDay,
                            medication: med,
                            schedule: schedule,
                            doseLabel: therapy?.doseLabel ?? schedule.doseLabel ?? med.doseLabel,
                            log: log,
                            status: log?.status ?? .pending
                        )
                    )
                }
            }
        }

        result.sort {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.timeOfDay != $1.timeOfDay { return $0.timeOfDay < $1.timeOfDay }
            return $0.medication.name < $1.medication.name
        }
        return result
    }

    public static func plannedForIso(dateKey: String, timeOfDay: String) -> String {
        DateKeys.combineDateAndTime(dateKey: dateKey, timeOfDay: timeOfDay)
    }
}
