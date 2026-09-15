import XCTest
@testable import PeriMediDomain

final class NextPendingDoseTests: XCTestCase {
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
        scheduleId: String = "s1",
        date: String,
        time: String,
        status: DoseStatus = .taken
    ) -> DoseLog {
        DoseLog(
            id: "l-\(scheduleId)-\(date)-\(time)",
            medicationId: "m1",
            scheduleId: scheduleId,
            plannedFor: DateKeys.combineDateAndTime(dateKey: date, timeOfDay: time),
            status: status,
            confirmedAt: "t"
        )
    }

    func select(
        now: Date,
        medications: [Medication]? = nil,
        schedules: [Schedule]? = nil,
        logs: [DoseLog] = []
    ) -> PlannedDose? {
        NextPendingDose.select(
            now: now,
            medications: medications ?? [med()],
            schedules: schedules ?? [sched()],
            doseLogs: logs,
            periods: [],
            settings: settings
        )
    }

    func testSelectsOverdueTimeToday() {
        let dose = select(now: nowOn("2026-08-07", time: "09:00"))
        XCTAssertEqual(dose?.date, "2026-08-07")
        XCTAssertEqual(dose?.timeOfDay, "08:00")
        XCTAssertEqual(dose?.status, .pending)
    }

    func testTakenSlotYieldsLaterTimeSameDay() {
        let dose = select(
            now: nowOn("2026-08-07", time: "09:00"),
            schedules: [sched(times: ["08:00", "20:00"])],
            logs: [log(date: "2026-08-07", time: "08:00")]
        )
        XCTAssertEqual(dose?.date, "2026-08-07")
        XCTAssertEqual(dose?.timeOfDay, "20:00")
    }

    func testCyclicPauseIsExcluded() {
        let dose = select(
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
        XCTAssertEqual(dose?.date, "2026-08-09")
        XCTAssertEqual(dose?.timeOfDay, "08:00")
    }

    func testReminderOffIsStillSelected() {
        let dose = select(
            now: nowOn("2026-08-07", time: "07:00"),
            medications: [med(reminders: false)]
        )
        XCTAssertEqual(dose?.medication.id, "m1")
        XCTAssertEqual(dose?.date, "2026-08-07")
        XCTAssertEqual(dose?.timeOfDay, "08:00")
    }

    func testSortsByFireAtThenMedicationName() {
        let alpha = med(id: "ma", name: "Alpha")
        let zest = med(id: "mz", name: "Zest")
        let laterAlpha = sched(id: "sa", medicationId: "ma", times: ["09:00"])
        let earlierZest = sched(id: "sz", medicationId: "mz", times: ["08:00"])
        let byTime = select(
            now: nowOn("2026-08-07", time: "07:00"),
            medications: [alpha, zest],
            schedules: [laterAlpha, earlierZest]
        )
        XCTAssertEqual(byTime?.medication.name, "Zest")
        XCTAssertEqual(byTime?.timeOfDay, "08:00")

        let sameTimeAlpha = sched(id: "sa2", medicationId: "ma", times: ["08:00"])
        let byName = select(
            now: nowOn("2026-08-07", time: "07:00"),
            medications: [zest, alpha],
            schedules: [earlierZest, sameTimeAlpha]
        )
        XCTAssertEqual(byName?.medication.name, "Alpha")
    }

    func testEmptyWhenNothingPendingInHorizon() {
        let dose = select(
            now: nowOn("2026-08-07", time: "07:00"),
            schedules: [sched { $0.startDate = "2026-08-22" }]
        )
        XCTAssertNil(dose)
    }

    func testDoesNotSelectYesterday() {
        let dose = select(now: nowOn("2026-08-07", time: "09:00"))
        XCTAssertNotEqual(dose?.date, "2026-08-06")
        XCTAssertEqual(dose?.date, "2026-08-07")
    }

    func testResolvePendingAlreadyTakenAndMissing() {
        let identity = PlannedSlotIdentity(
            medicationId: "m1",
            scheduleId: "s1",
            date: "2026-08-07",
            timeOfDay: "08:00"
        )
        let pending = NextPendingDose.resolve(
            identity: identity,
            medications: [med()],
            schedules: [sched()],
            doseLogs: [],
            periods: [],
            settings: settings
        )
        if case .pending(let dose) = pending {
            XCTAssertEqual(dose.identity, identity)
            XCTAssertNil(dose.log?.id)
        } else {
            XCTFail("expected pending, got \(pending)")
        }

        let taken = NextPendingDose.resolve(
            identity: identity,
            medications: [med()],
            schedules: [sched()],
            doseLogs: [log(date: "2026-08-07", time: "08:00")],
            periods: [],
            settings: settings
        )
        if case .alreadyTaken(let dose) = taken {
            XCTAssertEqual(dose.log?.id, "l-s1-2026-08-07-08:00")
        } else {
            XCTFail("expected alreadyTaken, got \(taken)")
        }

        let missing = NextPendingDose.resolve(
            identity: PlannedSlotIdentity(
                medicationId: "m1",
                scheduleId: "s1",
                date: "2026-08-07",
                timeOfDay: "21:00"
            ),
            medications: [med()],
            schedules: [sched()],
            doseLogs: [],
            periods: [],
            settings: settings
        )
        XCTAssertEqual(missing, .missing)
    }
}
