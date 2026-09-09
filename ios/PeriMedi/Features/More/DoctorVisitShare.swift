import Foundation
import PDFKit
import SwiftUI
import UIKit
import PeriMediDomain

@MainActor
enum DoctorVisitShare {
    static func file(store: Store, app: AppModel) throws -> URL {
        let report = DoctorVisitLogic.report(
            today: DateKeys.todayKey(),
            medications: store.medications,
            schedules: store.schedules,
            doseLogs: store.doseLogs,
            periods: store.periods,
            settings: store.settings,
            scores: store.symptomScores,
            changes: store.medicationChanges
        )
        let page = makePage(report, app: app)
        let data = DoctorVisitPDF.data(page: page)
        guard !data.isEmpty else { throw DoctorVisitShareError.empty }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("perimedi-visit.pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func previewImage(store: Store, app: AppModel) -> UIImage? {
        guard let url = try? file(store: store, app: app),
              let data = try? Data(contentsOf: url),
              let doc = PDFDocument(data: data),
              let page = doc.page(at: 0)
        else { return nil }
        return page.thumbnail(of: CGSize(width: 612, height: 792), for: .mediaBox)
    }

    static func makePage(_ report: DoctorVisitReport, app: AppModel) -> DoctorVisitPage {
        let locale = app.locale.language.locale
        var sections: [DoctorVisitSection] = []
        if let effect = EffectCopy.sentence(report.effect, t: app.t) {
            sections.append(DoctorVisitSection(heading: app.t("visit.effect"), rows: [effect]))
        }
        sections.append(
            DoctorVisitSection(
                heading: app.t("visit.meds"),
                rows: report.medications.isEmpty
                    ? [app.t("visit.noMeds")]
                    : report.medications.map { row in
                        app.t("visit.medLine", [
                            "name": row.name,
                            "dose": row.doseLabel,
                            "taken": String(row.taken),
                            "planned": String(row.planned),
                            "percent": String(row.percent),
                        ])
                    }
            )
        )
        sections.append(
            DoctorVisitSection(
                heading: app.t("visit.changes"),
                rows: report.changes.isEmpty
                    ? [app.t("visit.noChanges")]
                    : report.changes.map { change in
                        let key = change.field == .dose ? "visit.change.dose" : "visit.change.schedule"
                        return app.t(key, [
                            "date": formatDate(change.effectiveDate, locale: locale),
                            "name": change.nameSnapshot,
                            "previous": change.previousValue,
                            "new": change.newValue,
                        ])
                    }
            )
        )
        sections.append(
            DoctorVisitSection(
                heading: app.t("visit.periods"),
                rows: report.periods.isEmpty
                    ? [app.t("visit.noPeriods")]
                    : report.periods.map { row in
                        app.t("visit.periodRow", [
                            "start": formatDate(row.start, locale: locale),
                            "end": formatDate(row.end, locale: locale),
                        ])
                    }
            )
        )
        var symptomRows: [String] = []
        if report.symptoms.isEmpty {
            symptomRows = [app.t("visit.noSymptoms")]
        } else {
            symptomRows = [app.t("visit.symptomHeader")]
            symptomRows += report.symptoms.map { row in
                app.t("visit.symptomRow", [
                    "name": app.t("symptom.id.\(row.id)"),
                    "days": String(row.dayCount),
                    "mean": String(format: "%.1f", row.meanIntensity),
                ])
            }
        }
        sections.append(DoctorVisitSection(heading: app.t("visit.symptoms"), rows: symptomRows))

        return DoctorVisitPage(
            title: app.t("visit.title"),
            meta: [
                app.t("visit.generated", ["date": formatDate(report.generatedOn, locale: locale)]),
                rangeLine(report, app: app, locale: locale),
            ],
            sections: sections,
            disclaimer: app.t("visit.disclaimer")
        )
    }

    private static func rangeLine(
        _ report: DoctorVisitReport,
        app: AppModel,
        locale: Locale
    ) -> String {
        let start = formatDate(report.rangeStart, locale: locale)
        let end = formatDate(report.rangeEnd, locale: locale)
        let key: String
        switch report.rangeKind {
        case .completedCycles(let n) where n >= 2:
            key = "visit.range.two"
        case .completedCycles:
            key = "visit.range.one"
        case .fourWeeks:
            key = "visit.range.fourWeeks"
        case .twelveWeeks:
            key = "visit.range.twelveWeeks"
        }
        return app.t(key, ["start": start, "end": end])
    }

    private static func formatDate(_ key: String, locale: Locale) -> String {
        guard let date = DateKeys.parseDateKey(key) else { return key }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("yMMMd")
        return formatter.string(from: date)
    }
}

enum DoctorVisitShareError: Error {
    case empty
}

/// Catalog-only first page of the sample visit PDF (`-catalogVisitPdf`).
struct DoctorVisitCatalogPreview: View {
    var image: UIImage

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 12)
                .padding(.top, 8)
        }
        .accessibilityIdentifier(A11yID.visitPdfPreview)
    }
}
