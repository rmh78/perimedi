import Foundation
import SwiftUI

extension View {
    @ViewBuilder
    func a11y(_ id: String?) -> some View {
        if let id, !id.isEmpty {
            accessibilityIdentifier(id)
        } else {
            self
        }
    }
}

/// Language-independent accessibility identifiers. UI tests use the same string literals.
enum A11yID {
    static let tabCycle = "tab.cycle"
    static let tabMonth = "tab.month"
    static let tabMore = "tab.more"

    static let pagerPrev = "cycle.pager.prev"
    static let pagerNext = "cycle.pager.next"
    static let pagerToday = "cycle.pager.today"
    static let pagerLabel = "cycle.pager.label"

    static let actionMed = "cycle.action.med"
    static let actionPeriod = "cycle.action.period"
    static let actionSymptom = "cycle.action.symptom"

    static let emptyMeds = "cycle.empty.meds"
    static let intro = "cycle.intro"
    static let chipPeriod = "cycle.chip.period"

    static let sheetMed = "sheet.med"
    static let sheetPeriod = "sheet.period"
    static let sheetSymptom = "sheet.symptom"
    static let sheetClose = "sheet.close"

    static let medName = "med.name"
    static let medForm = "med.form"
    static let medDose = "med.dose"
    static let medModeEveryday = "med.mode.everyday"
    static let medModeCyclic = "med.mode.cyclic"
    static let medPreset = "med.preset"
    static let medStart = "med.start"
    static let medSave = "med.save"
    static let medDelete = "med.delete"

    static let periodAdd = "period.add"
    static let periodStart = "period.start"
    static let periodEnd = "period.end"
    static let periodSave = "period.save"

    static let symptomBody = "symptom.body"
    static let symptomSave = "symptom.save"
    static let confirmDelete = "confirm.delete"

    static func slug(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split { $0.isWhitespace || $0 == "_" }
            .joined(separator: "-")
    }

    static func lane(_ name: String) -> String { "cycle.lane.\(slug(name))" }
    static func laneStatus(_ name: String) -> String { "cycle.lane.\(slug(name)).status" }
    static func laneEdit(_ name: String) -> String { "cycle.lane.\(slug(name)).edit" }
    static func stripDay(_ dateKey: String) -> String { "cycle.strip.day.\(dateKey)" }
    static func monthDay(_ dateKey: String) -> String { "month.day.\(dateKey)" }
}
