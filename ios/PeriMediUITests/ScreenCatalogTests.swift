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
            robot.waitFor(id: "more.lang.en")
        }
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
            robot.waitFor(id: "more.lang.en")
        }

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
