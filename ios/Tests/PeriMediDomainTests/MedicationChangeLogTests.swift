import XCTest
@testable import PeriMediDomain

final class MedicationChangeLogTests: XCTestCase {
    private func med(_ dose: String, id: String = "m1") -> Medication {
        Medication(
            id: id,
            name: "Estrogel",
            form: .CREAM,
            doseLabel: dose,
            createdAt: "t"
        )
    }

    private func schedule(
        times: [String] = ["08:00"],
        days: [Int] = [],
        start: String = "2026-03-01",
        on: Int? = nil,
        off: Int? = nil
    ) -> Schedule {
        var therapy: TherapyCycle?
        if let on, let off {
            therapy = TherapyCycle(
                enabled: true,
                mode: .on_off_days,
                anchorDate: start,
                onDays: on,
                offDays: off
            )
        }
        return Schedule(
            id: "s1",
            medicationId: "m1",
            daysOfWeek: days,
            timeOfDay: times[0],
            times: times,
            active: true,
            startDate: start,
            cycleRule: .none,
            therapyCycle: therapy
        )
    }

    func testNewMedicationWritesDoseAndSchedule() {
        let events = MedicationChangeLog.events(
            previousMed: nil,
            newMed: med("1 pump"),
            previousSchedule: nil,
            newSchedule: schedule(),
            effectiveDate: "2026-03-15",
            loggedAt: "t"
        )
        XCTAssertEqual(events.map(\.field), [.dose, .schedule])
        XCTAssertEqual(events[0].previousValue, "")
        XCTAssertEqual(events[0].newValue, "1 pump")
        XCTAssertEqual(events[0].effectiveDate, "2026-03-15")
        XCTAssertTrue(events[1].previousValue.isEmpty)
        XCTAssertFalse(events[1].newValue.isEmpty)
    }

    func testDoseChangeThenChangeBackWritesTwoEvents() {
        let sched = schedule()
        let first = MedicationChangeLog.events(
            previousMed: med("1 pump"),
            newMed: med("2 pumps"),
            previousSchedule: sched,
            newSchedule: sched,
            effectiveDate: "2026-03-15",
            loggedAt: "t1"
        )
        let second = MedicationChangeLog.events(
            previousMed: med("2 pumps"),
            newMed: med("1 pump"),
            previousSchedule: sched,
            newSchedule: sched,
            effectiveDate: "2026-03-16",
            loggedAt: "t2"
        )
        XCTAssertEqual(first.map(\.field), [.dose])
        XCTAssertEqual(first[0].previousValue, "1 pump")
        XCTAssertEqual(first[0].newValue, "2 pumps")
        XCTAssertEqual(second.map(\.field), [.dose])
        XCTAssertEqual(second[0].previousValue, "2 pumps")
        XCTAssertEqual(second[0].newValue, "1 pump")
    }

    func testHasChangesDoesNotDependOnEvents() {
        let sched = schedule()
        XCTAssertTrue(
            MedicationChangeLog.hasChanges(
                previousMed: med("1 pump"),
                newMed: med("2 pumps"),
                previousSchedule: sched,
                newSchedule: sched
            )
        )
        XCTAssertFalse(
            MedicationChangeLog.hasChanges(
                previousMed: med("1 pump"),
                newMed: med("1 pump"),
                previousSchedule: sched,
                newSchedule: sched
            )
        )
    }

    func testUnchangedSaveWritesNothing() {
        let sched = schedule()
        let events = MedicationChangeLog.events(
            previousMed: med("1 pump"),
            newMed: med("1 pump"),
            previousSchedule: sched,
            newSchedule: sched,
            effectiveDate: "2026-03-15",
            loggedAt: "t"
        )
        XCTAssertTrue(events.isEmpty)
    }

    func testScheduleChangeOnly() {
        let events = MedicationChangeLog.events(
            previousMed: med("1 pump"),
            newMed: med("1 pump"),
            previousSchedule: schedule(times: ["08:00"]),
            newSchedule: schedule(times: ["20:00"]),
            effectiveDate: "2026-03-15",
            loggedAt: "t"
        )
        XCTAssertEqual(events.map(\.field), [.schedule])
        XCTAssertTrue(events[0].newValue.contains("20:00"))
    }

    func testExportIncludesBothChanges() throws {
        let payload = ExportPayload(
            exportedAt: "t",
            medications: [med("1 pump")],
            schedules: [schedule()],
            doseLogs: [],
            remarks: [],
            cycleSettings: .default,
            periods: [],
            medicationChanges: [
                MedicationChange(
                    id: "c1",
                    medicationId: "m1",
                    nameSnapshot: "Estrogel",
                    field: .dose,
                    previousValue: "1 pump",
                    newValue: "2 pumps",
                    effectiveDate: "2026-03-15",
                    loggedAt: "t1"
                ),
                MedicationChange(
                    id: "c2",
                    medicationId: "m1",
                    nameSnapshot: "Estrogel",
                    field: .dose,
                    previousValue: "2 pumps",
                    newValue: "1 pump",
                    effectiveDate: "2026-03-16",
                    loggedAt: "t2"
                ),
            ]
        )
        let decoded = try BackupCodec.decode(try BackupCodec.encode(payload))
        XCTAssertEqual(decoded.medicationChanges.count, 2)
        XCTAssertEqual(decoded.medicationChanges.map(\.newValue), ["2 pumps", "1 pump"])
    }

    func testOldBackupWithoutChangesDecodesEmpty() throws {
        let json = """
        {"version":1,"exportedAt":"t","medications":[],"schedules":[],"doseLogs":[],"remarks":[],"cycleSettings":{"id":"default","averageCycleLength":28,"averagePeriodLength":5},"periods":[]}
        """
        let imported = try BackupCodec.decode(Data(json.utf8))
        XCTAssertEqual(imported.medicationChanges, [])
    }
}
