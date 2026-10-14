import XCTest

struct ScreenCatalogWriter {
    let robot: AppRobot

    func writeEnglish() throws {
        try captureEmpty()
        try captureSample()
        try captureTrendsFixture()
        try captureTrendsNoScores()
        try captureGermanNewSymptomPill()

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
        try captureWrappedCustomName()
        robot.closeSheet(id: "sheet.symptom")
    }

    private func captureWrappedCustomName() throws {
        let longName = "Night sweats that return after waking up"
        XCTAssertEqual(longName.count, 40)
        robot.scrollTo("symptom.custom.create")
        robot.tap("symptom.custom.create")
        robot.clearAndType("symptom.custom.add", longName, dismiss: false)
        robot.tap("symptom.custom.create")
        let nameButton = robot.app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "symptom.custom.name.c.")
        ).firstMatch
        XCTAssertTrue(nameButton.waitForExistence(timeout: 3))
        let raw = nameButton.identifier.replacingOccurrences(of: "symptom.custom.name.", with: "")
        robot.scrollTo("symptom.score.vaginal_dryness.1")
        robot.scrollTo("symptom.score.\(raw).1")
        let catalog = robot.element("symptom.score.vaginal_dryness.1")
        let custom = robot.element("symptom.score.\(raw).1")
        XCTAssertEqual(catalog.frame.minX, custom.frame.minX, accuracy: 1)
        XCTAssertGreaterThan(nameButton.frame.height, 28, "40-character name stayed on one line")
        try write("sheet-symptom-wrap-en")
    }

    private func captureGermanNewSymptomPill() throws {
        robot.launchCatalog(.empty)
        robot.tap("tab.more")
        robot.waitFor(id: "more.lang.de")
        robot.tap("more.lang.de")
        robot.tap("tab.cycle")
        robot.tap("cycle.action.symptom")
        robot.waitFor(id: "sheet.symptom")
        robot.scrollTo("symptom.custom.create")
        let label = robot.element("symptom.custom.create").label
        try write("sheet-symptom-pill-de")
        robot.closeSheet(id: "sheet.symptom")
        robot.tap("tab.more")
        robot.tap("more.lang.en")
        XCTAssertEqual(label, "Neues Symptom")
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

    override func tearDown() {
        super.tearDown()
        guard robot.app.state == .runningForeground else { return }
        if robot.exists("sheet.close") {
            robot.element("sheet.close").tap()
        }
        guard robot.exists("tab.more"), robot.element("tab.more").label == "Mehr" else { return }
        robot.element("tab.more").tap()
        if robot.exists("more.lang.en") {
            robot.element("more.lang.en").tap()
        }
    }
}
