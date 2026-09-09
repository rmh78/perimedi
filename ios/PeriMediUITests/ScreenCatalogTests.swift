import XCTest

final class ScreenCatalogTests: PeriMediUITestCase {
    func testWriteScreenCatalog() throws {
        try shot("cycle-empty-en", locale: "en") {
            robot.waitFor(id: "cycle.intro")
        }
        try shot("trends-empty-en", locale: "en", extra: ["-tabTrends"]) {
            robot.waitFor(id: "trends.empty")
        }
        try shot("cycle-sample-en", locale: "en", extra: ["-loadSample"]) {
            robot.waitFor(id: "cycle.effect")
        }
        try shot("trends-sample-en", locale: "en", extra: ["-loadSample", "-tabTrends"]) {
            robot.waitFor(id: "trends.plot")
        }
        try shot("month-sample-en", locale: "en", extra: ["-loadSample", "-tabMonth"]) {
            robot.waitFor(id: "month.day.\(UITestDate.today)")
        }
        try shot("more-sample-en", locale: "en", extra: ["-loadSample", "-tabMore"]) {
            robot.scrollTo("more.sharePdf")
            robot.waitFor(id: "more.sharePdf")
        }
        try shot("visit-range-sample-en", locale: "en", extra: ["-loadSample", "-tabMore"]) {
            robot.scrollTo("more.sharePdf")
            robot.tap("more.sharePdf")
            robot.waitFor(id: "visit.range")
            robot.waitFor(id: "visit.range.cycle.2026-02-02")
            robot.waitFor(id: "visit.range.previous")
        }
        try shot("visit-pdf-sample-en", locale: "en", extra: ["-loadSample", "-tabMore"]) {
            robot.scrollTo("more.sharePdf")
            robot.tap("more.sharePdf")
            robot.waitFor(id: "visit.range.continue")
            robot.tap("visit.range.continue")
            robot.waitFor(id: "visit.pdf.preview")
            robot.waitFor(id: "visit.pdf.share")
        }
        try dialogShots(locale: "en")
        try trendsExtras(locale: "en")
        try shot("cycle-empty-de", locale: "de") {
            robot.waitFor(id: "cycle.intro")
        }
        try shot("trends-empty-de", locale: "de", extra: ["-tabTrends"]) {
            robot.waitFor(id: "trends.empty")
        }
        try shot("cycle-sample-de", locale: "de", extra: ["-loadSample"]) {
            robot.waitFor(id: "cycle.effect")
        }
        try shot("trends-sample-de", locale: "de", extra: ["-loadSample", "-tabTrends"]) {
            robot.waitFor(id: "trends.plot")
        }
        try shot("month-sample-de", locale: "de", extra: ["-loadSample", "-tabMonth"]) {
            robot.waitFor(id: "month.day.\(UITestDate.today)")
        }
        try shot("more-sample-de", locale: "de", extra: ["-loadSample", "-tabMore"]) {
            robot.scrollTo("more.sharePdf")
            robot.waitFor(id: "more.sharePdf")
        }
        try shot("visit-range-sample-de", locale: "de", extra: ["-loadSample", "-tabMore"]) {
            robot.scrollTo("more.sharePdf")
            robot.tap("more.sharePdf")
            robot.waitFor(id: "visit.range")
            robot.waitFor(id: "visit.range.cycle.2026-02-02")
            robot.waitFor(id: "visit.range.previous")
        }
        try shot("visit-pdf-sample-de", locale: "de", extra: ["-loadSample", "-tabMore"]) {
            robot.scrollTo("more.sharePdf")
            robot.tap("more.sharePdf")
            robot.waitFor(id: "visit.range.continue")
            robot.tap("visit.range.continue")
            robot.waitFor(id: "visit.pdf.preview")
            robot.waitFor(id: "visit.pdf.share")
        }
        try dialogShots(locale: "de")
        try trendsExtras(locale: "de")

        let expected = ScreenCatalog.expectedNames
        XCTAssertFalse(expected.isEmpty, "ios/docs/screens/expected.txt")
        for name in expected {
            let url = ScreenCatalog.directory.appendingPathComponent(name)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: url.path),
                "missing catalog \(name) — UI tests should have written it"
            )
        }
    }

    private func dialogShots(locale: String) throws {
        try shot("sheet-med-\(locale)", locale: locale, extra: ["-sheetMed"]) {
            robot.waitFor(id: "sheet.med")
            robot.clearAndType("med.dose", "1 mg")
            robot.waitFor(id: "med.since")
        }
        try shot("sheet-period-\(locale)", locale: locale, extra: ["-sheetPeriod"]) {
            robot.waitFor(id: "sheet.period")
        }
        try shot("sheet-symptom-\(locale)", locale: locale, extra: ["-sheetSymptom"]) {
            robot.waitFor(id: "sheet.symptom")
        }
    }

    private func trendsExtras(locale: String) throws {
        try shot("trends-sheet-\(locale)", locale: locale, extra: ["-loadSample", "-tabTrends"]) {
            robot.waitFor(id: "trends.change")
            robot.tap("trends.change")
            robot.waitFor(id: "sheet.trends")
        }
        try shot(
            "trends-tap-\(locale)",
            locale: locale,
            extra: ["-fixture=trends", "-tabTrends", "-trendsTap"]
        ) {
            robot.waitFor(id: "trends.detail")
        }
        try shot("trends-tick-\(locale)", locale: locale, extra: ["-fixture=trends", "-tabTrends"]) {
            robot.waitFor(id: "trends.tick.2026-02-01")
            robot.tap("trends.tick.2026-02-01")
            robot.waitFor(id: "trends.tickCopy")
        }
        try shot(
            "trends-noscores-\(locale)",
            locale: locale,
            extra: ["-fixture=trends-noscores", "-tabTrends"]
        ) {
            robot.waitFor(id: "trends.empty")
        }
    }

    private func shot(
        _ name: String,
        locale: String,
        extra: [String] = [],
        ready: () -> Void
    ) throws {
        robot.launchCatalog(locale: locale, extra: extra)
        ready()
        try ScreenCatalog.write(name)
    }
}
