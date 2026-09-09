import Foundation

/// Deterministic multi-cycle scores for Trends UI tests. Not sample data.
public enum TrendsFixture {
    public static let today = "2026-03-15"
    public static let cycleA = "2026-01-04"
    public static let cycleB = "2026-02-01"
    public static let cycleC = "2026-03-01"
    public static let emptyStart = "2025-12-07"
    public static let doseChangeDate = "2026-02-10"
    public static let doseMedName = "Estrogel"
    public static let doseNewValue = "2 pumps"

    public static func payload() -> ExportPayload {
        let periods = [
            Period(id: "p-empty", startDate: emptyStart, endDate: "2025-12-11"),
            Period(id: "p-a", startDate: cycleA, endDate: "2026-01-08"),
            Period(id: "p-b", startDate: cycleB, endDate: "2026-02-05"),
            Period(id: "p-c", startDate: cycleC, endDate: "2026-03-05"),
        ]

        var scores: [SymptomScore] = []
        // Cycle A: eight mild hot-flash days (high Y, small dot). Episode count
        // on the first row must not become Y.
        scores.append(contentsOf: days("2026-01-05", count: 8, id: .hot_flash, severity: 1, firstCount: 99))
        scores.append(contentsOf: days("2026-01-13", count: 3, id: .mood, severity: 2))
        scores.append(contentsOf: days("2026-01-16", count: 2, id: .anxiety, severity: 2))
        scores.append(score(.joints, date: "2026-01-18", severity: 4))
        // Sleep has no scores in A (gap).
        // Cycle B: two severe hot-flash days (lower Y, larger dot).
        scores.append(contentsOf: days("2026-02-03", count: 2, id: .hot_flash, severity: 4))
        scores.append(contentsOf: days("2026-02-05", count: 4, id: .sleep, severity: 3))
        scores.append(contentsOf: days("2026-02-09", count: 3, id: .mood, severity: 2))
        scores.append(contentsOf: days("2026-02-12", count: 2, id: .anxiety, severity: 4))
        // Cycle C
        scores.append(contentsOf: days("2026-03-02", count: 5, id: .hot_flash, severity: 2))
        scores.append(contentsOf: days("2026-03-07", count: 2, id: .sleep, severity: 4))
        scores.append(contentsOf: days("2026-03-09", count: 3, id: .mood, severity: 3))

        let change = MedicationChange(
            id: "chg-dose",
            medicationId: "m-estrogel",
            nameSnapshot: doseMedName,
            field: .dose,
            previousValue: "1 pump",
            newValue: doseNewValue,
            effectiveDate: doseChangeDate,
            loggedAt: "t"
        )

        return ExportPayload(
            version: 1,
            exportedAt: "t",
            medications: [],
            schedules: [],
            doseLogs: [],
            remarks: [],
            cycleSettings: CycleSettings(averageCycleLength: 28, averagePeriodLength: 5),
            periods: periods,
            symptomScores: scores,
            medicationChanges: [change]
        )
    }

    public static func noScoresPayload() -> ExportPayload {
        ExportPayload(
            version: 1,
            exportedAt: "t",
            medications: [],
            schedules: [],
            doseLogs: [],
            remarks: [],
            cycleSettings: CycleSettings(averageCycleLength: 28, averagePeriodLength: 5),
            periods: [
                Period(id: "p-a", startDate: cycleA, endDate: "2026-01-08"),
                Period(id: "p-b", startDate: cycleB, endDate: "2026-02-05"),
            ],
            symptomScores: [],
            medicationChanges: []
        )
    }

    private static func days(
        _ start: String,
        count: Int,
        id: SymptomId,
        severity: Int,
        firstCount: Int? = nil
    ) -> [SymptomScore] {
        (0..<count).map { offset in
            score(
                id,
                date: DateKeys.addDaysKey(start, offset),
                severity: severity,
                count: offset == 0 ? firstCount : nil
            )
        }
    }

    private static func score(
        _ id: SymptomId,
        date: String,
        severity: Int,
        count: Int? = nil
    ) -> SymptomScore {
        SymptomScore(id: id.rawValue, date: date, severity: severity, count: count, loggedAt: "t")
    }
}
