import Foundation

/// Storage id for one user-defined symptom. Not a display name.
/// Raw form is `c.` plus a lowercase UUID.
public struct CustomSymptomId: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard rawValue.hasPrefix("c.") else { return nil }
        let rest = String(rawValue.dropFirst(2))
        guard let uuid = UUID(uuidString: rest) else { return nil }
        guard rest == uuid.uuidString.lowercased() else { return nil }
        self.rawValue = rawValue
    }

    public static func mint() -> CustomSymptomId {
        let raw = "c.\(UUID().uuidString.lowercased())"
        return CustomSymptomId(rawValue: raw)!
    }
}

/// One definition. Identity is `id`. `name` is trimmed user text. `sort` is creation order.
public struct CustomSymptom: Hashable, Sendable, Codable, Identifiable {
    public var id: CustomSymptomId
    public var name: String
    public var sort: Int

    public init(id: CustomSymptomId, name: String, sort: Int) {
        self.id = id
        self.name = name
        self.sort = sort
    }
}

public struct ScoreRecordId: Hashable, Sendable, Comparable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static func < (lhs: ScoreRecordId, rhs: ScoreRecordId) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct ScoredRecord: Equatable, Sendable {
    public var id: ScoreRecordId
    public var score: SymptomScore

    public init(id: ScoreRecordId, score: SymptomScore) {
        self.id = id
        self.score = score
    }
}

public struct ScoreKeep: Equatable, Sendable {
    public var recordId: ScoreRecordId
    public var score: SymptomScore

    public init(recordId: ScoreRecordId, score: SymptomScore) {
        self.recordId = recordId
        self.score = score
    }
}

public enum RepairInstruction: Equatable, Sendable {
    case deleteCustom(CustomSymptomId)
    case keep(ScoreKeep)
    case deleteScore(ScoreRecordId)
}

public struct SymptomSync: Equatable, Sendable {
    public var directory: SymptomDirectory
    public var scores: [SymptomScore]
    public var instructions: [RepairInstruction]
    public var memory: RememberedScoreRewrites

    public init(
        directory: SymptomDirectory,
        scores: [SymptomScore],
        instructions: [RepairInstruction],
        memory: RememberedScoreRewrites
    ) {
        self.directory = directory
        self.scores = scores
        self.instructions = instructions
        self.memory = memory
    }

    public var droppedIds: [CustomSymptomId] {
        instructions.compactMap { instruction in
            guard case .deleteCustom(let id) = instruction else { return nil }
            return id
        }
    }
}

public struct RememberedScoreRewrites: Equatable, Sendable {
    public static let none = RememberedScoreRewrites(pairs: [:])

    public let pairs: [CustomSymptomId: CustomSymptomId]

    init(pairs: [CustomSymptomId: CustomSymptomId]) {
        self.pairs = pairs
    }

    public init(wire: [String: String]) {
        var pairs: [CustomSymptomId: CustomSymptomId] = [:]
        for (key, value) in wire {
            guard
                let loser = CustomSymptomId(rawValue: key),
                let winner = CustomSymptomId(rawValue: value),
                loser != winner
            else { continue }
            pairs[loser] = winner
        }
        self.pairs = pairs
    }

    public var wire: [String: String] {
        var encoded: [String: String] = [:]
        encoded.reserveCapacity(pairs.count)
        for (loser, winner) in pairs {
            encoded[loser.rawValue] = winner.rawValue
        }
        return encoded
    }

    public func remembering(
        _ additions: [CustomSymptomId: CustomSymptomId],
        stoppingAt kept: Set<CustomSymptomId> = []
    ) -> RememberedScoreRewrites {
        var overlaid = pairs
        for (loser, winner) in additions where loser != winner {
            overlaid[loser] = winner
        }
        var flat: [CustomSymptomId: CustomSymptomId] = [:]
        flat.reserveCapacity(overlaid.count)
        for loser in overlaid.keys {
            guard let winner = Self.terminal(of: loser, in: overlaid, stoppingAt: kept) else { continue }
            flat[loser] = winner
        }
        return RememberedScoreRewrites(pairs: flat)
    }

    private static func terminal(
        of loser: CustomSymptomId,
        in edges: [CustomSymptomId: CustomSymptomId],
        stoppingAt kept: Set<CustomSymptomId>
    ) -> CustomSymptomId? {
        guard let direct = edges[loser], direct != loser else { return nil }
        if kept.contains(loser) { return direct }
        var seen: Set<CustomSymptomId> = [loser]
        var current = direct
        while !kept.contains(current), let next = edges[current] {
            if !seen.insert(current).inserted { return nil }
            current = next
        }
        guard current != loser else { return nil }
        return current
    }
}

public enum SymptomEditError: Error, Equatable, Sendable {
    case blankName
    case nameTooLong
    case duplicateName
    case tooMany
    case unknownId
}

/// What a score id points at. Catalog raw values stay bare (`hot_flash`).
public enum SymptomRef: Hashable, Sendable {
    case catalog(SymptomId)
    case custom(CustomSymptomId)

    public var storageId: String {
        switch self {
        case .catalog(let id): return id.rawValue
        case .custom(let id): return id.rawValue
        }
    }

    public static func parse(_ storageId: String) -> SymptomRef? {
        if let id = SymptomId(rawValue: storageId) { return .catalog(id) }
        if let id = CustomSymptomId(rawValue: storageId) { return .custom(id) }
        return nil
    }
}

public enum SymptomBlock: Equatable, Sendable {
    case catalog(SymptomGroup, [SymptomId])
    case custom([CustomSymptom])
}

/// The symptoms that exist: the enum, then user definitions.
public struct SymptomDirectory: Equatable, Sendable {
    public static let addCap = 8
    public static let maxNameGraphemes = 40
    public static let catalogOnly = SymptomDirectory(customs: [])

    public let customs: [CustomSymptom]

    private init(customs: [CustomSymptom]) {
        self.customs = customs
    }

    public static func restored(_ rows: [CustomSymptom]) -> SymptomDirectory {
        SymptomDirectory(customs: folded(deduped(rows)))
    }

    static func accepted(from wires: [CustomSymptomWire]) -> [CustomSymptom] {
        let rows: [CustomSymptom] = wires.compactMap { wire in
            guard let id = CustomSymptomId(rawValue: wire.id) else { return nil }
            return CustomSymptom(id: id, name: wire.name, sort: wire.sort)
        }
        return deduped(rows)
    }

    private static func deduped(_ rows: [CustomSymptom]) -> [CustomSymptom] {
        var best: [CustomSymptomId: CustomSymptom] = [:]
        for row in rows {
            let name = clipped(row.name)
            guard !name.isEmpty else { continue }
            let symptom = CustomSymptom(id: row.id, name: name, sort: row.sort)
            if let existing = best[row.id] {
                if symptom.sort < existing.sort { best[row.id] = symptom }
            } else {
                best[row.id] = symptom
            }
        }
        return best.values.sorted { a, b in
            if a.sort != b.sort { return a.sort < b.sort }
            return a.id.rawValue < b.id.rawValue
        }
    }

    private static func folded(_ rows: [CustomSymptom]) -> [CustomSymptom] {
        var kept: [String: CustomSymptom] = [:]
        var order: [String] = []
        for row in rows {
            let key = fold(row.name)
            guard kept[key] == nil else { continue }
            kept[key] = row
            order.append(key)
        }
        return order.compactMap { kept[$0] }
    }

    public func adding(
        _ rawName: String,
        mint id: CustomSymptomId = .mint()
    ) -> Result<(SymptomDirectory, CustomSymptom), SymptomEditError> {
        let name: String
        switch checked(rawName, allowing: nil) {
        case .success(let value): name = value
        case .failure(let error): return .failure(error)
        }
        if customs.count >= Self.addCap { return .failure(.tooMany) }
        let sort = (customs.map(\.sort).max() ?? -1) + 1
        let created = CustomSymptom(id: id, name: name, sort: sort)
        return .success((SymptomDirectory(customs: customs + [created]), created))
    }

    public func renaming(
        _ id: CustomSymptomId,
        to rawName: String
    ) -> Result<SymptomDirectory, SymptomEditError> {
        guard customs.contains(where: { $0.id == id }) else { return .failure(.unknownId) }
        let name: String
        switch checked(rawName, allowing: id) {
        case .success(let value): name = value
        case .failure(let error): return .failure(error)
        }
        let next = customs.map { symptom -> CustomSymptom in
            guard symptom.id == id else { return symptom }
            return CustomSymptom(id: symptom.id, name: name, sort: symptom.sort)
        }
        return .success(SymptomDirectory(customs: next))
    }

    public var blocks: [SymptomBlock] {
        let catalog = SymptomGroup.allCases.map { group in
            SymptomBlock.catalog(group, group.ids)
        }
        return catalog + [.custom(customs)]
    }

    public var rankedIds: [String] {
        SymptomId.allCases.map(\.rawValue) + customs.map(\.id.rawValue)
    }

    public func contains(_ storageId: String) -> Bool {
        index(of: storageId) != nil
    }

    public func scoresOnCalendar(_ scores: [SymptomScore]) -> [SymptomScore] {
        scores.filter { contains($0.id) }
    }

    public func index(of storageId: String) -> Int? {
        rankedIds.firstIndex(of: storageId)
    }

    public static func synced(
        rows: [CustomSymptom],
        scores: [SymptomScore],
        memory: RememberedScoreRewrites = .none
    ) -> SymptomSync {
        fold(
            rows: rows,
            incoming: scores.map { Incoming(recordId: nil, score: $0) },
            memory: memory
        )
    }

    public static func synced(
        rows: [CustomSymptom],
        records: [ScoredRecord],
        memory: RememberedScoreRewrites = .none
    ) -> SymptomSync {
        fold(
            rows: rows,
            incoming: records.map { Incoming(recordId: $0.id, score: $0.score) },
            memory: memory
        )
    }

    private struct Incoming {
        var recordId: ScoreRecordId?
        var score: SymptomScore
    }

    private struct Slot: Hashable {
        var date: String
        var symptomId: String
    }

    private struct Bucket {
        var ranked: RankedScore
        var recordIds: [ScoreRecordId]
    }

    private static func fold(
        rows: [CustomSymptom],
        incoming: [Incoming],
        memory: RememberedScoreRewrites
    ) -> SymptomSync {
        let cleaned = deduped(rows)
        let customs = folded(cleaned)
        let directory = SymptomDirectory(customs: customs)
        var winnerByFold: [String: CustomSymptomId] = [:]
        for symptom in customs {
            winnerByFold[fold(symptom.name)] = symptom.id
        }
        var fresh: [CustomSymptomId: CustomSymptomId] = [:]
        for symptom in cleaned {
            guard let winner = winnerByFold[fold(symptom.name)], winner != symptom.id else { continue }
            fresh[symptom.id] = winner
        }
        let kept = Set(customs.map(\.id))
        let nextMemory = memory.remembering(fresh, stoppingAt: kept)
        let rewrites = merging(nextMemory, kept: kept)
        var buckets: [Slot: Bucket] = [:]
        for item in incoming {
            guard let mapped = map(item.score, rewrites: rewrites, kept: kept) else { continue }
            let slot = Slot(date: mapped.date, symptomId: mapped.id)
            let ranked = RankedScore(score: mapped, originalId: item.score.id)
            var bucket = buckets[slot] ?? Bucket(ranked: ranked, recordIds: [])
            if buckets[slot] != nil {
                bucket.ranked = prefer(bucket.ranked, ranked)
            }
            if let recordId = item.recordId {
                bucket.recordIds.append(recordId)
            }
            buckets[slot] = bucket
        }
        let orderedBuckets = buckets.values.sorted { a, b in
            let left = a.ranked.score
            let right = b.ranked.score
            if left.date != right.date { return left.date < right.date }
            return left.id < right.id
        }
        let dropped = cleaned.map(\.id).filter { !kept.contains($0) }.sorted { $0.rawValue < $1.rawValue }
        var instructions = dropped.map { RepairInstruction.deleteCustom($0) }
        for bucket in orderedBuckets {
            guard let keeper = bucket.recordIds.min() else { continue }
            instructions.append(.keep(ScoreKeep(recordId: keeper, score: bucket.ranked.score)))
            let extras = Set(bucket.recordIds).subtracting([keeper]).sorted()
            instructions.append(contentsOf: extras.map { .deleteScore($0) })
        }
        return SymptomSync(
            directory: directory,
            scores: orderedBuckets.map(\.ranked.score),
            instructions: instructions,
            memory: nextMemory
        )
    }

    private static func merging(
        _ memory: RememberedScoreRewrites,
        kept: Set<CustomSymptomId>
    ) -> [CustomSymptomId: CustomSymptomId] {
        var rewrites: [CustomSymptomId: CustomSymptomId] = [:]
        for (loser, winner) in memory.pairs {
            if loser == winner { continue }
            if kept.contains(loser) { continue }
            if !kept.contains(winner) { continue }
            rewrites[loser] = winner
        }
        return rewrites
    }

    private static func map(
        _ score: SymptomScore,
        rewrites: [CustomSymptomId: CustomSymptomId],
        kept: Set<CustomSymptomId>
    ) -> SymptomScore? {
        guard let custom = CustomSymptomId(rawValue: score.id) else { return score }
        if let winner = rewrites[custom] {
            return SymptomScore(
                id: winner.rawValue,
                date: score.date,
                severity: score.severity,
                count: score.count,
                note: score.note,
                loggedAt: score.loggedAt,
                higherIsWorse: score.higherIsWorse
            )
        }
        guard kept.contains(custom) else { return nil }
        return score
    }

    private struct RankedScore {
        var score: SymptomScore
        var originalId: String
    }

    private static func prefer(_ current: RankedScore, _ incoming: RankedScore) -> RankedScore {
        let kept = current.score
        let next = incoming.score
        if kept.loggedAt != next.loggedAt {
            return kept.loggedAt > next.loggedAt ? current : incoming
        }
        if kept.severity != next.severity {
            return kept.severity > next.severity ? current : incoming
        }
        let keptCount = kept.count ?? Int.min
        let nextCount = next.count ?? Int.min
        if keptCount != nextCount {
            return keptCount > nextCount ? current : incoming
        }
        let keptNote = kept.note ?? ""
        let nextNote = next.note ?? ""
        if keptNote != nextNote {
            return keptNote > nextNote ? current : incoming
        }
        if current.originalId != incoming.originalId {
            return current.originalId < incoming.originalId ? current : incoming
        }
        if kept.higherIsWorse != next.higherIsWorse {
            return kept.higherIsWorse ? current : incoming
        }
        return current
    }

    /// Catalog scores stay. A custom id stays only when this directory still has it.
    public static func scoresToStore(
        _ scores: [SymptomScore],
        directory: SymptomDirectory
    ) -> [SymptomScore] {
        let live = Set(directory.customs.map(\.id.rawValue))
        return scores.filter { score in
            guard CustomSymptomId(rawValue: score.id) != nil else { return true }
            return live.contains(score.id)
        }
    }

    public func name(for storageId: String) -> String? {
        guard let id = CustomSymptomId(rawValue: storageId) else { return nil }
        return customs.first { $0.id == id }?.name
    }

    private func checked(
        _ rawName: String,
        allowing id: CustomSymptomId?
    ) -> Result<String, SymptomEditError> {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return .failure(.blankName) }
        if name.count > Self.maxNameGraphemes { return .failure(.nameTooLong) }
        let folded = Self.fold(name)
        let clash = customs.contains { symptom in
            symptom.id != id && Self.fold(symptom.name) == folded
        }
        if clash { return .failure(.duplicateName) }
        return .success(name)
    }

    static func fold(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
    }

    private static func clipped(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= maxNameGraphemes { return trimmed }
        return String(trimmed.prefix(maxNameGraphemes))
    }
}

struct CustomSymptomWire: Decodable {
    var id: String
    var name: String
    var sort: Int
}

struct LenientCustomSymptom: Decodable {
    var wire: CustomSymptomWire?

    init(from decoder: Decoder) throws {
        wire = try? CustomSymptomWire(from: decoder)
    }
}

enum CustomSymptomBackup {
    static func symptoms<K: CodingKey>(from container: KeyedDecodingContainer<K>, key: K) -> [CustomSymptom] {
        guard container.contains(key) else { return [] }
        let boxes = (try? container.decode([LenientCustomSymptom].self, forKey: key)) ?? []
        return SymptomDirectory.accepted(from: boxes.compactMap(\.wire))
    }
}

public enum SymptomDay {
    public static func row(
        date: String,
        ref: SymptomRef,
        severity: Int?,
        loggedAt: String
    ) -> SymptomScore? {
        guard let severity, (1...4).contains(severity) else { return nil }
        return SymptomScore(
            id: ref.storageId,
            date: date,
            severity: severity,
            count: nil,
            note: nil,
            loggedAt: loggedAt,
            higherIsWorse: true
        )
    }
}
