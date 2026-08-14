import Foundation

/// Fictional perimenopause demo — same sketch as `web/src/lib/seed.ts`.
public enum SampleData {
    public static func payload(now: Date = Date()) -> ExportPayload {
        let today = DateKeys.calendar.startOfDay(for: now)
        let todayKey = DateKeys.toDateKey(today)
        let isoNow = ISO8601DateFormatter().string(from: now)

        let p1Start = DateKeys.addDays(today, -64)
        let p2Start = DateKeys.addDays(today, -36)
        let p3Start = DateKeys.addDays(today, -9)

        let periods: [Period] = [
            Period(
                id: createId(),
                startDate: DateKeys.toDateKey(p1Start),
                endDate: DateKeys.toDateKey(DateKeys.addDays(p1Start, 5)),
                flowNote: .heavy,
                notes: "Heavier than usual; clots day 2–3"
            ),
            Period(
                id: createId(),
                startDate: DateKeys.toDateKey(p2Start),
                endDate: DateKeys.toDateKey(DateKeys.addDays(p2Start, 4)),
                flowNote: .medium,
                notes: "Cycle ~28 days from previous start"
            ),
            Period(
                id: createId(),
                startDate: DateKeys.toDateKey(p3Start),
                endDate: DateKeys.toDateKey(DateKeys.addDays(p3Start, 4)),
                flowNote: .light,
                notes: "Slightly shorter cycle (~27d); lighter bleed"
            ),
        ]

        let e2Start = DateKeys.toDateKey(DateKeys.addDays(today, -60))
        let progStart = DateKeys.toDateKey(DateKeys.addDays(p2Start, 14))

        let estradiol = Medication(
            id: createId(), name: "Estradiol gel", form: .CREAM, doseLabel: "1 pump",
            instructions: "Apply to clean dry skin in the morning (arms/thighs)",
            color: "#9b6fc9", createdAt: isoNow
        )
        let progesterone = Medication(
            id: createId(), name: "Micronized progesterone", form: .PILL, doseLabel: "100 mg",
            instructions: "At bedtime; 14 days on, then pause (cyclic demo plan)",
            color: "#d43d6c", createdAt: isoNow
        )
        let magnesium = Medication(
            id: createId(), name: "Magnesium glycinate", form: .PILL, doseLabel: "200 mg",
            instructions: "Evening — may help sleep and muscle tension",
            color: "#0d9488", createdAt: isoNow
        )
        let vitaminD = Medication(
            id: createId(), name: "Vitamin D3", form: .PILL, doseLabel: "2000 IU",
            instructions: "With breakfast and a little fat",
            color: "#c97b3a", createdAt: isoNow
        )
        let iron = Medication(
            id: createId(), name: "Iron bisglycinate", form: .PILL, doseLabel: "25 mg",
            instructions: "Only on heavier flow days if advised by clinician",
            color: "#ea580c", createdAt: isoNow
        )
        let vaginal = Medication(
            id: createId(), name: "Vaginal moisturizer", form: .CREAM, doseLabel: "Thin application",
            instructions: "A few evenings per week",
            color: "#5b8fd9", createdAt: isoNow
        )

        let meds = [estradiol, progesterone, magnesium, vitaminD, iron, vaginal]

        func sched(
            med: Medication,
            time: String,
            days: [Int] = [],
            start: String,
            cycleRule: CycleRule = .none,
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
                cycleRule: cycleRule,
                therapyCycle: therapy
            )
        }

        let schedules: [Schedule] = [
            sched(med: estradiol, time: "07:30", start: e2Start),
            sched(
                med: progesterone,
                time: "21:00",
                start: progStart,
                therapy: TherapyCycle(
                    enabled: true, mode: .on_off_days, anchorDate: progStart, onDays: 14, offDays: 14
                ),
                doseLabel: "100 mg"
            ),
            sched(med: magnesium, time: "21:30", start: e2Start),
            sched(med: vitaminD, time: "08:00", start: e2Start),
            sched(med: iron, time: "12:00", start: DateKeys.toDateKey(p1Start), cycleRule: .period_only),
            sched(med: vaginal, time: "22:00", days: [1, 3, 5], start: e2Start),
        ]

        var doseLogs: [DoseLog] = []
        for daysAgo in stride(from: 6, through: 0, by: -1) {
            let date = DateKeys.toDateKey(DateKeys.addDays(today, -daysAgo))
            doseLogs.append(log(
                med: estradiol, schedule: schedules[0], date: date, time: "07:30",
                taken: !(daysAgo == 4)
            ))
            doseLogs.append(log(
                med: vitaminD, schedule: schedules[3], date: date, time: "08:00",
                taken: !(daysAgo == 2)
            ))
            doseLogs.append(log(
                med: magnesium, schedule: schedules[2], date: date, time: "21:30",
                taken: daysAgo != 1
            ))
        }
        for daysAgo in stride(from: 5, through: 0, by: -1) {
            let date = DateKeys.toDateKey(DateKeys.addDays(today, -daysAgo))
            doseLogs.append(log(
                med: progesterone, schedule: schedules[1], date: date, time: "21:00",
                taken: daysAgo != 3
            ))
        }
        for offset in 0...2 {
            let date = DateKeys.toDateKey(DateKeys.addDays(p3Start, offset))
            doseLogs.append(log(
                med: iron, schedule: schedules[4], date: date, time: "12:00", taken: true
            ))
        }

        let remarks: [Remark] = [
            Remark(id: createId(), occurredOn: DateKeys.toDateKey(p3Start), kind: .cycle,
                   body: "Cramps day 1, milder than last cycle.", createdAt: isoNow),
            Remark(id: createId(), occurredOn: DateKeys.toDateKey(DateKeys.addDays(p3Start, 1)), kind: .cycle,
                   body: "Joint stiffness in hands in the morning.", createdAt: isoNow),
            Remark(id: createId(), occurredOn: DateKeys.toDateKey(DateKeys.addDays(today, -6)), kind: .note,
                   body: "Mood dip late afternoon; short walk helped.", createdAt: isoNow),
            Remark(id: createId(), medicationId: estradiol.id,
                   occurredOn: DateKeys.toDateKey(DateKeys.addDays(today, -5)), kind: .side_effect,
                   body: "Mild breast tenderness; noted for next visit.", createdAt: isoNow),
            Remark(id: createId(), medicationId: progesterone.id,
                   occurredOn: DateKeys.toDateKey(DateKeys.addDays(today, -3)), kind: .side_effect,
                   body: "Sleepy next morning after progesterone — took earlier at 20:30.", createdAt: isoNow),
            Remark(id: createId(), occurredOn: DateKeys.toDateKey(DateKeys.addDays(today, -2)), kind: .cycle,
                   body: "Night sweats twice; woke at 3 a.m.", createdAt: isoNow),
            Remark(id: createId(), occurredOn: DateKeys.toDateKey(DateKeys.addDays(today, -1)), kind: .cycle,
                   body: "Hot flush after lunch; lasted ~3 minutes.", createdAt: isoNow),
            Remark(id: createId(), occurredOn: todayKey, kind: .cycle,
                   body: "Brain fog mid-morning; hard to focus.", createdAt: isoNow),
        ]

        return ExportPayload(
            version: 1,
            exportedAt: isoNow,
            medications: meds,
            schedules: schedules,
            doseLogs: doseLogs,
            remarks: remarks,
            cycleSettings: CycleSettings(averageCycleLength: 28, averagePeriodLength: 5),
            periods: periods
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
