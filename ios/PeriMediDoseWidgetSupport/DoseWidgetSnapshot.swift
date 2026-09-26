import Foundation
import PeriMediDomain

struct DoseWidgetChrome: Equatable, Sendable {
    var brandTitle: String
    var emptyTitle: String
    var emptyBody: String
    var takeAction: String
    var stillToTake: String

    static func make(t: (String, [String: String]) -> String) -> DoseWidgetChrome {
        DoseWidgetChrome(
            brandTitle: "PeriMedi",
            emptyTitle: t("widget.empty.title", [:]),
            emptyBody: t("widget.empty.body", [:]),
            takeAction: t("widget.take.action", [:]),
            stillToTake: t("widget.still.title", [:])
        )
    }
}

enum DoseWidgetControl: Equatable, Sendable {
    case take(String)
    case check
}

struct DoseWidgetAck: Codable, Equatable, Sendable {
    var row: DoseWidgetSnapshot.Row
    var index: Int
    var until: Date
}

struct DoseWidgetFace: Equatable, Sendable {
    var brandTitle: String
    var helper: String?
    var emptyTitle: String?
    var rows: [Row]

    struct Row: Equatable, Sendable, Identifiable {
        var medicationId: String
        var name: String
        var detail: String
        var color: String
        var icon: String
        var control: DoseWidgetControl
        var id: String { medicationId }
    }
}

struct DoseWidgetSnapshot: Equatable, Sendable {
    var version: Int
    var chrome: DoseWidgetChrome
    var date: String
    var meds: [Row]
    var nextDate: String
    var nextMeds: [Row]
    var ack: DoseWidgetAck? = nil

    struct Row: Codable, Equatable, Sendable, Identifiable {
        var medicationId: String
        var name: String
        var doseLabel: String
        var color: String
        var icon: String
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
                icon: med.medication.form.assetName,
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

    func face(at instant: Date) -> DoseWidgetFace {
        let visible = visible(at: instant)
        var rows = visible.meds.map { med in
            DoseWidgetFace.Row(
                medicationId: med.medicationId,
                name: med.name,
                detail: Self.detail(med),
                color: med.color,
                icon: med.icon,
                control: .take(chrome.takeAction)
            )
        }
        if let ack, shows(ack, pending: visible.meds, day: visible.date, at: instant) {
            let index = min(max(ack.index, 0), rows.count)
            rows.insert(
                DoseWidgetFace.Row(
                    medicationId: ack.row.medicationId,
                    name: ack.row.name,
                    detail: Self.detail(ack.row),
                    color: ack.row.color,
                    icon: ack.row.icon,
                    control: .check
                ),
                at: index
            )
        }
        let stillTaking = rows.contains { row in
            if case .take = row.control { return true }
            return false
        }
        return DoseWidgetFace(
            brandTitle: chrome.brandTitle,
            helper: stillTaking && !chrome.stillToTake.isEmpty ? chrome.stillToTake : nil,
            emptyTitle: rows.isEmpty ? chrome.emptyTitle : nil,
            rows: rows
        )
    }

    private func shows(_ ack: DoseWidgetAck, pending: [Row], day: String, at instant: Date) -> Bool {
        if pending.contains(where: { $0.medicationId == ack.row.medicationId }) {
            return false
        }
        if day != date {
            return false
        }
        let lead = ack.until.timeIntervalSince(instant)
        return lead > 0 && lead <= 3
    }

    private static func detail(_ row: Row) -> String {
        "\(row.doseLabel) · \(row.earliestTimeOfDay)"
    }

    static var placeholder: DoseWidgetSnapshot {
        DoseWidgetSnapshot(
            version: schemaVersion,
            chrome: DoseWidgetChrome(
                brandTitle: "PeriMedi",
                emptyTitle: "Nothing to take today",
                emptyBody: "No untaken medications planned today.",
                takeAction: "Take",
                stillToTake: "Still to take today"
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
                takeAction: german ? "Nehmen" : "Take",
                stillToTake: german ? "Heute noch einnehmen" : "Still to take today"
            ),
            date: "",
            meds: [],
            nextDate: "",
            nextMeds: []
        )
    }
}

extension DoseWidgetChrome: Codable {
    private enum CodingKeys: String, CodingKey {
        case brandTitle
        case emptyTitle
        case emptyBody
        case takeAction
        case stillToTake
        case takenAction
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        brandTitle = try container.decode(String.self, forKey: .brandTitle)
        emptyTitle = try container.decode(String.self, forKey: .emptyTitle)
        emptyBody = try container.decode(String.self, forKey: .emptyBody)
        let storedTake = try container.decodeIfPresent(String.self, forKey: .takeAction)
        if let storedTake, !storedTake.isEmpty {
            takeAction = storedTake
        } else {
            let legacy = try container.decodeIfPresent(String.self, forKey: .takenAction)
            switch legacy {
            case "Genommen":
                takeAction = "Nehmen"
            case "Taken":
                takeAction = "Take"
            default:
                takeAction = "Take"
            }
        }
        stillToTake = try container.decodeIfPresent(String.self, forKey: .stillToTake) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(brandTitle, forKey: .brandTitle)
        try container.encode(emptyTitle, forKey: .emptyTitle)
        try container.encode(emptyBody, forKey: .emptyBody)
        try container.encode(takeAction, forKey: .takeAction)
        try container.encode(stillToTake, forKey: .stillToTake)
    }
}

extension DoseWidgetSnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case version
        case chrome
        case date
        case meds
        case nextDate
        case nextMeds
        case ack
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        chrome = try container.decode(DoseWidgetChrome.self, forKey: .chrome)
        date = try container.decode(String.self, forKey: .date)
        meds = try container.decode([Row].self, forKey: .meds)
        nextDate = try container.decode(String.self, forKey: .nextDate)
        nextMeds = try container.decode([Row].self, forKey: .nextMeds)
        ack = try? container.decode(DoseWidgetAck.self, forKey: .ack)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(chrome, forKey: .chrome)
        try container.encode(date, forKey: .date)
        try container.encode(meds, forKey: .meds)
        try container.encode(nextDate, forKey: .nextDate)
        try container.encode(nextMeds, forKey: .nextMeds)
        try container.encodeIfPresent(ack, forKey: .ack)
    }
}

enum DoseWidgetKind {
    static let id = "app.perimedi.ios.today"
}

enum DoseWidgetSnapshotFile {
    static let appGroupId = "group.app.perimedi.ios"
    static let fileName = "next-dose.json"

    static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
    }

    static func suite() -> UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    static func read() -> DoseWidgetSnapshot {
        let snapshot: DoseWidgetSnapshot
        if let data = suite()?.data(forKey: fileName),
           let decoded = try? JSONDecoder().decode(DoseWidgetSnapshot.self, from: data),
           decoded.version == DoseWidgetSnapshot.schemaVersion
        {
            snapshot = decoded
        } else if
            let url = containerURL()?.appendingPathComponent(fileName),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(DoseWidgetSnapshot.self, from: data),
            decoded.version == DoseWidgetSnapshot.schemaVersion
        {
            snapshot = decoded
        } else {
            snapshot = .missingFileFallback
        }
        return snapshot
    }

#if PERIMEDI_APP
    static func write(_ snapshot: DoseWidgetSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        guard let suite = suite() else {
            throw CocoaError(.fileNoSuchFile)
        }
        suite.set(data, forKey: fileName)
        suite.synchronize()
        guard let dir = containerURL() else { return }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(fileName)
        let tmp = dir.appendingPathComponent("\(fileName).tmp")
        try data.write(to: tmp, options: .atomic)
        if FileManager.default.fileExists(atPath: dest.path) {
            _ = try FileManager.default.replaceItemAt(dest, withItemAt: tmp)
        } else {
            try FileManager.default.moveItem(at: tmp, to: dest)
        }
    }
#endif
}
