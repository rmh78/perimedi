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

        struct PreparedSchedule {
            let schedule: Schedule
            let start: String?
            let end: String?
            let weekdaySet: Set<Int>
            let times: [String]
        }
        let prepared: [PreparedSchedule] = schedules.compactMap { schedule in
            guard schedule.active else { return nil }
            guard medById[schedule.medicationId] != nil else { return nil }
            return PreparedSchedule(
                schedule: schedule,
                start: schedule.startDate.map(DateKeys.toDateKey),
                end: schedule.endDate.map(DateKeys.toDateKey),
                weekdaySet: Set(schedule.daysOfWeek),
                times: TherapyCycleLogic.getScheduleTimes(schedule)
            )
        }
        let lookup = CycleLogic.dayCycleLookup(periods: periods, settings: settings)

        var result: [PlannedDose] = []
        for day in DateKeys.eachDay(from: from, to: to) {
            let dateKey = DateKeys.toDateKey(day)
            let weekday = DateKeys.weekdaySundayZero(day)
            let cycleInfo = lookup.info(dateKey: dateKey)

            for item in prepared {
                if let start = item.start, dateKey < start { continue }
                if let end = item.end, dateKey > end { continue }
                if !item.weekdaySet.isEmpty && !item.weekdaySet.contains(weekday) { continue }
                if !CycleLogic.matchesCycleRule(
                    cycleInfo,
                    cycleRule: item.schedule.cycleRule,
                    cycleDayFrom: item.schedule.cycleDayFrom,
                    cycleDayTo: item.schedule.cycleDayTo
                ) { continue }

                let therapy = TherapyCycleLogic.matchTherapyCycle(schedule: item.schedule, dateKey: dateKey)
                if let therapy, !therapy.take { continue }
                guard let med = medById[item.schedule.medicationId] else { continue }

                for timeOfDay in item.times {
                    let log = logBySlot[logKey(scheduleId: item.schedule.id, dateKey: dateKey, timeOfDay: timeOfDay)]
                    result.append(
                        PlannedDose(
                            key: "\(item.schedule.id)-\(dateKey)-\(timeOfDay)",
                            date: dateKey,
                            timeOfDay: timeOfDay,
                            medication: med,
                            schedule: item.schedule,
                            doseLabel: therapy?.doseLabel ?? item.schedule.doseLabel ?? med.doseLabel,
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
