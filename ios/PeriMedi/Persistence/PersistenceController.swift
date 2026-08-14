import Foundation
import SwiftData

enum PersistenceController {
    static let cloudContainer = "iCloud.app.perimedi.ios"

    static let schema = Schema([
        SDMedication.self,
        SDSchedule.self,
        SDDoseLog.self,
        SDRemark.self,
        SDPeriod.self,
        SDCycleSettings.self,
    ])

    /// Local SwiftData always works. CloudKit is only enabled when the process
    /// is signed with a CloudKit entitlement — unsigned Simulator builds
    /// SIGTRAP inside CloudKit setup if we request a private database.
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
        Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") != nil
    }
}
