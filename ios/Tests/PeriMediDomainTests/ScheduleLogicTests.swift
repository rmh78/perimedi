import XCTest
@testable import PeriMediDomain

final class ScheduleLogicTests: XCTestCase {
    let settings = CycleSettings(averageCycleLength: 28, averagePeriodLength: 5)

    func med(_ partial: Medication? = nil) -> Medication {
        partial ?? Medication(
            id: "m1", name: "Estrogen", form: .PILL, doseLabel: "1 mg", createdAt: "2026-01-01T00:00:00"
        )
    }

    func sched(_ mutate: (inout Schedule) -> Void = { _ in }) -> Schedule {
        var s = Schedule(
            id: "s1", medicationId: "m1", daysOfWeek: [], timeOfDay: "08:00",
            active: true, cycleRule: .none
        )
        mutate(&s)
        return s
    }

    func expand(
        from: String = "2026-08-03",
        to: String = "2026-08-09",
        medications: [Medication]? = nil,
        schedules: [Schedule]? = nil,
        doseLogs: [DoseLog] = [],
        periods: [Period] = []
    ) -> [PlannedDose] {
        ScheduleLogic.expandPlannedDoses(
            from: from,
            to: to,
            medications: medications ?? [med()],
            schedules: schedules ?? [sched()],
            doseLogs: doseLogs,
            periods: periods,
            settings: settings
        )
    }

    func testEverydayScheduleEmitsOnePendingDosePerDay() {
        let doses = expand()
        XCTAssertEqual(doses.count, 7)
        XCTAssertEqual(doses.map(\.date), [
            "2026-08-03", "2026-08-04", "2026-08-05", "2026-08-06",
            "2026-08-07", "2026-08-08", "2026-08-09",
        ])
        XCTAssertTrue(doses.allSatisfy { $0.timeOfDay == "08:00" })
        XCTAssertTrue(doses.allSatisfy { $0.status == .pending })
        XCTAssertEqual(doses.first?.doseLabel, "1 mg")
    }

    func testWeekdaysFilter() {
        let doses = expand(schedules: [sched { $0.daysOfWeek = [1, 3] }])
        XCTAssertEqual(doses.map(\.date), ["2026-08-03", "2026-08-05"])
    }

    func testSkipsInactiveAndUnknownMed() {
        XCTAssertEqual(expand(schedules: [sched { $0.active = false }]).count, 0)
        XCTAssertEqual(expand(medications: [med(Medication(id: "other", name: "X", form: .PILL, doseLabel: "1", createdAt: "t"))]).count, 0)
    }

    func testStartAndEndInclusive() {
        let doses = expand(schedules: [sched {
            $0.startDate = "2026-08-05"
            $0.endDate = "2026-08-07"
        }])
        XCTAssertEqual(doses.map(\.date), ["2026-08-05", "2026-08-06", "2026-08-07"])
    }

    func testMultipleTimesAndScheduleDoseLabel() {
        let doses = expand(from: "2026-08-03", to: "2026-08-03", schedules: [sched {
            $0.timeOfDay = "08:00"
            $0.times = ["08:00", "20:00"]
            $0.doseLabel = "2 mg"
        }])
        XCTAssertEqual(doses.map(\.timeOfDay), ["08:00", "20:00"])
        XCTAssertTrue(doses.allSatisfy { $0.doseLabel == "2 mg" })
    }

    func testAttachesMatchingDoseLog() {
        let log = DoseLog(
            id: "log1", medicationId: "m1", scheduleId: "s1",
            plannedFor: "2026-08-03T08:00:00", status: .taken
        )
        let doses = expand(from: "2026-08-03", to: "2026-08-03", doseLogs: [log])
        XCTAssertEqual(doses.count, 1)
        XCTAssertEqual(doses.first?.status, .taken)
        XCTAssertEqual(doses.first?.log?.id, "log1")
    }

    func testSkipsTherapyPauseDays() {
        let doses = expand(schedules: [sched {
            $0.therapyCycle = TherapyCycle(
                enabled: true, mode: .on_off_days, anchorDate: "2026-08-03", onDays: 3, offDays: 4
            )
        }])
        XCTAssertEqual(doses.map(\.date), ["2026-08-03", "2026-08-04", "2026-08-05"])
    }

    func testPeriodOnlySchedule() {
        let periods = [Period(id: "p1", startDate: "2026-08-03", endDate: "2026-08-05")]
        let doses = expand(schedules: [sched { $0.cycleRule = .period_only }], periods: periods)
        XCTAssertEqual(doses.map(\.date), ["2026-08-03", "2026-08-04", "2026-08-05"])
    }

    func testPlannedForIso() {
        XCTAssertEqual(ScheduleLogic.plannedForIso(dateKey: "2026-08-03", timeOfDay: "08:00"), "2026-08-03T08:00:00")
    }
}
