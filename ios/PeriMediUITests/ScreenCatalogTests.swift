import XCTest

struct ScreenCatalogWriter {
    let robot: AppRobot

    func writeEnglish() throws {
        try captureEmpty()
        try captureSample()
        try captureTrendsFixture()
        try captureTrendsNoScores()

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

    private func captureEmpty() throws {
        robot.launchCatalog(.empty)
        robot.tap("tab.cycle")
        robot.waitFor(id: "cycle.intro")
        try write("cycle-empty-en")

        robot.tap("tab.trends")
        robot.waitFor(id: "trends.empty")
        try write("trends-empty-en")

        robot.tap("tab.cycle")
        robot.tap("cycle.action.med")
        robot.waitFor(id: "sheet.med")
        robot.clearAndType("med.dose", "1 mg")
        robot.waitFor(id: "med.since")
        try write("sheet-med-en")
        robot.closeSheet(id: "sheet.med")

        robot.tap("cycle.action.period")
        robot.waitFor(id: "sheet.period")
        try write("sheet-period-en")
        robot.closeSheet(id: "sheet.period")

        robot.tap("cycle.action.symptom")
        robot.waitFor(id: "sheet.symptom")
        try write("sheet-symptom-en")
        robot.closeSheet(id: "sheet.symptom")
    }

    private func captureSample() throws {
        robot.launchCatalog(.sample)
        robot.tap("tab.cycle")
        robot.waitFor(id: "cycle.effect")
        try write("cycle-sample-en")

        robot.tap("tab.trends")
        robot.waitFor(id: "trends.plot")
        try write("trends-sample-en")
        robot.waitFor(id: "trends.change")
        robot.tap("trends.change")
        robot.waitFor(id: "sheet.trends")
        try write("trends-sheet-en")
        robot.closeSheet(id: "sheet.trends")

        robot.tap("tab.month")
        robot.waitFor(id: "month.day.\(UITestDate.today)")
        try write("month-sample-en")

        robot.tap("tab.more")
        robot.scrollTo("more.sharePdf")
        robot.waitFor(id: "more.sharePdf")
        try write("more-sample-en")
        robot.tap("more.sharePdf")
        robot.waitFor(id: "visit.range")
        robot.waitFor(id: "visit.range.cycle.2026-02-02")
        robot.waitFor(id: "visit.range.previous")
        try write("visit-range-sample-en")
        robot.waitFor(id: "visit.range.continue")
        robot.tap("visit.range.continue")
        robot.waitFor(id: "visit.pdf.preview")
        robot.waitFor(id: "visit.pdf.share")
        try write("visit-pdf-sample-en")
        robot.tap("sheet.close")
        robot.waitGone(id: "visit.pdf.preview")
    }

    private func captureTrendsFixture() throws {
        robot.launchCatalog(.trendsChart)
        robot.waitFor(id: "trends.tick.2026-02-01")
        robot.tap("trends.tick.2026-02-01")
        robot.waitFor(id: "trends.tickCopy")
        try write("trends-tick-en")
        robot.waitFor(id: "trends.dot.hot_flash.2026-03-01")
        robot.tap("trends.dot.hot_flash.2026-03-01")
        robot.waitFor(id: "trends.detail")
        try write("trends-tap-en")
    }

    private func captureTrendsNoScores() throws {
        robot.launchCatalog(.trendsNoScores)
        robot.waitFor(id: "trends.empty")
        try write("trends-noscores-en")
    }

    private func write(_ name: String) throws {
        try ScreenCatalog.write(name)
    }
}

final class ScreenCatalogTests: PeriMediUITestCase {
    func testWriteScreenCatalog() throws {
        try ScreenCatalogWriter(robot: robot).writeEnglish()
    }
}
