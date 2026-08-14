import XCTest
@testable import PeriMediDomain

final class TherapyCycleTests: XCTestCase {
    func sched(_ mutate: (inout Schedule) -> Void = { _ in }) -> Schedule {
        var s = Schedule(
            id: "s1", medicationId: "m1", daysOfWeek: [], timeOfDay: "08:00",
            active: true, cycleRule: .none
        )
        mutate(&s)
        return s
    }

    let onOff = TherapyCycle(
        enabled: true, mode: .on_off_days, anchorDate: "2026-08-01", onDays: 3, offDays: 2
    )

    func testGetScheduleTimes() {
        XCTAssertEqual(
            TherapyCycleLogic.getScheduleTimes(sched { $0.times = ["8:00", "20:30"] }),
            ["08:00", "20:30"]
        )
        XCTAssertEqual(
            TherapyCycleLogic.getScheduleTimes(sched { $0.timeOfDay = "9:15" }),
            ["09:15"]
        )
        XCTAssertEqual(
            TherapyCycleLogic.getScheduleTimes(sched {
                $0.timeOfDay = ""
                $0.times = []
            }),
            ["08:00"]
        )
    }

    func testGetTherapyCycle() {
        XCTAssertEqual(TherapyCycleLogic.getTherapyCycle(sched { $0.therapyCycle = onOff }), onOff)
        let migrated = TherapyCycleLogic.getTherapyCycle(sched {
            $0.startDate = "2026-07-01"
            $0.weekPattern = WeekPattern(
                enabled: true,
                anchorDate: "2026-07-06",
                slots: [WeekPatternSlot(take: true, doseLabel: "100 mg"), WeekPatternSlot(take: false)]
            )
        })
        XCTAssertEqual(migrated?.mode, .week_slots)
        XCTAssertEqual(migrated?.anchorDate, "2026-07-06")
        XCTAssertEqual(migrated?.onDays, 7)
        XCTAssertEqual(migrated?.offDays, 7)
        XCTAssertEqual(migrated?.slots?.count, 2)
        XCTAssertNil(TherapyCycleLogic.getTherapyCycle(sched()))
    }

    func testMatchContinuousIsNil() {
        XCTAssertNil(
            TherapyCycleLogic.matchTherapyCycle(
                schedule: sched { $0.therapyCycle = TherapyCycle(enabled: true, mode: .continuous, anchorDate: "2026-08-01", onDays: 3, offDays: 2) },
                dateKey: "2026-08-01"
            )
        )
        XCTAssertNil(TherapyCycleLogic.matchTherapyCycle(schedule: sched(), dateKey: "2026-08-01"))
    }

    func testBeforeStart() {
        let match = TherapyCycleLogic.matchTherapyCycle(schedule: sched { $0.therapyCycle = onOff }, dateKey: "2026-07-31")
        XCTAssertEqual(match, TherapyMatch(take: false, phase: .before_start))
    }

    func testOnOffApplyThenPause() {
        let s = sched { $0.therapyCycle = onOff }
        XCTAssertEqual(TherapyCycleLogic.matchTherapyCycle(schedule: s, dateKey: "2026-08-01")?.phase, .apply)
        XCTAssertEqual(TherapyCycleLogic.matchTherapyCycle(schedule: s, dateKey: "2026-08-01")?.take, true)
        XCTAssertEqual(TherapyCycleLogic.matchTherapyCycle(schedule: s, dateKey: "2026-08-03")?.dayInBlock, 2)
        XCTAssertEqual(TherapyCycleLogic.matchTherapyCycle(schedule: s, dateKey: "2026-08-04")?.phase, .pause)
        XCTAssertEqual(TherapyCycleLogic.matchTherapyCycle(schedule: s, dateKey: "2026-08-06")?.dayInBlock, 0)
    }

    func testOffDaysZeroIsContinuous() {
        let match = TherapyCycleLogic.matchTherapyCycle(
            schedule: sched {
                $0.therapyCycle = TherapyCycle(enabled: true, mode: .on_off_days, anchorDate: "2026-08-01", onDays: 3, offDays: 0)
            },
            dateKey: "2026-08-10"
        )
        XCTAssertEqual(match?.take, true)
        XCTAssertEqual(match?.phase, .continuous)
    }

    func testOnDaysZeroIsPause() {
        let match = TherapyCycleLogic.matchTherapyCycle(
            schedule: sched {
                $0.therapyCycle = TherapyCycle(enabled: true, mode: .on_off_days, anchorDate: "2026-08-01", onDays: 0, offDays: 2)
            },
            dateKey: "2026-08-02"
        )
        XCTAssertEqual(match?.take, false)
        XCTAssertEqual(match?.phase, .pause)
    }

    func testWeekSlots() {
        let s = sched {
            $0.therapyCycle = TherapyCycle(
                enabled: true,
                mode: .week_slots,
                anchorDate: "2026-08-03",
                onDays: 14,
                offDays: 7,
                slots: [
                    WeekPatternSlot(take: true, doseLabel: "100 mg", name: "Week 1"),
                    WeekPatternSlot(take: true, doseLabel: "50 mg", name: "Week 2"),
                    WeekPatternSlot(take: false, name: "Pause"),
                ]
            )
        }
        XCTAssertEqual(TherapyCycleLogic.matchTherapyCycle(schedule: s, dateKey: "2026-08-03")?.doseLabel, "100 mg")
        XCTAssertEqual(TherapyCycleLogic.matchTherapyCycle(schedule: s, dateKey: "2026-08-10")?.slotIndex, 1)
        XCTAssertEqual(TherapyCycleLogic.matchTherapyCycle(schedule: s, dateKey: "2026-08-17")?.take, false)
        XCTAssertEqual(TherapyCycleLogic.matchTherapyCycle(schedule: s, dateKey: "2026-08-24")?.slotIndex, 0)
    }

    func testNormalizeTherapyCycle() {
        XCTAssertNil(
            TherapyCycleLogic.normalizeTherapyCycle(
                TherapyCycle(enabled: false, mode: .on_off_days, anchorDate: "", onDays: 21, offDays: 7),
                fallbackAnchor: "2026-08-01"
            )
        )
        XCTAssertNil(
            TherapyCycleLogic.normalizeTherapyCycle(
                TherapyCycle(enabled: true, mode: .continuous, anchorDate: "", onDays: 0, offDays: 0),
                fallbackAnchor: "2026-08-01"
            )
        )
        XCTAssertNil(
            TherapyCycleLogic.normalizeTherapyCycle(
                TherapyCycle(enabled: true, mode: .on_off_days, anchorDate: "", onDays: 21, offDays: 0),
                fallbackAnchor: "2026-08-01"
            )
        )
        let kept = TherapyCycleLogic.normalizeTherapyCycle(
            TherapyCycle(enabled: true, mode: .on_off_days, anchorDate: "", onDays: 21, offDays: 7),
            fallbackAnchor: "2026-08-01"
        )
        XCTAssertEqual(kept?.onDays, 21)
        XCTAssertEqual(kept?.anchorDate, "2026-08-01")
    }

    func testNormalizeTimes() {
        XCTAssertEqual(TherapyCycleLogic.normalizeTimes(["20:00", "8:00", "08:00"], fallback: "09:00"), ["08:00", "20:00"])
        XCTAssertEqual(TherapyCycleLogic.normalizeTimes([], fallback: "9:00"), ["09:00"])
    }

    func testDescribe() {
        XCTAssertEqual(TherapyCycleLogic.describeTherapyCycle(sched()), "Continuous")
        XCTAssertEqual(TherapyCycleLogic.describeTherapyCycle(sched { $0.therapyCycle = onOff }), "Apply 3 days · pause 2 days")
    }
}
