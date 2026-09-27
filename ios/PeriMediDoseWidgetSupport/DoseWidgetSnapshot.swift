import Foundation
import PeriMediDomain

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
