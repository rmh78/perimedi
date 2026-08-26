import Foundation
import PeriMediDomain

/// Shared empty-to-tracking journey used for Simulator screenshots.
/// Step numbers match `web/shots/journey-*.png` / design §2c.
@MainActor
enum JourneyScript {
    static let estrogenId = "journey-estrogen"
    static let progesteroneId = "journey-progesterone"
    static let estrogenScheduleId = "journey-estrogen-sched"
    static let progesteroneScheduleId = "journey-progesterone-sched"
    static let periodId = "journey-period"
    static let symptomId = "journey-symptom"
    static let estrogenLogId = "journey-estrogen-log"

    struct Snapshot {
        var selectedDate: String
        var tab: AppModel.Tab
        var launchSheet: String?
        var openPeriodEditor: Bool
    }

    static func periodStart(today: String = DateKeys.todayKey()) -> String {
        DateKeys.addDaysKey(today, -8)
    }

    static func periodEnd(today: String = DateKeys.todayKey()) -> String {
        DateKeys.addDaysKey(today, -4)
    }

    static func apply(store: Store, step: Int, today: String = DateKeys.todayKey()) -> Snapshot {
        store.clearAll()
        let start = periodStart(today: today)
        var snapshot = Snapshot(
            selectedDate: today,
            tab: .cycle,
            launchSheet: nil,
            openPeriodEditor: false
        )
        guard step >= 1 else { return snapshot }

        if step == 2 {
            snapshot.launchSheet = "period"
            snapshot.openPeriodEditor = true
            return snapshot
        }

        if step >= 3 {
            store.upsertPeriod(
                Period(
                    id: periodId,
                    startDate: start,
                    endDate: periodEnd(today: today),
                    flowNote: .medium
                )
            )
        }

        if step >= 4 {
            upsertEstrogen(store: store, dose: step >= 6 ? "2 mg" : "1 mg", start: start)
        }

        if step >= 5 && step < 7 {
            // Match the web form: cyclic 21/7 anchored on period start,
            // schedule start left as today → band Days 9–21.
            upsertProgesterone(store: store, start: today, anchor: start)
        }

        if step == 8 {
            snapshot.selectedDate = DateKeys.addDaysKey(today, -1)
        }

        if step >= 10 {
            store.setDoseStatus(
                medicationId: estrogenId,
                scheduleId: estrogenScheduleId,
                date: today,
                timeOfDay: "20:00",
                status: .taken,
                existingLogId: estrogenLogId
            )
        }

        if step >= 11 {
            store.replaceDayScores(
                date: today,
                scores: [
                    SymptomScore(
                        id: SymptomId.hot_flash.rawValue,
                        date: today,
                        severity: 3,
                        count: 8,
                        loggedAt: ISO8601DateFormatter().string(from: Date()),
                        higherIsWorse: true
                    ),
                    SymptomScore(
                        id: SymptomId.sleep.rawValue,
                        date: today,
                        severity: 2,
                        loggedAt: ISO8601DateFormatter().string(from: Date()),
                        higherIsWorse: true
                    ),
                    SymptomScore(
                        id: SymptomId.joints.rawValue,
                        date: today,
                        severity: 1,
                        loggedAt: ISO8601DateFormatter().string(from: Date()),
                        higherIsWorse: true
                    ),
                ],
                note: nil,
                noteId: nil
            )
        }

        if step >= 12 {
            snapshot.tab = .month
        }

        return snapshot
    }

    private static func upsertEstrogen(store: Store, dose: String, start: String) {
        store.upsertMedication(
            Medication(
                id: estrogenId,
                name: "Estrogen",
                form: .PILL,
                doseLabel: dose,
                color: MedColors.formDefaults[.PILL],
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
        )
        store.upsertSchedule(
            Schedule(
                id: estrogenScheduleId,
                medicationId: estrogenId,
                daysOfWeek: [],
                timeOfDay: "20:00",
                times: ["20:00"],
                active: true,
                startDate: start,
                cycleRule: .none
            )
        )
    }

    private static func upsertProgesterone(store: Store, start: String, anchor: String) {
        store.upsertMedication(
            Medication(
                id: progesteroneId,
                name: "Progesterone",
                form: .CREAM,
                doseLabel: "200 mg",
                color: MedColors.formDefaults[.CREAM],
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
        )
        store.upsertSchedule(
            Schedule(
                id: progesteroneScheduleId,
                medicationId: progesteroneId,
                daysOfWeek: [],
                timeOfDay: "20:00",
                times: ["20:00"],
                active: true,
                startDate: start,
                cycleRule: .none,
                therapyCycle: TherapyCycle(
                    enabled: true,
                    mode: .on_off_days,
                    anchorDate: anchor,
                    onDays: 21,
                    offDays: 7
                )
            )
        )
    }
}
