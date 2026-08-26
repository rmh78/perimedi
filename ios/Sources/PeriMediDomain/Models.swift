import Foundation

public enum MedForm: String, Codable, CaseIterable, Sendable {
    case PILL, CREAM, DROPS, INJECTION, OTHER
}

public enum DoseStatus: String, Codable, Sendable {
    case pending, taken, skipped
}

public enum CycleRule: String, Codable, Sendable {
    case none
    case period_only
    case cycle_day_range
}

public enum RemarkKind: String, Codable, CaseIterable, Sendable {
    case side_effect
    case note
    case cycle
    case other
}

public enum FlowNote: String, Codable, CaseIterable, Sendable {
    case spotting, light, medium, heavy
}

public struct Medication: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var form: MedForm
    public var doseLabel: String
    public var instructions: String?
    public var color: String?
    public var createdAt: String
    /// Missing in older backups means on.
    public var remindersEnabled: Bool

    public init(
        id: String,
        name: String,
        form: MedForm,
        doseLabel: String,
        instructions: String? = nil,
        color: String? = nil,
        createdAt: String,
        remindersEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.form = form
        self.doseLabel = doseLabel
        self.instructions = instructions
        self.color = color
        self.createdAt = createdAt
        self.remindersEnabled = remindersEnabled
    }

    enum CodingKeys: String, CodingKey {
        case id, name, form, doseLabel, instructions, color, createdAt, remindersEnabled
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        form = try c.decode(MedForm.self, forKey: .form)
        doseLabel = try c.decode(String.self, forKey: .doseLabel)
        instructions = try c.decodeIfPresent(String.self, forKey: .instructions)
        color = try c.decodeIfPresent(String.self, forKey: .color)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        remindersEnabled = try c.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(form, forKey: .form)
        try c.encode(doseLabel, forKey: .doseLabel)
        try c.encodeIfPresent(instructions, forKey: .instructions)
        try c.encodeIfPresent(color, forKey: .color)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(remindersEnabled, forKey: .remindersEnabled)
    }
}

public struct WeekPatternSlot: Codable, Equatable, Sendable {
    public var take: Bool
    public var doseLabel: String?
    public var name: String?

    public init(take: Bool, doseLabel: String? = nil, name: String? = nil) {
        self.take = take
        self.doseLabel = doseLabel
        self.name = name
    }
}

public struct WeekPattern: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var anchorDate: String
    public var slots: [WeekPatternSlot]

    public init(enabled: Bool, anchorDate: String, slots: [WeekPatternSlot]) {
        self.enabled = enabled
        self.anchorDate = anchorDate
        self.slots = slots
    }
}

public enum TherapyCycleMode: String, Codable, Sendable {
    case continuous
    case on_off_days
    case week_slots
}

public struct TherapyCycle: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var mode: TherapyCycleMode
    public var anchorDate: String
    public var onDays: Int
    public var offDays: Int
    public var slots: [WeekPatternSlot]?

    public init(
        enabled: Bool,
        mode: TherapyCycleMode,
        anchorDate: String,
        onDays: Int,
        offDays: Int,
        slots: [WeekPatternSlot]? = nil
    ) {
        self.enabled = enabled
        self.mode = mode
        self.anchorDate = anchorDate
        self.onDays = onDays
        self.offDays = offDays
        self.slots = slots
    }
}

public struct Schedule: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var medicationId: String
    public var daysOfWeek: [Int]
    public var timeOfDay: String
    public var times: [String]?
    public var doseLabel: String?
    public var active: Bool
    public var startDate: String?
    public var endDate: String?
    public var cycleRule: CycleRule
    public var cycleDayFrom: Int?
    public var cycleDayTo: Int?
    public var therapyCycle: TherapyCycle?
    public var weekPattern: WeekPattern?

    public init(
        id: String,
        medicationId: String,
        daysOfWeek: [Int],
        timeOfDay: String,
        times: [String]? = nil,
        doseLabel: String? = nil,
        active: Bool,
        startDate: String? = nil,
        endDate: String? = nil,
        cycleRule: CycleRule,
        cycleDayFrom: Int? = nil,
        cycleDayTo: Int? = nil,
        therapyCycle: TherapyCycle? = nil,
        weekPattern: WeekPattern? = nil
    ) {
        self.id = id
        self.medicationId = medicationId
        self.daysOfWeek = daysOfWeek
        self.timeOfDay = timeOfDay
        self.times = times
        self.doseLabel = doseLabel
        self.active = active
        self.startDate = startDate
        self.endDate = endDate
        self.cycleRule = cycleRule
        self.cycleDayFrom = cycleDayFrom
        self.cycleDayTo = cycleDayTo
        self.therapyCycle = therapyCycle
        self.weekPattern = weekPattern
    }
}

public struct DoseLog: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var medicationId: String
    public var scheduleId: String?
    public var plannedFor: String
    public var status: DoseStatus
    public var confirmedAt: String?
    public var skipReason: String?

    public init(
        id: String,
        medicationId: String,
        scheduleId: String? = nil,
        plannedFor: String,
        status: DoseStatus,
        confirmedAt: String? = nil,
        skipReason: String? = nil
    ) {
        self.id = id
        self.medicationId = medicationId
        self.scheduleId = scheduleId
        self.plannedFor = plannedFor
        self.status = status
        self.confirmedAt = confirmedAt
        self.skipReason = skipReason
    }
}

public struct Remark: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var medicationId: String?
    public var occurredOn: String
    public var kind: RemarkKind
    public var body: String
    public var createdAt: String

    public init(
        id: String,
        medicationId: String? = nil,
        occurredOn: String,
        kind: RemarkKind,
        body: String,
        createdAt: String
    ) {
        self.id = id
        self.medicationId = medicationId
        self.occurredOn = occurredOn
        self.kind = kind
        self.body = body
        self.createdAt = createdAt
    }
}

public struct CycleSettings: Codable, Equatable, Sendable {
    public var id: String
    public var averageCycleLength: Int
    public var averagePeriodLength: Int
    public var tracksPeriods: Bool

    public static let `default` = CycleSettings(
        id: "default",
        averageCycleLength: 28,
        averagePeriodLength: 5,
        tracksPeriods: true
    )

    public init(
        id: String = "default",
        averageCycleLength: Int,
        averagePeriodLength: Int,
        tracksPeriods: Bool = true
    ) {
        self.id = id
        self.averageCycleLength = averageCycleLength
        self.averagePeriodLength = averagePeriodLength
        self.tracksPeriods = tracksPeriods
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? "default"
        averageCycleLength = try c.decode(Int.self, forKey: .averageCycleLength)
        averagePeriodLength = try c.decode(Int.self, forKey: .averagePeriodLength)
        tracksPeriods = try c.decodeIfPresent(Bool.self, forKey: .tracksPeriods) ?? true
    }
}

public struct Period: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var startDate: String
    public var endDate: String?
    public var flowNote: FlowNote?
    public var notes: String?

    public init(
        id: String,
        startDate: String,
        endDate: String? = nil,
        flowNote: FlowNote? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.flowNote = flowNote
        self.notes = notes
    }
}

public struct ExportPayload: Codable, Equatable, Sendable {
    public var version: Int
    public var exportedAt: String
    public var medications: [Medication]
    public var schedules: [Schedule]
    public var doseLogs: [DoseLog]
    public var remarks: [Remark]
    public var cycleSettings: CycleSettings
    public var periods: [Period]
    /// Structured 0–4 scores. Absent in older backups.
    public var symptomScores: [SymptomScore]

    public init(
        version: Int = 1,
        exportedAt: String,
        medications: [Medication],
        schedules: [Schedule],
        doseLogs: [DoseLog],
        remarks: [Remark],
        cycleSettings: CycleSettings,
        periods: [Period],
        symptomScores: [SymptomScore] = []
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.medications = medications
        self.schedules = schedules
        self.doseLogs = doseLogs
        self.remarks = remarks
        self.cycleSettings = cycleSettings
        self.periods = periods
        self.symptomScores = symptomScores
    }

    enum CodingKeys: String, CodingKey {
        case version, exportedAt, medications, schedules, doseLogs, remarks, cycleSettings, periods, symptomScores
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        exportedAt = try c.decode(String.self, forKey: .exportedAt)
        medications = try c.decodeIfPresent([Medication].self, forKey: .medications) ?? []
        schedules = try c.decodeIfPresent([Schedule].self, forKey: .schedules) ?? []
        doseLogs = try c.decodeIfPresent([DoseLog].self, forKey: .doseLogs) ?? []
        remarks = try c.decodeIfPresent([Remark].self, forKey: .remarks) ?? []
        cycleSettings = try c.decode(CycleSettings.self, forKey: .cycleSettings)
        periods = try c.decodeIfPresent([Period].self, forKey: .periods) ?? []
        symptomScores = try c.decodeIfPresent([SymptomScore].self, forKey: .symptomScores) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(exportedAt, forKey: .exportedAt)
        try c.encode(medications, forKey: .medications)
        try c.encode(schedules, forKey: .schedules)
        try c.encode(doseLogs, forKey: .doseLogs)
        try c.encode(remarks, forKey: .remarks)
        try c.encode(cycleSettings, forKey: .cycleSettings)
        try c.encode(periods, forKey: .periods)
        try c.encode(symptomScores, forKey: .symptomScores)
    }
}

public struct DayCycleInfo: Equatable, Sendable {
    public var date: String
    public var isLoggedPeriod: Bool
    public var isPredictedPeriod: Bool
    public var cycleDay: Int?

    public init(date: String, isLoggedPeriod: Bool, isPredictedPeriod: Bool, cycleDay: Int?) {
        self.date = date
        self.isLoggedPeriod = isLoggedPeriod
        self.isPredictedPeriod = isPredictedPeriod
        self.cycleDay = cycleDay
    }
}

public struct PlannedDose: Equatable, Identifiable, Sendable {
    public var key: String
    public var date: String
    public var timeOfDay: String
    public var medication: Medication
    public var schedule: Schedule
    public var doseLabel: String
    public var log: DoseLog?
    public var status: DoseStatus

    public var id: String { key }

    public init(
        key: String,
        date: String,
        timeOfDay: String,
        medication: Medication,
        schedule: Schedule,
        doseLabel: String,
        log: DoseLog?,
        status: DoseStatus
    ) {
        self.key = key
        self.date = date
        self.timeOfDay = timeOfDay
        self.medication = medication
        self.schedule = schedule
        self.doseLabel = doseLabel
        self.log = log
        self.status = status
    }
}

public struct CycleBoundaryMark: Equatable, Sendable {
    public var isStart: Bool
    public var isEnd: Bool

    public init(isStart: Bool, isEnd: Bool) {
        self.isStart = isStart
        self.isEnd = isEnd
    }
}

public enum TherapyPresetId: String, CaseIterable, Sendable {
    case continuous
    case days21_7 = "21_7"
    case days14_7 = "14_7"
    case days7_7 = "7_7"
    case days5_2 = "5_2"
    case custom_days
    case week_slots
}

public func createId() -> String {
    UUID().uuidString.lowercased()
}
