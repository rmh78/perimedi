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
        let ordered = best.values.sorted { a, b in
            if a.sort != b.sort { return a.sort < b.sort }
            return a.id.rawValue < b.id.rawValue
        }
        return SymptomDirectory(customs: ordered)
    }

    static func restored(from wires: [CustomSymptomWire]) -> SymptomDirectory {
        let rows: [CustomSymptom] = wires.compactMap { wire in
            guard let id = CustomSymptomId(rawValue: wire.id) else { return nil }
            return CustomSymptom(id: id, name: wire.name, sort: wire.sort)
        }
        return restored(rows)
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

    public func removing(_ id: CustomSymptomId) -> SymptomDirectory {
        SymptomDirectory(customs: customs.filter { $0.id != id })
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

    public func index(of storageId: String) -> Int? {
        rankedIds.firstIndex(of: storageId)
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
        return SymptomDirectory.restored(from: boxes.compactMap(\.wire)).customs
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
