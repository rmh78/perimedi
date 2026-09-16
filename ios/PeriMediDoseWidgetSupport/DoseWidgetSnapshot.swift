import Foundation
import PeriMediDomain

struct DoseWidgetChrome: Codable, Equatable, Sendable {
    var brandTitle: String
    var emptyTitle: String
    var emptyBody: String
    var takenAction: String

    static func make(t: (String, [String: String]) -> String) -> DoseWidgetChrome {
        DoseWidgetChrome(
            brandTitle: "PeriMedi",
            emptyTitle: t("widget.empty.title", [:]),
            emptyBody: t("widget.empty.body", [:]),
            takenAction: t("reminder.taken", [:])
        )
    }
}

struct DoseWidgetSnapshot: Codable, Equatable, Sendable {
    var version: Int
    var chrome: DoseWidgetChrome
    var date: String
    var meds: [Row]
    var nextDate: String
    var nextMeds: [Row]

    struct Row: Codable, Equatable, Sendable, Identifiable {
        var medicationId: String
        var name: String
        var doseLabel: String
        var color: String
        var earliestTimeOfDay: String
        var id: String { medicationId }
    }

    static let schemaVersion = 2

    static func rows(from meds: [TodayPendingMedication]) -> [Row] {
        meds.map { med in
            Row(
                medicationId: med.medication.id,
                name: med.medication.name,
                doseLabel: med.doseLabel,
                color: MedColors.resolve(form: med.medication.form, color: med.medication.color),
                earliestTimeOfDay: med.earliestTimeOfDay
            )
        }
    }

    static func make(
        chrome: DoseWidgetChrome,
        date: String,
        meds: [TodayPendingMedication],
        nextDate: String,
        nextMeds: [TodayPendingMedication]
    ) -> DoseWidgetSnapshot {
        DoseWidgetSnapshot(
            version: schemaVersion,
            chrome: chrome,
            date: date,
            meds: rows(from: meds),
            nextDate: nextDate,
            nextMeds: rows(from: nextMeds)
        )
    }

    struct Visible: Equatable {
        var date: String
        var meds: [Row]
    }

    func visible(at now: Date) -> Visible {
        let key = DateKeys.toDateKey(now)
        if key == date { return Visible(date: date, meds: meds) }
        if key == nextDate { return Visible(date: nextDate, meds: nextMeds) }
        return Visible(date: key, meds: [])
    }

    static var placeholder: DoseWidgetSnapshot {
        DoseWidgetSnapshot(
            version: schemaVersion,
            chrome: DoseWidgetChrome(
                brandTitle: "PeriMedi",
                emptyTitle: "Nothing to take today",
                emptyBody: "No untaken medications planned today.",
                takenAction: "Taken"
            ),
            date: "",
            meds: [],
            nextDate: "",
            nextMeds: []
        )
    }

    static var missingFileFallback: DoseWidgetSnapshot {
        let german = Locale.preferredLanguages.joined(separator: ",").lowercased().contains("de")
        return DoseWidgetSnapshot(
            version: schemaVersion,
            chrome: DoseWidgetChrome(
                brandTitle: "PeriMedi",
                emptyTitle: german ? "Heute nichts zu nehmen" : "Nothing to take today",
                emptyBody: german ? "Heute keine offene Dosis." : "No untaken medications planned today.",
                takenAction: german ? "Genommen" : "Taken"
            ),
            date: "",
            meds: [],
            nextDate: "",
            nextMeds: []
        )
    }
}

enum DoseWidgetKind {
    static let id = "app.perimedi.ios.dose"
}

enum DoseWidgetSnapshotFile {
    static let appGroupId = "group.app.perimedi.ios"
    static let fileName = "next-dose.json"

    static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
    }

    static func read() -> DoseWidgetSnapshot {
        guard
            let url = containerURL()?.appendingPathComponent(fileName),
            let data = try? Data(contentsOf: url),
            let snapshot = try? JSONDecoder().decode(DoseWidgetSnapshot.self, from: data),
            snapshot.version == DoseWidgetSnapshot.schemaVersion
        else {
            return .missingFileFallback
        }
        return snapshot
    }

#if PERIMEDI_APP
    static func write(_ snapshot: DoseWidgetSnapshot) throws {
        guard let dir = containerURL() else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(fileName)
        let tmp = dir.appendingPathComponent("\(fileName).tmp")
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: tmp, options: .atomic)
        if FileManager.default.fileExists(atPath: dest.path) {
            _ = try FileManager.default.replaceItemAt(dest, withItemAt: tmp)
        } else {
            try FileManager.default.moveItem(at: tmp, to: dest)
        }
    }
#endif
}
