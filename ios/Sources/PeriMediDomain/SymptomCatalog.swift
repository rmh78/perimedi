import Foundation

/// Stable symptom ids. Never translate these strings.
public enum SymptomId: String, Codable, CaseIterable, Sendable {
    case hot_flash
    case heart
    case sleep
    case joints
    case mood
    case irritability
    case anxiety
    case exhaustion
    case sexual
    case bladder
    case vaginal_dryness

    public var group: SymptomGroup {
        switch self {
        case .hot_flash, .heart, .sleep, .joints: return .body
        case .mood, .irritability, .anxiety, .exhaustion: return .mood
        case .sexual, .bladder, .vaginal_dryness: return .urogenital
        }
    }

    /// Every catalog id is scored with higher = worse.
    public var higherIsWorse: Bool { true }
}

public enum SymptomGroup: String, CaseIterable, Sendable {
    case body
    case mood
    case urogenital

    public var ids: [SymptomId] {
        SymptomId.allCases.filter { $0.group == self }
    }
}

/// One scored row. Identity in a backup is (`date`, `id`).
public struct SymptomScore: Codable, Equatable, Sendable {
    /// Stable catalog id (`hot_flash`, …), never a UUID.
    public var id: String
    public var date: String
    /// 0 = none, 4 = very strong. Missing rows are omitted, not zero.
    public var severity: Int
    /// Hot flushes only: optional episode count for that day.
    public var count: Int?
    public var note: String?
    public var loggedAt: String
    public var higherIsWorse: Bool

    public var rowId: String { "\(date)#\(id)" }

    public init(
        id: String,
        date: String,
        severity: Int,
        count: Int? = nil,
        note: String? = nil,
        loggedAt: String,
        higherIsWorse: Bool = true
    ) {
        self.id = id
        self.date = date
        self.severity = severity
        self.count = count
        self.note = note
        self.loggedAt = loggedAt
        self.higherIsWorse = higherIsWorse
    }

    enum CodingKeys: String, CodingKey {
        case id, date, severity, count, note, loggedAt, higherIsWorse
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        date = try c.decode(String.self, forKey: .date)
        severity = try c.decode(Int.self, forKey: .severity)
        count = try c.decodeIfPresent(Int.self, forKey: .count)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        loggedAt = try c.decode(String.self, forKey: .loggedAt)
        higherIsWorse = try c.decodeIfPresent(Bool.self, forKey: .higherIsWorse) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(date, forKey: .date)
        try c.encode(severity, forKey: .severity)
        try c.encodeIfPresent(count, forKey: .count)
        if let note, !note.isEmpty {
            try c.encode(note, forKey: .note)
        }
        try c.encode(loggedAt, forKey: .loggedAt)
        try c.encode(higherIsWorse, forKey: .higherIsWorse)
    }
}

public enum SymptomLog {
    public static let minSeverity = 0
    public static let maxSeverity = 4
    public static let maxCount = 99

    public static func isCatalogId(_ id: String) -> Bool {
        SymptomId(rawValue: id) != nil
    }

    public static func clampSeverity(_ value: Int) -> Int {
        min(maxSeverity, max(minSeverity, value))
    }

    public static func clampCount(_ value: Int) -> Int {
        min(maxCount, max(0, value))
    }

    /// At most one scored record per id per calendar day. Incoming replaces that id’s score.
    public static func upserting(_ scores: [SymptomScore], incoming: SymptomScore) -> [SymptomScore] {
        var next = scores.filter { !($0.date == incoming.date && $0.id == incoming.id) }
        next.append(normalized(incoming))
        return next
    }

    public static func replacingDay(
        _ scores: [SymptomScore],
        date: String,
        with dayScores: [SymptomScore]
    ) -> [SymptomScore] {
        let kept = scores.filter { $0.date != date }
        var seen = Set<String>()
        var incoming: [SymptomScore] = []
        for raw in dayScores where raw.date == date {
            let row = normalized(raw)
            if seen.contains(row.id) {
                incoming.removeAll { $0.id == row.id }
            }
            seen.insert(row.id)
            incoming.append(row)
        }
        return kept + incoming
    }

    /// Mean of logged severities. Missing days and remarks are ignored — never treated as 0.
    public static func meanSeverity(
        _ scores: [SymptomScore],
        id: String,
        from: String? = nil,
        to: String? = nil
    ) -> Double? {
        let vals = scores.compactMap { row -> Int? in
            guard row.id == id else { return nil }
            if let from, row.date < from { return nil }
            if let to, row.date > to { return nil }
            return row.severity
        }
        guard !vals.isEmpty else { return nil }
        return Double(vals.reduce(0, +)) / Double(vals.count)
    }

    public static func normalized(_ score: SymptomScore) -> SymptomScore {
        var row = score
        row.severity = clampSeverity(row.severity)
        if let count = row.count {
            row.count = clampCount(count)
        }
        if let note = row.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            row.note = note
        } else {
            row.note = nil
        }
        row.higherIsWorse = true
        return row
    }
}
