import Foundation

/// Fictional perimenopause demo for a woman about 40 (range 35–45).
/// Not medical advice — typical HRT + irregular cycles for the UI, not a protocol.
public enum SampleData {
    public static func payload(now: Date = Date()) -> ExportPayload {
        let today = DateKeys.calendar.startOfDay(for: now)
        let isoNow = ISO8601DateFormatter().string(from: now)

        func key(_ daysAgo: Int) -> String {
            DateKeys.toDateKey(DateKeys.addDays(today, -daysAgo))
        }
        func endKey(startAgo: Int, length: Int) -> String {
            key(startAgo - (length - 1))
        }

        // Irregular starts (peri): ~29d, ~33d, ~24d, then current cycle day 18.
        let periods: [Period] = [
            Period(
                id: createId(),
                startDate: key(103),
                endDate: endKey(startAgo: 103, length: 5),
                flowNote: .medium
            ),
            Period(
                id: createId(),
                startDate: key(74),
                endDate: endKey(startAgo: 74, length: 7),
                flowNote: .heavy
            ),
            Period(
                id: createId(),
                startDate: key(41),
                endDate: endKey(startAgo: 41, length: 3),
                flowNote: .light
            ),
            Period(
                id: createId(),
                startDate: key(17),
                endDate: endKey(startAgo: 17, length: 5),
                flowNote: .medium
            ),
        ]

        let hrtStart = key(90)
        let progAnchor = key(17 - 14)

        let estradiol = Medication(
            id: createId(), name: "Estradiol gel", form: .CREAM, doseLabel: "1 pump",
            instructions: "Apply to clean dry skin in the morning",
            color: "#9b6fc9", createdAt: isoNow
        )
        let progesterone = Medication(
            id: createId(), name: "Micronized progesterone", form: .PILL, doseLabel: "100 mg",
            instructions: "At bedtime; 14 days on, 14 days off",
            color: "#d43d6c", createdAt: isoNow
        )
        let vaginalE2 = Medication(
            id: createId(), name: "Vaginal estradiol", form: .CREAM, doseLabel: "10 mcg",
            instructions: "Monday and Thursday evenings",
            color: "#5b8fd9", createdAt: isoNow
        )
        let magnesium = Medication(
            id: createId(), name: "Magnesium glycinate", form: .PILL, doseLabel: "200 mg",
            instructions: "Evening — sleep and muscle tension",
            color: "#0d9488", createdAt: isoNow
        )
        let vitaminD = Medication(
            id: createId(), name: "Vitamin D3", form: .PILL, doseLabel: "2000 IU",
            instructions: "With breakfast",
            color: "#c97b3a", createdAt: isoNow
        )

        let meds = [estradiol, progesterone, vaginalE2, magnesium, vitaminD]

        func sched(
            med: Medication,
            time: String,
            days: [Int] = [],
            start: String,
            therapy: TherapyCycle? = nil,
            doseLabel: String? = nil
        ) -> Schedule {
            Schedule(
                id: createId(),
                medicationId: med.id,
                daysOfWeek: days,
                timeOfDay: time,
                times: [time],
                doseLabel: doseLabel,
                active: true,
                startDate: start,
                cycleRule: .none,
                therapyCycle: therapy
            )
        }

        let schedules: [Schedule] = [
            sched(med: estradiol, time: "07:30", start: hrtStart),
            sched(
                med: progesterone,
                time: "21:00",
                start: hrtStart,
                therapy: TherapyCycle(
                    enabled: true,
                    mode: .on_off_days,
                    anchorDate: progAnchor,
                    onDays: 14,
                    offDays: 14
                ),
                doseLabel: "100 mg"
            ),
            sched(med: vaginalE2, time: "21:30", days: [1, 4], start: hrtStart),
            sched(med: magnesium, time: "21:45", start: hrtStart),
            sched(med: vitaminD, time: "08:00", start: hrtStart),
        ]

        var doseLogs: [DoseLog] = []
        for daysAgo in stride(from: 6, through: 0, by: -1) {
            let date = key(daysAgo)
            doseLogs.append(log(med: estradiol, schedule: schedules[0], date: date, time: "07:30", taken: daysAgo != 4))
            doseLogs.append(log(med: vitaminD, schedule: schedules[4], date: date, time: "08:00", taken: daysAgo != 2))
            doseLogs.append(log(med: magnesium, schedule: schedules[3], date: date, time: "21:45", taken: daysAgo != 1))
            doseLogs.append(log(med: progesterone, schedule: schedules[1], date: date, time: "21:00", taken: daysAgo != 3))
        }

        func score(_ id: SymptomId, daysAgo: Int, severity: Int) -> SymptomScore {
            SymptomScore(
                id: id.rawValue,
                date: key(daysAgo),
                severity: severity,
                loggedAt: isoNow,
                higherIsWorse: true
            )
        }

        // Cluster around the recent bleed and typical peri nights/days.
        let symptomScores: [SymptomScore] = [
            score(.hot_flash, daysAgo: 0, severity: 3),
            score(.sleep, daysAgo: 0, severity: 3),
            score(.heart, daysAgo: 0, severity: 1),
            score(.exhaustion, daysAgo: 0, severity: 2),
            score(.sexual, daysAgo: 0, severity: 2),
            score(.vaginal_dryness, daysAgo: 0, severity: 2),
            score(.hot_flash, daysAgo: 1, severity: 2),
            score(.sleep, daysAgo: 1, severity: 2),
            score(.mood, daysAgo: 1, severity: 2),
            score(.joints, daysAgo: 2, severity: 2),
            score(.irritability, daysAgo: 2, severity: 1),
            score(.hot_flash, daysAgo: 3, severity: 2),
            score(.sleep, daysAgo: 4, severity: 3),
            score(.anxiety, daysAgo: 5, severity: 2),
            score(.exhaustion, daysAgo: 6, severity: 2),
            score(.bladder, daysAgo: 8, severity: 1),
            score(.hot_flash, daysAgo: 12, severity: 3),
            score(.sleep, daysAgo: 13, severity: 3),
            score(.mood, daysAgo: 14, severity: 3),
            score(.joints, daysAgo: 16, severity: 2),
            score(.hot_flash, daysAgo: 17, severity: 2),
        ]

        return ExportPayload(
            version: 1,
            exportedAt: isoNow,
            medications: meds,
            schedules: schedules,
            doseLogs: doseLogs,
            remarks: [],
            cycleSettings: CycleSettings(averageCycleLength: 30, averagePeriodLength: 5),
            periods: periods,
            symptomScores: symptomScores
        )
    }

    private static func log(
        med: Medication,
        schedule: Schedule,
        date: String,
        time: String,
        taken: Bool
    ) -> DoseLog {
        DoseLog(
            id: createId(),
            medicationId: med.id,
            scheduleId: schedule.id,
            plannedFor: ScheduleLogic.plannedForIso(dateKey: date, timeOfDay: time),
            status: taken ? .taken : .pending,
            confirmedAt: taken ? ISO8601DateFormatter().string(from: Date()) : nil
        )
    }
}
