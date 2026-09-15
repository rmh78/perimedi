import AppIntents
import PeriMediDomain

enum MarkSlotTakenResult: Equatable, Sendable {
    case taken
    case alreadyTaken
    case notPlanned
}

enum MarkDoseTakenError: Error, Equatable {
    case notHostedByApp
    case saveFailed
}

enum MarkDoseTakenRuntime {
    static var run: ((PlannedSlotIdentity) throws -> MarkSlotTakenResult)?
}

struct MarkDoseTakenIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark dose taken"
    static var openAppWhenRun = false
    static var isDiscoverable = false

    @Parameter(title: "Medication")
    var medicationId: String
    @Parameter(title: "Schedule")
    var scheduleId: String
    @Parameter(title: "Date")
    var date: String
    @Parameter(title: "Time")
    var timeOfDay: String

    init() {
        medicationId = ""
        scheduleId = ""
        date = ""
        timeOfDay = ""
    }

    init(medicationId: String, scheduleId: String, date: String, timeOfDay: String) {
        self.medicationId = medicationId
        self.scheduleId = scheduleId
        self.date = date
        self.timeOfDay = timeOfDay
    }

    init(identity: PlannedSlotIdentity) {
        self.init(
            medicationId: identity.medicationId,
            scheduleId: identity.scheduleId,
            date: identity.date,
            timeOfDay: identity.timeOfDay
        )
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let run = MarkDoseTakenRuntime.run else {
            throw MarkDoseTakenError.notHostedByApp
        }
        _ = try run(
            PlannedSlotIdentity(
                medicationId: medicationId,
                scheduleId: scheduleId,
                date: date,
                timeOfDay: timeOfDay
            )
        )
        return .result()
    }
}

#if PERIMEDI_APP
@available(iOSApplicationExtension, unavailable)
extension MarkDoseTakenIntent: ForegroundContinuableIntent {}
#endif
