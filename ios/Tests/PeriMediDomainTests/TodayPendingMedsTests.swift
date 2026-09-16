import XCTest
@testable import PeriMediDomain

final class TodayPendingMedsTests: XCTestCase {
    let settings = CycleSettings(averageCycleLength: 28, averagePeriodLength: 5)

    func med(
        id: String = "m1",
        name: String = "Estrogen",
        reminders: Bool = true
    ) -> Medication {
        Medication(
            id: id,
            name: name,
            form: .PILL,
            doseLabel: "1 mg",
            createdAt: "t",
            remindersEnabled: reminders
        )
    }

    func sched(
        id: String = "s1",
        medicationId: String = "m1",
        times: [String] = ["08:00"],
        mutate: (inout Schedule) -> Void = { _ in }
    ) -> Schedule {
        var s = Schedule(
            id: id,
            medicationId: medicationId,
            daysOfWeek: [],
            timeOfDay: times[0],
            times: times,
            active: true,
            cycleRule: .none
        )
        mutate(&s)
        return s
    }

    func nowOn(_ dateKey: String, time: String) -> Date {
        DateKeys.date(dateKey: dateKey, timeOfDay: time)!
    }

    func log(
        medicationId: String = "m1",
        scheduleId: String = "s1",
        date: String,
        time: String,
        status: DoseStatus = .taken
    ) -> DoseLog {
        DoseLog(
            id: "l-\(scheduleId)-\(date)-\(time)",
            medicationId: medicationId,
            scheduleId: scheduleId,
            plannedFor: DateKeys.combineDateAndTime(dateKey: date, timeOfDay: time),
            status: status,
            confirmedAt: "t"
        )
    }

    func list(
        now: Date,
        medications: [Medication]? = nil,
        schedules: [Schedule]? = nil,
        logs: [DoseLog] = []
    ) -> [TodayPendingMedication] {
        TodayPendingMeds.list(
            now: now,
            medications: medications ?? [med()],
            schedules: schedules ?? [sched()],
            doseLogs: logs,
            periods: [],
            settings: settings
        )
    }

    func testOverdueTimeTodayIsIncluded() {
        let meds = list(now: nowOn("2026-08-07", time: "09:00"))
        XCTAssertEqual(meds.map(\.medication.id), ["m1"])
        XCTAssertEqual(meds.first?.pending.map(\.timeOfDay), ["08:00"])
        XCTAssertEqual(meds.first?.pending.first?.status, .pending)
        XCTAssertEqual(meds.first?.date, "2026-08-07")
    }

    func testGroupsTwoTimesOnOneMedication() {
        let meds = list(
            now: nowOn("2026-08-07", time: "09:00"),
            schedules: [sched(times: ["08:00", "20:00"])]
        )
        XCTAssertEqual(meds.map(\.medication.id), ["m1"])
        XCTAssertEqual(meds.first?.pending.map(\.timeOfDay), ["08:00", "20:00"])
    }

    func testTakenMorningLeavesEveningOnSameMedication() {
        let meds = list(
            now: nowOn("2026-08-07", time: "09:00"),
            schedules: [sched(times: ["08:00", "20:00"])],
            logs: [log(date: "2026-08-07", time: "08:00")]
        )
        XCTAssertEqual(meds.map(\.medication.id), ["m1"])
        XCTAssertEqual(meds.first?.pending.map(\.timeOfDay), ["20:00"])
    }

    func testTakenDropsMedicationWhenAllSlotsTaken() {
        let meds = list(
            now: nowOn("2026-08-07", time: "09:00"),
            schedules: [sched(times: ["08:00", "20:00"])],
            logs: [
                log(date: "2026-08-07", time: "08:00"),
                log(date: "2026-08-07", time: "20:00"),
            ]
        )
        XCTAssertTrue(meds.isEmpty)
    }

    func testPendingLogAfterUntakeReturnsMedication() {
        let taken = list(
            now: nowOn("2026-08-07", time: "09:00"),
            logs: [log(date: "2026-08-07", time: "08:00", status: .taken)]
        )
        XCTAssertTrue(taken.isEmpty)

        let pending = list(
            now: nowOn("2026-08-07", time: "09:00"),
            logs: [log(date: "2026-08-07", time: "08:00", status: .pending)]
        )
        XCTAssertEqual(pending.map(\.medication.id), ["m1"])
        XCTAssertEqual(pending.first?.pending.map(\.timeOfDay), ["08:00"])
    }

    func testTomorrowOnlyPendingYieldsEmptyToday() {
        let meds = list(
            now: nowOn("2026-08-07", time: "09:00"),
            schedules: [sched { $0.startDate = "2026-08-08" }]
        )
        XCTAssertTrue(meds.isEmpty)
    }

    func testDoesNotIncludeTomorrowWhenTodayHasPending() {
        let meds = list(
            now: nowOn("2026-08-07", time: "09:00"),
            schedules: [sched(times: ["08:00"])]
        )
        XCTAssertEqual(meds.flatMap(\.pending).map(\.date), ["2026-08-07"])
        XCTAssertFalse(meds.flatMap(\.pending).contains { $0.date == "2026-08-08" })
    }

    func testSortsByEarliestPendingThenMedicationName() {
        let alpha = med(id: "ma", name: "Alpha")
        let zest = med(id: "mz", name: "Zest")
        let laterAlpha = sched(id: "sa", medicationId: "ma", times: ["09:00"])
        let earlierZest = sched(id: "sz", medicationId: "mz", times: ["08:00"])
        let byTime = list(
            now: nowOn("2026-08-07", time: "07:00"),
            medications: [alpha, zest],
            schedules: [laterAlpha, earlierZest]
        )
        XCTAssertEqual(byTime.map(\.medication.name), ["Zest", "Alpha"])

        let sameTimeAlpha = sched(id: "sa2", medicationId: "ma", times: ["08:00"])
        let byName = list(
            now: nowOn("2026-08-07", time: "07:00"),
            medications: [zest, alpha],
            schedules: [earlierZest, sameTimeAlpha]
        )
        XCTAssertEqual(byName.map(\.medication.name), ["Alpha", "Zest"])
    }

    func testReminderOffIsStillIncluded() {
        let meds = list(
            now: nowOn("2026-08-07", time: "07:00"),
            medications: [med(reminders: false)]
        )
        XCTAssertEqual(meds.map(\.medication.id), ["m1"])
        XCTAssertEqual(meds.first?.pending.map(\.timeOfDay), ["08:00"])
    }

    func testCyclicPauseIsExcluded() {
        let meds = list(
            now: nowOn("2026-08-08", time: "07:00"),
            schedules: [sched {
                $0.therapyCycle = TherapyCycle(
                    enabled: true,
                    mode: .on_off_days,
                    anchorDate: "2026-08-07",
                    onDays: 1,
                    offDays: 1
                )
            }]
        )
        XCTAssertTrue(meds.isEmpty)
    }

    func testEmptyWhenNothingPendingToday() {
        let meds = list(
            now: nowOn("2026-08-07", time: "07:00"),
            schedules: [sched { $0.startDate = "2026-08-22" }]
        )
        XCTAssertTrue(meds.isEmpty)
    }

    func testInitDropsEmptyOrTakenGroups() {
        XCTAssertNil(TodayPendingMedication(medication: med(), pending: []))
        let taken = PlannedDose(
            key: "s1-2026-08-07-08:00",
            date: "2026-08-07",
            timeOfDay: "08:00",
            medication: med(),
            schedule: sched(),
            doseLabel: "1 mg",
            log: log(date: "2026-08-07", time: "08:00"),
            status: .taken
        )
        XCTAssertNil(TodayPendingMedication(medication: med(), pending: [taken]))
    }
}
