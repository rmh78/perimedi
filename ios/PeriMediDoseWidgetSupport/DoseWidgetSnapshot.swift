import Foundation
import PeriMediDomain

struct DoseWidgetChrome: Codable, Equatable, Sendable {
    var nextTitle: String
    var emptyTitle: String
    var emptyBody: String
    var takenAction: String

    static func make(t: (String, [String: String]) -> String) -> DoseWidgetChrome {
        DoseWidgetChrome(
            nextTitle: t("widget.next.title", [:]),
            emptyTitle: t("widget.empty.title", [:]),
            emptyBody: t("widget.empty.body", [:]),
            takenAction: t("reminder.taken", [:])
        )
    }
}

struct DoseWidgetSnapshot: Codable, Equatable, Sendable {
    var version: Int
    var chrome: DoseWidgetChrome
    var slot: Slot?

    struct Slot: Codable, Equatable, Sendable {
        var identity: PlannedSlotIdentity
        var medicationName: String
        var doseLabel: String
        var timeOfDay: String
        var date: String
        var color: String?
        var fireAtEpoch: TimeInterval
    }

    static let schemaVersion = 1

    static func occupied(chrome: DoseWidgetChrome, dose: PlannedDose) -> DoseWidgetSnapshot {
        let fireAt = DateKeys.date(dateKey: dose.date, timeOfDay: dose.timeOfDay) ?? Date.distantPast
        return DoseWidgetSnapshot(
            version: schemaVersion,
            chrome: chrome,
            slot: Slot(
                identity: dose.identity,
                medicationName: dose.medication.name,
                doseLabel: dose.doseLabel,
                timeOfDay: dose.timeOfDay,
                date: dose.date,
                color: dose.medication.color,
                fireAtEpoch: fireAt.timeIntervalSince1970
            )
        )
    }

    static func empty(chrome: DoseWidgetChrome) -> DoseWidgetSnapshot {
        DoseWidgetSnapshot(version: schemaVersion, chrome: chrome, slot: nil)
    }

    static var placeholder: DoseWidgetSnapshot {
        DoseWidgetSnapshot(
            version: schemaVersion,
            chrome: DoseWidgetChrome(
                nextTitle: "Next dose",
                emptyTitle: "No pending dose",
                emptyBody: "Nothing planned soon.",
                takenAction: "Taken"
            ),
            slot: nil
        )
    }

    static var missingFileFallback: DoseWidgetSnapshot {
        let german = Locale.preferredLanguages.joined(separator: ",").lowercased().contains("de")
        return .empty(
            chrome: DoseWidgetChrome(
                nextTitle: german ? "Nächste Dosis" : "Next dose",
                emptyTitle: german ? "Keine offene Dosis" : "No pending dose",
                emptyBody: german ? "Bald nichts geplant." : "Nothing planned soon.",
                takenAction: german ? "Genommen" : "Taken"
            )
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
