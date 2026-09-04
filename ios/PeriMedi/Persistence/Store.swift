import CoreData
import Foundation
import SwiftData
import PeriMediDomain

struct StoreSnapshot: Equatable {
    var medications: [Medication] = []
    var schedules: [Schedule] = []
    var doseLogs: [DoseLog] = []
    var remarks: [Remark] = []
    var symptomScores: [SymptomScore] = []
    var periods: [Period] = []
    var settings: CycleSettings = .default
    var medicationChanges: [MedicationChange] = []
}

enum PersistenceError: Error, Equatable {
    case saveFailed
    case fetchFailed
}

@MainActor
final class Store: ObservableObject {
    /// Single published bag so a refresh invalidates SwiftUI once, not six times.
    @Published private(set) var snapshot = StoreSnapshot()
    @Published private(set) var lastError: PersistenceError?

    var medications: [Medication] { snapshot.medications }
    var schedules: [Schedule] { snapshot.schedules }
    var doseLogs: [DoseLog] { snapshot.doseLogs }
    var remarks: [Remark] { snapshot.remarks }
    var symptomScores: [SymptomScore] { snapshot.symptomScores }
    var periods: [Period] { snapshot.periods }
    var settings: CycleSettings { snapshot.settings }
    var medicationChanges: [MedicationChange] { snapshot.medicationChanges }

    private let context: ModelContext
    var afterChange: (() -> Void)?
    private var observerTokens: [NSObjectProtocol] = []
    private var remoteRefreshTask: Task<Void, Never>?

    init(container: ModelContainer) {
        self.context = container.mainContext
        refresh()
        ensureSettings()
        startObservingRemoteChanges()
    }

    func dismissError() {
        lastError = nil
    }

    func refresh() {
        do {
            let next = try loadSnapshot()
            if next != snapshot {
                snapshot = next
                afterChange?()
            }
        } catch {
            lastError = .fetchFailed
        }
    }

    private func loadSnapshot() throws -> StoreSnapshot {
        var next = StoreSnapshot()
        next.medications = try fetchAll(SDMedication.self).map { $0.toDomain() }
            .sorted { $0.createdAt < $1.createdAt }
        next.schedules = try fetchAll(SDSchedule.self).map { $0.toDomain() }
        next.doseLogs = try fetchAll(SDDoseLog.self).map { $0.toDomain() }
        next.remarks = try fetchAll(SDRemark.self).map { $0.toDomain() }
        next.symptomScores = try fetchAll(SDSymptomScore.self).map { $0.toDomain() }
        next.periods = try fetchAll(SDPeriod.self).map { $0.toDomain() }
            .sorted { $0.startDate > $1.startDate }
        var settingsDesc = FetchDescriptor<SDCycleSettings>()
        settingsDesc.fetchLimit = 1
        if let row = try context.fetch(settingsDesc).first {
            next.settings = row.toDomain()
        } else {
            next.settings = .default
        }
        next.medicationChanges = try fetchAll(SDMedicationChange.self).map { $0.toDomain() }
            .sorted { $0.loggedAt < $1.loggedAt }
        return next
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            lastError = .saveFailed
            throw PersistenceError.saveFailed
        }
        lastError = nil
        refresh()
    }

    private func ensureSettings() {
        do {
            var descriptor = FetchDescriptor<SDCycleSettings>()
            descriptor.fetchLimit = 1
            if try context.fetch(descriptor).isEmpty {
                let row = SDCycleSettings()
                row.apply(.default)
                context.insert(row)
                try save()
            }
        } catch {
            if lastError == nil {
                lastError = (error as? PersistenceError) ?? .saveFailed
            }
        }
    }

    private func startObservingRemoteChanges() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            .NSPersistentStoreRemoteChange,
            NSPersistentCloudKitContainer.eventChangedNotification,
        ]
        for name in names {
            let token = center.addObserver(forName: name, object: nil, queue: nil) { [weak self] note in
                Task { @MainActor in
                    self?.handleRemoteStoreEvent(name: name, note: note)
                }
            }
            observerTokens.append(token)
        }
    }

    private func handleRemoteStoreEvent(name: Notification.Name, note: Notification) {
        if name == NSPersistentCloudKitContainer.eventChangedNotification {
            guard
                let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                event.succeeded,
                event.type == .import || event.type == .setup
            else { return }
        }
        scheduleRemoteRefresh()
    }

    private func scheduleRemoteRefresh() {
        remoteRefreshTask?.cancel()
        remoteRefreshTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            refresh()
        }
    }

    private func fetchAll<T: PersistentModel>(_: T.Type) throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    private func fetchWhere<T: PersistentModel>(_: T.Type, _ predicate: Predicate<T>) throws -> [T] {
        try context.fetch(FetchDescriptor<T>(predicate: predicate))
    }

    private func fetchOne<T: PersistentModel>(_: T.Type, _ predicate: Predicate<T>) throws -> T? {
        var descriptor = FetchDescriptor<T>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func commitWrite(_ work: () throws -> Void) throws {
        do {
            try work()
            try save()
        } catch let error as PersistenceError {
            throw error
        } catch {
            context.rollback()
            lastError = .fetchFailed
            throw PersistenceError.fetchFailed
        }
    }

    func upsertMedication(_ med: Medication) throws {
        try commitWrite {
            let id = med.id
            let row = try fetchOne(SDMedication.self, #Predicate { $0.id == id }) ?? {
                let created = SDMedication()
                context.insert(created)
                return created
            }()
            row.apply(med)
        }
    }

    func deleteMedication(id: String) throws {
        try commitWrite {
            let medId = id
            let optionalMedId: String? = medId
            for row in try fetchWhere(SDMedication.self, #Predicate { $0.id == medId }) {
                context.delete(row)
            }
            for row in try fetchWhere(SDSchedule.self, #Predicate { $0.medicationId == medId }) {
                context.delete(row)
            }
            for row in try fetchWhere(SDDoseLog.self, #Predicate { $0.medicationId == medId }) {
                context.delete(row)
            }
            for row in try fetchWhere(SDRemark.self, #Predicate { $0.medicationId == optionalMedId }) {
                row.medicationId = nil
            }
            // Keep SDMedicationChange rows: name snapshot is Effect context after the med is gone.
        }
    }

    func upsertSchedule(_ schedule: Schedule) throws {
        try commitWrite {
            let id = schedule.id
            let row = try fetchOne(SDSchedule.self, #Predicate { $0.id == id }) ?? {
                let created = SDSchedule()
                context.insert(created)
                return created
            }()
            row.apply(schedule)
        }
    }

    func setDoseStatus(
        medicationId: String,
        scheduleId: String,
        date: String,
        timeOfDay: String,
        status: DoseStatus,
        existingLogId: String?
    ) throws {
        try commitWrite {
            let plannedFor = ScheduleLogic.plannedForIso(dateKey: date, timeOfDay: timeOfDay)
            let id = existingLogId ?? createId()
            let row = try fetchOne(SDDoseLog.self, #Predicate { $0.id == id }) ?? {
                let created = SDDoseLog()
                context.insert(created)
                return created
            }()
            let log = DoseLog(
                id: id,
                medicationId: medicationId,
                scheduleId: scheduleId,
                plannedFor: plannedFor,
                status: status,
                confirmedAt: status == .pending ? nil : ISO8601DateFormatter().string(from: Date())
            )
            row.apply(log)
        }
    }

    func addRemark(_ remark: Remark) throws {
        try commitWrite {
            let row = SDRemark()
            row.apply(remark)
            context.insert(row)
        }
    }

    func updateRemark(id: String, kind: RemarkKind?, body: String?) throws {
        try commitWrite {
            let rowId = id
            guard let row = try fetchOne(SDRemark.self, #Predicate { $0.id == rowId }) else { return }
            if let kind { row.kindRaw = kind.rawValue }
            if let body { row.body = body.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
    }

    func deleteRemark(id: String) throws {
        try commitWrite {
            let rowId = id
            for row in try fetchWhere(SDRemark.self, #Predicate { $0.id == rowId }) {
                context.delete(row)
            }
        }
    }

    func replaceDayScores(date: String, scores: [SymptomScore], note: String?, noteId: String?) throws {
        try commitWrite {
            let day = date
            for row in try fetchWhere(SDSymptomScore.self, #Predicate { $0.date == day }) {
                context.delete(row)
            }
            let loggedAt = ISO8601DateFormatter().string(from: Date())
            let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
            let dayNote = (trimmed?.isEmpty == false) ? trimmed : nil
            for raw in scores {
                var score = SymptomLog.normalized(raw)
                score.date = date
                if score.loggedAt.isEmpty { score.loggedAt = loggedAt }
                score.note = dayNote
                let row = SDSymptomScore()
                row.recordId = score.rowId
                row.apply(score)
                context.insert(row)
            }
            let noteKind = RemarkKind.note.rawValue
            let dayRemarks = try fetchWhere(
                SDRemark.self,
                #Predicate { $0.kindRaw == noteKind && $0.occurredOn == day }
            )
            if let dayNote {
                if let id = noteId {
                    let rowId = id
                    if let existing = try fetchOne(SDRemark.self, #Predicate { $0.id == rowId }) {
                        existing.body = dayNote
                        existing.kindRaw = noteKind
                    } else if let existing = dayRemarks.first {
                        existing.body = dayNote
                    } else {
                        insertDayNote(date: date, body: dayNote, loggedAt: loggedAt)
                    }
                } else if let existing = dayRemarks.first {
                    existing.body = dayNote
                } else {
                    insertDayNote(date: date, body: dayNote, loggedAt: loggedAt)
                }
            } else if let id = noteId {
                let rowId = id
                for row in try fetchWhere(SDRemark.self, #Predicate { $0.id == rowId }) {
                    context.delete(row)
                }
            }
        }
    }

    private func insertDayNote(date: String, body: String, loggedAt: String) {
        let remark = SDRemark()
        remark.apply(
            Remark(
                id: createId(),
                occurredOn: date,
                kind: .note,
                body: body,
                createdAt: loggedAt
            )
        )
        context.insert(remark)
    }

    func deleteDayScore(date: String, symptomId: String) throws {
        try commitWrite {
            let day = date
            let symptom = symptomId
            for row in try fetchWhere(
                SDSymptomScore.self,
                #Predicate { $0.date == day && $0.symptomId == symptom }
            ) {
                context.delete(row)
            }
        }
    }

    func saveSettings(_ next: CycleSettings) throws {
        try commitWrite {
            var descriptor = FetchDescriptor<SDCycleSettings>()
            descriptor.fetchLimit = 1
            let row = try context.fetch(descriptor).first ?? {
                let created = SDCycleSettings()
                context.insert(created)
                return created
            }()
            row.apply(next)
        }
    }

    func upsertPeriod(_ period: Period) throws {
        try commitWrite {
            let id = period.id
            let row = try fetchOne(SDPeriod.self, #Predicate { $0.id == id }) ?? {
                let created = SDPeriod()
                context.insert(created)
                return created
            }()
            row.apply(period)
        }
    }

    func appendMedicationChanges(_ changes: [MedicationChange]) throws {
        guard !changes.isEmpty else { return }
        try commitWrite {
            for item in changes {
                let row = SDMedicationChange()
                row.apply(item)
                context.insert(row)
            }
        }
    }

    func deletePeriod(id: String) throws {
        try commitWrite {
            let rowId = id
            for row in try fetchWhere(SDPeriod.self, #Predicate { $0.id == rowId }) {
                context.delete(row)
            }
        }
    }

    func replaceAll(with payload: ExportPayload) throws {
        guard payload.version == 1 else { throw BackupError.unsupportedVersion(payload.version) }
        do {
            try wipeDomain(restoreDefaultSettings: false)
            for item in payload.medications {
                let row = SDMedication(); row.apply(item); context.insert(row)
            }
            for item in payload.schedules {
                let row = SDSchedule(); row.apply(item); context.insert(row)
            }
            for item in payload.doseLogs {
                let row = SDDoseLog(); row.apply(item); context.insert(row)
            }
            for item in payload.remarks {
                let row = SDRemark(); row.apply(item); context.insert(row)
            }
            for item in payload.symptomScores {
                let row = SDSymptomScore()
                row.recordId = item.rowId
                row.apply(SymptomLog.normalized(item))
                context.insert(row)
            }
            for item in payload.periods {
                let row = SDPeriod(); row.apply(item); context.insert(row)
            }
            for item in payload.medicationChanges {
                let row = SDMedicationChange(); row.apply(item); context.insert(row)
            }
            let settingsRow = SDCycleSettings()
            settingsRow.apply(payload.cycleSettings)
            context.insert(settingsRow)
            try context.save()
        } catch let error as BackupError {
            throw error
        } catch {
            context.rollback()
            lastError = .saveFailed
            throw PersistenceError.saveFailed
        }
        lastError = nil
        refresh()
    }

    func exportPayload() -> ExportPayload {
        BackupCodec.makeExport(
            medications: medications,
            schedules: schedules,
            doseLogs: doseLogs,
            remarks: remarks,
            cycleSettings: settings,
            periods: periods,
            symptomScores: symptomScores,
            medicationChanges: medicationChanges
        )
    }

    func loadSample() throws {
        let now = DateKeys.parseDateKey(DateKeys.todayKey()) ?? Date()
        try replaceAll(with: SampleData.payload(now: now))
    }

    func clearAll() throws {
        try commitWrite {
            try wipeDomain(restoreDefaultSettings: true)
        }
    }

    private func wipeDomain(restoreDefaultSettings: Bool) throws {
        let medications = try fetchAll(SDMedication.self)
        let schedules = try fetchAll(SDSchedule.self)
        let doseLogs = try fetchAll(SDDoseLog.self)
        let remarks = try fetchAll(SDRemark.self)
        let scores = try fetchAll(SDSymptomScore.self)
        let periods = try fetchAll(SDPeriod.self)
        let changes = try fetchAll(SDMedicationChange.self)
        let settingsRows = try fetchAll(SDCycleSettings.self)
        medications.forEach { context.delete($0) }
        schedules.forEach { context.delete($0) }
        doseLogs.forEach { context.delete($0) }
        remarks.forEach { context.delete($0) }
        scores.forEach { context.delete($0) }
        periods.forEach { context.delete($0) }
        changes.forEach { context.delete($0) }
        settingsRows.forEach { context.delete($0) }
        if restoreDefaultSettings {
            let row = SDCycleSettings()
            row.apply(.default)
            context.insert(row)
        }
    }
}
