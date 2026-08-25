import XCTest
@testable import PeriMediDomain

final class ReminderLogicTests: XCTestCase {
    let settings = CycleSettings(averageCycleLength: 28, averagePeriodLength: 5)

    func med(_ reminders: Bool = true) -> Medication {
        Medication(
            id: "m1", name: "Estrogen", form: .PILL, doseLabel: "1 mg",
            createdAt: "t", remindersEnabled: reminders
        )
    }

    func sched(_ mutate: (inout Schedule) -> Void = { _ in }) -> Schedule {
        var s = Schedule(
            id: "s1", medicationId: "m1", daysOfWeek: [], timeOfDay: "08:00",
            times: ["08:00"], active: true, cycleRule: .none
        )
        mutate(&s)
        return s
    }

    func nowOn(_ dateKey: String, time: String) -> Date {
        DateKeys.date(dateKey: dateKey, timeOfDay: time)!
    }

    func upcoming(
        now: Date,
        medications: [Medication]? = nil,
        schedules: [Schedule]? = nil,
        logs: [DoseLog] = []
    ) -> [ReminderSlot] {
        ReminderLogic.upcoming(
            now: now,
            medications: medications ?? [med()],
            schedules: schedules ?? [sched()],
            doseLogs: logs,
            periods: [],
            settings: settings
        )
    }

    func testEverydayFutureSlots() {
        let slots = upcoming(now: nowOn("2026-08-07", time: "07:00"))
        XCTAssertFalse(slots.isEmpty)
        XCTAssertEqual(slots.first?.date, "2026-08-07")
        XCTAssertEqual(slots.first?.timeOfDay, "08:00")
        XCTAssertEqual(slots.first?.medicationName, "Estrogen")
        XCTAssertTrue(slots.allSatisfy { $0.fireAt > nowOn("2026-08-07", time: "07:00") })
    }

    func testSkipsPastTimeToday() {
        let slots = upcoming(now: nowOn("2026-08-07", time: "09:00"))
        XCTAssertFalse(slots.contains { $0.date == "2026-08-07" && $0.timeOfDay == "08:00" })
        XCTAssertEqual(slots.first?.date, "2026-08-08")
    }

    func testSkipsTaken() {
        let log = DoseLog(
            id: "l1",
            medicationId: "m1",
            scheduleId: "s1",
            plannedFor: DateKeys.combineDateAndTime(dateKey: "2026-08-07", timeOfDay: "08:00"),
            status: .taken,
            confirmedAt: "t"
        )
        let slots = upcoming(now: nowOn("2026-08-07", time: "07:00"), logs: [log])
        XCTAssertFalse(slots.contains { $0.date == "2026-08-07" })
    }

    func testSkipsRemindOff() {
        let slots = upcoming(now: nowOn("2026-08-07", time: "07:00"), medications: [med(false)])
        XCTAssertTrue(slots.isEmpty)
    }

    func testStartEndAndCyclicPause() {
        let bounded = upcoming(
            now: nowOn("2026-08-07", time: "07:00"),
            schedules: [sched {
                $0.startDate = "2026-08-10"
                $0.endDate = "2026-08-11"
            }]
        )
        XCTAssertEqual(Set(bounded.map(\.date)), ["2026-08-10", "2026-08-11"])

        let cyclic = upcoming(
            now: nowOn("2026-08-07", time: "07:00"),
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
        XCTAssertFalse(cyclic.contains { $0.date == "2026-08-08" })
        XCTAssertTrue(cyclic.contains { $0.date == "2026-08-07" })
        XCTAssertTrue(cyclic.contains { $0.date == "2026-08-09" })
    }

    func testPendingOnPinnedDayIncludesPastClockTime() {
        let slots = ReminderLogic.pending(
            on: "2026-08-07",
            medications: [med()],
            schedules: [sched()],
            doseLogs: [],
            periods: [],
            settings: settings
        )
        XCTAssertEqual(slots.map(\.date), ["2026-08-07"])
        XCTAssertEqual(slots.first?.timeOfDay, "08:00")
    }

    func testOldBackupDefaultsRemindersOn() throws {
        let json = """
        {"version":1,"exportedAt":"t","medications":[{"id":"m","name":"E","form":"PILL","doseLabel":"1","createdAt":"t"}],"schedules":[],"doseLogs":[],"remarks":[],"cycleSettings":{"id":"default","averageCycleLength":28,"averagePeriodLength":5},"periods":[]}
        """
        let payload = try BackupCodec.decode(Data(json.utf8))
        XCTAssertEqual(payload.medications.first?.remindersEnabled, true)
    }
}
