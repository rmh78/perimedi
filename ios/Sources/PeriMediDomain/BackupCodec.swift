import Foundation

public enum BackupError: Error, Equatable, LocalizedError {
    case unsupportedVersion(Int)
    case invalidJSON

    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v):
            return "Unsupported backup version \(v)"
        case .invalidJSON:
            return "Not a valid PeriMedi backup"
        }
    }
}

public enum BackupCodec {
    public static func decode(_ data: Data) throws -> ExportPayload {
        let decoder = JSONDecoder()
        let payload: ExportPayload
        do {
            payload = try decoder.decode(ExportPayload.self, from: data)
        } catch {
            throw BackupError.invalidJSON
        }
        if payload.version != 1 {
            throw BackupError.unsupportedVersion(payload.version)
        }
        return payload
    }

    public static func encode(_ payload: ExportPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    public static func makeExport(
        medications: [Medication],
        schedules: [Schedule],
        doseLogs: [DoseLog],
        remarks: [Remark],
        cycleSettings: CycleSettings,
        periods: [Period],
        exportedAt: Date = Date()
    ) -> ExportPayload {
        ExportPayload(
            version: 1,
            exportedAt: ISO8601DateFormatter().string(from: exportedAt),
            medications: medications,
            schedules: schedules,
            doseLogs: doseLogs,
            remarks: remarks,
            cycleSettings: cycleSettings,
            periods: periods
        )
    }
}
