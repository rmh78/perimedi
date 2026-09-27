import Foundation

public struct DoseWidgetChrome: Equatable, Sendable {
    public var brandTitle: String
    public var emptyTitle: String
    public var emptyBody: String
    public var takeAction: String
    public var stillToTake: String
    public var doneTitle: String

    public static func make(t: (String, [String: String]) -> String) -> DoseWidgetChrome {
        DoseWidgetChrome(
            brandTitle: "PeriMedi",
            emptyTitle: t("widget.empty.title", [:]),
            emptyBody: t("widget.empty.body", [:]),
            takeAction: t("widget.take.action", [:]),
            stillToTake: t("widget.still.title", [:]),
            doneTitle: t("widget.done.title", [:])
        )
    }
}

public enum DoseWidgetControl: Equatable, Sendable {
    case take(String)
    case check
}

public struct DoseWidgetAck: Codable, Equatable, Sendable {
    public static let duration: TimeInterval = 2
    public static var horizon: TimeInterval { duration + 1 }

    public var row: DoseWidgetSnapshot.Row
    public var index: Int
    public var until: Date

    public init(row: DoseWidgetSnapshot.Row, index: Int, until: Date) {
        self.row = row
        self.index = index
        self.until = until
    }
}

public struct DoseWidgetFace: Equatable, Sendable {
    public var brandTitle: String
    public var helper: String?
    public var emptyTitle: String?
    public var rows: [Row]

    public struct Row: Equatable, Sendable, Identifiable {
        public var medicationId: String
        public var name: String
        public var detail: String
        public var color: String
        public var icon: String
        public var control: DoseWidgetControl
        public var id: String { medicationId }
    }

    public var showsCheck: Bool {
        rows.contains { row in
            if case .check = row.control { return true }
            return false
        }
    }
}

public struct DoseWidgetSnapshot: Equatable, Sendable {
    public var version: Int
    public var chrome: DoseWidgetChrome
    public var date: String
    public var meds: [Row]
    public var nextDate: String
    public var nextMeds: [Row]
    public var ack: DoseWidgetAck? = nil
    public var finishedToday: Bool = false

    public struct Row: Codable, Equatable, Sendable, Identifiable {
        public var medicationId: String
        public var name: String
        public var doseLabel: String
        public var color: String
        public var icon: String
        public var earliestTimeOfDay: String
        public var id: String { medicationId }
    }

    public static let schemaVersion = 2

    public static func rows(from meds: [TodayPendingMedication]) -> [Row] {
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

    public static func make(
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

    public struct Visible: Equatable {
        public var date: String
        public var meds: [Row]
    }

    public func visible(at now: Date) -> Visible {
        let key = DateKeys.toDateKey(now)
        if key == date { return Visible(date: date, meds: meds) }
        if key == nextDate { return Visible(date: nextDate, meds: nextMeds) }
        return Visible(date: key, meds: [])
    }

    public func face(at instant: Date) -> DoseWidgetFace {
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
        let emptyTitle: String?
        if !rows.isEmpty {
            emptyTitle = nil
        } else if finishedToday && visible.date == date && !chrome.doneTitle.isEmpty {
            emptyTitle = chrome.doneTitle
        } else {
            emptyTitle = chrome.emptyTitle
        }
        let helper = rows.isEmpty || chrome.stillToTake.isEmpty ? nil : chrome.stillToTake
        return DoseWidgetFace(
            brandTitle: chrome.brandTitle,
            helper: helper,
            emptyTitle: emptyTitle,
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
        return lead > 0 && lead <= DoseWidgetAck.horizon
    }

    private static func detail(_ row: Row) -> String {
        "\(row.doseLabel) · \(row.earliestTimeOfDay)"
    }

    public static var placeholder: DoseWidgetSnapshot {
        DoseWidgetSnapshot(
            version: schemaVersion,
            chrome: DoseWidgetChrome(
                brandTitle: "PeriMedi",
                emptyTitle: "Nothing to take today",
                emptyBody: "No untaken medications planned today.",
                takeAction: "Take",
                stillToTake: "Still to take today",
                doneTitle: "All taken for today"
            ),
            date: "",
            meds: [],
            nextDate: "",
            nextMeds: []
        )
    }

    public static var missingFileFallback: DoseWidgetSnapshot {
        let german = Locale.preferredLanguages.joined(separator: ",").lowercased().contains("de")
        return DoseWidgetSnapshot(
            version: schemaVersion,
            chrome: DoseWidgetChrome(
                brandTitle: "PeriMedi",
                emptyTitle: german ? "Heute nichts zu nehmen" : "Nothing to take today",
                emptyBody: german ? "Heute keine offene Dosis." : "No untaken medications planned today.",
                takeAction: german ? "Nehmen" : "Take",
                stillToTake: german ? "Heute noch einnehmen" : "Still to take today",
                doneTitle: german ? "Heute alles genommen" : "All taken for today"
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
        case doneTitle
        case takenAction
    }

    public init(from decoder: Decoder) throws {
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
        doneTitle = try container.decodeIfPresent(String.self, forKey: .doneTitle) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(brandTitle, forKey: .brandTitle)
        try container.encode(emptyTitle, forKey: .emptyTitle)
        try container.encode(emptyBody, forKey: .emptyBody)
        try container.encode(takeAction, forKey: .takeAction)
        try container.encode(stillToTake, forKey: .stillToTake)
        try container.encode(doneTitle, forKey: .doneTitle)
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
        case finishedToday
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        chrome = try container.decode(DoseWidgetChrome.self, forKey: .chrome)
        date = try container.decode(String.self, forKey: .date)
        meds = try container.decode([Row].self, forKey: .meds)
        nextDate = try container.decode(String.self, forKey: .nextDate)
        nextMeds = try container.decode([Row].self, forKey: .nextMeds)
        ack = try? container.decode(DoseWidgetAck.self, forKey: .ack)
        finishedToday = (try? container.decode(Bool.self, forKey: .finishedToday)) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(chrome, forKey: .chrome)
        try container.encode(date, forKey: .date)
        try container.encode(meds, forKey: .meds)
        try container.encode(nextDate, forKey: .nextDate)
        try container.encode(nextMeds, forKey: .nextMeds)
        try container.encodeIfPresent(ack, forKey: .ack)
        try container.encode(finishedToday, forKey: .finishedToday)
    }
}
