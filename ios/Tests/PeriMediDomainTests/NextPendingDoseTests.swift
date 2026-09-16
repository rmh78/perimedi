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
