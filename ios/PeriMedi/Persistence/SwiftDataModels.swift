import Foundation
import SwiftData
import PeriMediDomain

@Model
final class SDMedication {
    var id: String = ""
    var name: String = ""
    var formRaw: String = MedForm.PILL.rawValue
    var doseLabel: String = ""
    var instructions: String?
    var color: String?
    var createdAt: String = ""

    init() {}

    func toDomain() -> Medication {
        Medication(
            id: id,
            name: name,
            form: MedForm(rawValue: formRaw) ?? .OTHER,
            doseLabel: doseLabel,
            instructions: instructions,
            color: color,
            createdAt: createdAt
        )
    }

    func apply(_ m: Medication) {
        id = m.id
        name = m.name
        formRaw = m.form.rawValue
        doseLabel = m.doseLabel
        instructions = m.instructions
        color = m.color
        createdAt = m.createdAt
    }
}

@Model
final class SDSchedule {
    var id: String = ""
    var medicationId: String = ""
    var daysOfWeekJSON: String = "[]"
    var timeOfDay: String = "08:00"
    var timesJSON: String?
    var doseLabel: String?
    var active: Bool = true
    var startDate: String?
    var endDate: String?
    var cycleRuleRaw: String = CycleRule.none.rawValue
    var cycleDayFrom: Int?
    var cycleDayTo: Int?
    var therapyJSON: String?
    var weekPatternJSON: String?

    init() {}

    func toDomain() -> Schedule {
        let days = (try? JSONDecoder().decode([Int].self, from: Data(daysOfWeekJSON.utf8))) ?? []
        let times = timesJSON.flatMap { try? JSONDecoder().decode([String].self, from: Data($0.utf8)) }
        let therapy = therapyJSON.flatMap { try? JSONDecoder().decode(TherapyCycle.self, from: Data($0.utf8)) }
        let week = weekPatternJSON.flatMap { try? JSONDecoder().decode(WeekPattern.self, from: Data($0.utf8)) }
        return Schedule(
            id: id,
            medicationId: medicationId,
            daysOfWeek: days,
            timeOfDay: timeOfDay,
            times: times,
            doseLabel: doseLabel,
            active: active,
            startDate: startDate,
            endDate: endDate,
            cycleRule: CycleRule(rawValue: cycleRuleRaw) ?? .none,
            cycleDayFrom: cycleDayFrom,
            cycleDayTo: cycleDayTo,
            therapyCycle: therapy,
            weekPattern: week
        )
    }

    func apply(_ s: Schedule) {
        id = s.id
        medicationId = s.medicationId
        daysOfWeekJSON = stringJSON(s.daysOfWeek)
        timeOfDay = s.timeOfDay
        timesJSON = s.times.map(stringJSON)
        doseLabel = s.doseLabel
        active = s.active
        startDate = s.startDate
        endDate = s.endDate
        cycleRuleRaw = s.cycleRule.rawValue
        cycleDayFrom = s.cycleDayFrom
        cycleDayTo = s.cycleDayTo
        therapyJSON = s.therapyCycle.map(stringJSON)
        weekPatternJSON = s.weekPattern.map(stringJSON)
    }
}

@Model
final class SDDoseLog {
    var id: String = ""
    var medicationId: String = ""
    var scheduleId: String?
    var plannedFor: String = ""
    var statusRaw: String = DoseStatus.pending.rawValue
    var confirmedAt: String?
    var skipReason: String?

    init() {}

    func toDomain() -> DoseLog {
        DoseLog(
            id: id,
            medicationId: medicationId,
            scheduleId: scheduleId,
            plannedFor: plannedFor,
            status: DoseStatus(rawValue: statusRaw) ?? .pending,
            confirmedAt: confirmedAt,
            skipReason: skipReason
        )
    }

    func apply(_ l: DoseLog) {
        id = l.id
        medicationId = l.medicationId
        scheduleId = l.scheduleId
        plannedFor = l.plannedFor
        statusRaw = l.status.rawValue
        confirmedAt = l.confirmedAt
        skipReason = l.skipReason
    }
}

@Model
final class SDRemark {
    var id: String = ""
    var medicationId: String?
    var occurredOn: String = ""
    var kindRaw: String = RemarkKind.note.rawValue
    var body: String = ""
    var createdAt: String = ""

    init() {}

    func toDomain() -> Remark {
        Remark(
            id: id,
            medicationId: medicationId,
            occurredOn: occurredOn,
            kind: RemarkKind(rawValue: kindRaw) ?? .note,
            body: body,
            createdAt: createdAt
        )
    }

    func apply(_ r: Remark) {
        id = r.id
        medicationId = r.medicationId
        occurredOn = r.occurredOn
        kindRaw = r.kind.rawValue
        body = r.body
        createdAt = r.createdAt
    }
}

@Model
final class SDPeriod {
    var id: String = ""
    var startDate: String = ""
    var endDate: String?
    var flowNoteRaw: String?
    var notes: String?

    init() {}

    func toDomain() -> Period {
        Period(
            id: id,
            startDate: startDate,
            endDate: endDate,
            flowNote: flowNoteRaw.flatMap(FlowNote.init(rawValue:)),
            notes: notes
        )
    }

    func apply(_ p: Period) {
        id = p.id
        startDate = p.startDate
        endDate = p.endDate
        flowNoteRaw = p.flowNote?.rawValue
        notes = p.notes
    }
}

@Model
final class SDCycleSettings {
    var id: String = "default"
    var averageCycleLength: Int = 28
    var averagePeriodLength: Int = 5
    var tracksPeriods: Bool = true

    init() {}

    func toDomain() -> CycleSettings {
        CycleSettings(
            id: id,
            averageCycleLength: averageCycleLength,
            averagePeriodLength: averagePeriodLength,
            tracksPeriods: tracksPeriods
        )
    }

    func apply(_ s: CycleSettings) {
        id = s.id
        averageCycleLength = s.averageCycleLength
        averagePeriodLength = s.averagePeriodLength
        tracksPeriods = s.tracksPeriods
    }
}

private func stringJSON<T: Encodable>(_ value: T) -> String {
    let data = (try? JSONEncoder().encode(value)) ?? Data("[]".utf8)
    return String(data: data, encoding: .utf8) ?? "[]"
}
