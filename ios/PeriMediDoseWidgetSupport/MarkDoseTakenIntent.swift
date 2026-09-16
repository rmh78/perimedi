import AppIntents
import PeriMediDomain

enum MarkSlotTakenResult: Equatable, Sendable {
    case taken
    case alreadyTaken
    case notPlanned
}

enum MarkMedicationTakenResult: Equatable, Sendable {
    case taken
    case alreadyTaken
    case notPlanned
}

enum MarkDoseTakenError: Error, Equatable {
    case notHostedByApp
    case saveFailed
}

enum MarkTodayMedicationTakenRuntime {
    static var run: ((String) throws -> MarkMedicationTakenResult)?
}

struct MarkTodayMedicationTakenIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark medication taken"
    static var openAppWhenRun = true
    static var isDiscoverable = false

    @Parameter(title: "Medication")
    var medicationId: String

    init() {
        medicationId = ""
    }

    init(medicationId: String) {
        self.medicationId = medicationId
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let run = MarkTodayMedicationTakenRuntime.run else {
            throw MarkDoseTakenError.notHostedByApp
        }
        _ = try run(medicationId)
        return .result()
    }
}

#if PERIMEDI_APP
@available(iOSApplicationExtension, unavailable)
extension MarkTodayMedicationTakenIntent: ForegroundContinuableIntent {}
#endif
