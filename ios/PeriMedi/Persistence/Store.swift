import Foundation
import SwiftData
import PeriMediDomain

struct StoreSnapshot: Equatable {
    var medications: [Medication] = []
    var schedules: [Schedule] = []
    var doseLogs: [DoseLog] = []
    var remarks: [Remark] = []
    var periods: [Period] = []
    var settings: CycleSettings = .default
}

@MainActor
final class Store: ObservableObject {
    /// Single published bag so a refresh invalidates SwiftUI once, not six times.
    @Published private(set) var snapshot = StoreSnapshot()

    var medications: [Medication] { snapshot.medications }
    var schedules: [Schedule] { snapshot.schedules }
    var doseLogs: [DoseLog] { snapshot.doseLogs }
    var remarks: [Remark] { snapshot.remarks }
    var periods: [Period] { snapshot.periods }
    var settings: CycleSettings { snapshot.settings }

    private let context: ModelContext

    init(container: ModelContainer) {
        self.context = container.mainContext
        refresh()
        ensureSettings()
    }

    func refresh() {
        var next = StoreSnapshot()
        next.medications = (try? context.fetch(FetchDescriptor<SDMedication>()))?.map { $0.toDomain() }
            .sorted { $0.createdAt < $1.createdAt } ?? []
        next.schedules = (try? context.fetch(FetchDescriptor<SDSchedule>()))?.map { $0.toDomain() } ?? []
        next.doseLogs = (try? context.fetch(FetchDescriptor<SDDoseLog>()))?.map { $0.toDomain() } ?? []
        next.remarks = (try? context.fetch(FetchDescriptor<SDRemark>()))?.map { $0.toDomain() } ?? []
        next.periods = (try? context.fetch(FetchDescriptor<SDPeriod>()))?.map { $0.toDomain() }
            .sorted { $0.startDate > $1.startDate } ?? []
        if let row = try? context.fetch(FetchDescriptor<SDCycleSettings>()).first {
            next.settings = row.toDomain()
        } else {
            next.settings = .default
        }
        if next != snapshot {
            snapshot = next
        }
    }

    private func save() {
        try? context.save()
        refresh()
    }

    private func ensureSettings() {
        let rows = (try? context.fetch(FetchDescriptor<SDCycleSettings>())) ?? []
        if rows.isEmpty {
            let row = SDCycleSettings()
            row.apply(.default)
            context.insert(row)
            save()
        }
    }

    func upsertMedication(_ med: Medication) {
        let row = (try? context.fetch(FetchDescriptor<SDMedication>()))?.first { $0.id == med.id } ?? {
            let created = SDMedication()
            context.insert(created)
            return created
        }()
        row.apply(med)
        save()
    }

    func deleteMedication(id: String) {
        for row in (try? context.fetch(FetchDescriptor<SDMedication>())) ?? [] where row.id == id {
            context.delete(row)
        }
        for row in (try? context.fetch(FetchDescriptor<SDSchedule>())) ?? [] where row.medicationId == id {
            context.delete(row)
        }
        for row in (try? context.fetch(FetchDescriptor<SDDoseLog>())) ?? [] where row.medicationId == id {
            context.delete(row)
        }
        for row in (try? context.fetch(FetchDescriptor<SDRemark>())) ?? [] where row.medicationId == id {
            row.medicationId = nil
        }
        save()
    }

    func upsertSchedule(_ schedule: Schedule) {
        let row = (try? context.fetch(FetchDescriptor<SDSchedule>()))?.first { $0.id == schedule.id } ?? {
            let created = SDSchedule()
            context.insert(created)
            return created
        }()
        row.apply(schedule)
        save()
    }

    func setDoseStatus(
        medicationId: String,
        scheduleId: String,
        date: String,
        timeOfDay: String,
        status: DoseStatus,
        existingLogId: String?
    ) {
        let plannedFor = ScheduleLogic.plannedForIso(dateKey: date, timeOfDay: timeOfDay)
        let id = existingLogId ?? createId()
        let row = (try? context.fetch(FetchDescriptor<SDDoseLog>()))?.first { $0.id == id } ?? {
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
        try? context.save()
        var next = snapshot
        if let idx = next.doseLogs.firstIndex(where: { $0.id == id }) {
            next.doseLogs[idx] = log
        } else {
            next.doseLogs.append(log)
        }
        snapshot = next
    }

    func addRemark(_ remark: Remark) {
        let row = SDRemark()
        row.apply(remark)
        context.insert(row)
        save()
    }

    func updateRemark(id: String, kind: RemarkKind?, body: String?) {
        guard let row = (try? context.fetch(FetchDescriptor<SDRemark>()))?.first(where: { $0.id == id }) else { return }
        if let kind { row.kindRaw = kind.rawValue }
        if let body { row.body = body.trimmingCharacters(in: .whitespacesAndNewlines) }
        save()
    }

    func deleteRemark(id: String) {
        for row in (try? context.fetch(FetchDescriptor<SDRemark>())) ?? [] where row.id == id {
            context.delete(row)
        }
        save()
    }

    func saveSettings(_ next: CycleSettings) {
        let row = (try? context.fetch(FetchDescriptor<SDCycleSettings>()))?.first ?? {
            let created = SDCycleSettings()
            context.insert(created)
            return created
        }()
        row.apply(next)
        save()
    }

    func upsertPeriod(_ period: Period) {
        let row = (try? context.fetch(FetchDescriptor<SDPeriod>()))?.first { $0.id == period.id } ?? {
            let created = SDPeriod()
            context.insert(created)
            return created
        }()
        row.apply(period)
        save()
    }

    func deletePeriod(id: String) {
        for row in (try? context.fetch(FetchDescriptor<SDPeriod>())) ?? [] where row.id == id {
            context.delete(row)
        }
        save()
    }

    func replaceAll(with payload: ExportPayload) throws {
        guard payload.version == 1 else { throw BackupError.unsupportedVersion(payload.version) }
        wipeDomain(restoreDefaultSettings: false)
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
        for item in payload.periods {
            let row = SDPeriod(); row.apply(item); context.insert(row)
        }
        let settingsRow = SDCycleSettings()
        settingsRow.apply(payload.cycleSettings)
        context.insert(settingsRow)
        save()
    }

    func exportPayload() -> ExportPayload {
        BackupCodec.makeExport(
            medications: medications,
            schedules: schedules,
            doseLogs: doseLogs,
            remarks: remarks,
            cycleSettings: settings,
            periods: periods
        )
    }

    func loadSample() throws {
        try replaceAll(with: SampleData.payload())
    }

    func clearAll() {
        wipeDomain(restoreDefaultSettings: true)
        save()
    }

    private func wipeDomain(restoreDefaultSettings: Bool) {
        ((try? context.fetch(FetchDescriptor<SDMedication>())) ?? []).forEach { context.delete($0) }
        ((try? context.fetch(FetchDescriptor<SDSchedule>())) ?? []).forEach { context.delete($0) }
        ((try? context.fetch(FetchDescriptor<SDDoseLog>())) ?? []).forEach { context.delete($0) }
        ((try? context.fetch(FetchDescriptor<SDRemark>())) ?? []).forEach { context.delete($0) }
        ((try? context.fetch(FetchDescriptor<SDPeriod>())) ?? []).forEach { context.delete($0) }
        ((try? context.fetch(FetchDescriptor<SDCycleSettings>())) ?? []).forEach { context.delete($0) }
        if restoreDefaultSettings {
            let row = SDCycleSettings()
            row.apply(.default)
            context.insert(row)
        }
    }
}
