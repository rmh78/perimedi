import Foundation
import SwiftData

enum PersistenceController {
    static let cloudContainer = "iCloud.app.perimedi.ios"

    static let schema = Schema([
        SDMedication.self,
        SDSchedule.self,
        SDDoseLog.self,
        SDRemark.self,
        SDSymptomScore.self,
        SDPeriod.self,
        SDCycleSettings.self,
    ])

    /// Local SwiftData always works. CloudKit is only enabled when the process
    /// is actually entitled for the PeriMedi iCloud container. A signed Personal
    /// Team build has a provisioning profile but no iCloud capability — do not
    /// treat that as CloudKit or SwiftData will fail at launch.
    static func makeContainer() -> ModelContainer {
        if hasCloudKitEntitlement() {
            do {
                let cloud = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .private(cloudContainer)
                )
                return try ModelContainer(for: schema, configurations: [cloud])
            } catch {
                // fall through to local
            }
        }
        do {
            let local = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [local])
        } catch {
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [memory])
        }
    }

    private static func hasCloudKitEntitlement() -> Bool {
        guard
            let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
            let data = try? Data(contentsOf: url),
            let raw = String(data: data, encoding: .isoLatin1)
        else { return false }
        return raw.contains(cloudContainer)
    }
}
