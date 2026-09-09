import XCTest

final class SymptomTrendsTests: PeriMediUITestCase {
    func testSymptomTrendsEmpty() {
        robot.launch()
        robot.waitFor(id: "tab.trends")
        robot.tap("tab.trends")
        robot.waitFor(id: "trends.screen")
        robot.waitFor(id: "trends.status")
        XCTAssertEqual(robot.value(of: "trends.status"), "need-cycles")
        robot.waitFor(id: "trends.empty")
        XCTAssertEqual(robot.value(of: "trends.empty"), "need-cycles")
        XCTAssertFalse(robot.exists("trends.series.hot_flash"))
        XCTAssertFalse(robot.exists("trends.intro"))
        XCTAssertFalse(robot.exists("trends.change"))
    }

    func testSymptomTrendsNoScores() {
        robot.launch(extra: ["-fixture=trends-noscores", "-tabTrends"])
        robot.waitFor(id: "trends.screen")
        XCTAssertEqual(robot.value(of: "trends.status"), "no-scores")
        XCTAssertEqual(robot.value(of: "trends.empty"), "no-scores")
        XCTAssertFalse(robot.exists("trends.series.hot_flash"))
        XCTAssertFalse(robot.exists("trends.intro"))
        XCTAssertFalse(robot.exists("trends.change"))
    }

    func testSymptomTrendsChart() {
        robot.launch(extra: ["-fixture=trends", "-tabTrends"])

        XCTContext.runActivity(named: "default three series") { _ in
            robot.waitFor(id: "trends.screen")
            robot.waitFor(id: "trends.plot")
            robot.waitFor(id: "trends.axis")
            XCTAssertEqual(robot.value(of: "trends.axis"), "days-scored")
            robot.waitFor(id: "trends.sizeKey")
            robot.waitFor(id: "trends.change")
            robot.waitFor(id: "trends.status")
            XCTAssertEqual(robot.value(of: "trends.status"), "ids:hot_flash,sleep,mood")
            XCTAssertFalse(robot.exists("trends.intro"))
            XCTAssertFalse(robot.exists("trends.group.body"))
            robot.waitFor(id: "trends.series.hot_flash")
            robot.waitFor(id: "trends.series.mood")
            robot.waitFor(id: "trends.series.sleep")
            XCTAssertEqual(robot.value(of: "trends.series.hot_flash"), "on")
            XCTAssertEqual(robot.value(of: "trends.series.sleep"), "on")
            XCTAssertEqual(robot.value(of: "trends.series.mood"), "on")
            XCTAssertFalse(robot.exists("trends.series.anxiety"))
        }

        XCTContext.runActivity(named: "Y is days scored, size is mean") { _ in
            robot.waitFor(id: "trends.dot.hot_flash.2026-01-04")
            let mild = robot.value(of: "trends.dot.hot_flash.2026-01-04")
            XCTAssertTrue(mild.contains("count:8"), mild)
            XCTAssertTrue(mild.contains("mean:1"), mild)
            XCTAssertFalse(mild.contains("count:99"), mild)
            let severe = robot.value(of: "trends.dot.hot_flash.2026-02-01")
            XCTAssertTrue(severe.contains("count:2"), severe)
            XCTAssertTrue(severe.contains("mean:4"), severe)
        }

        XCTContext.runActivity(named: "gap is not a zero") { _ in
            XCTAssertFalse(robot.exists("trends.dot.sleep.2026-01-04"))
            robot.waitFor(id: "trends.dot.sleep.2026-02-01")
            let sleep = robot.value(of: "trends.dot.sleep.2026-02-01")
            XCTAssertTrue(sleep.contains("count:4"), sleep)
            XCTAssertFalse(sleep.contains("count:0"), sleep)
        }

        XCTContext.runActivity(named: "tap shows numbers") { _ in
            robot.tap("trends.dot.hot_flash.2026-01-04")
            robot.waitFor(id: "trends.detail")
            let detail = robot.value(of: "trends.detail")
            XCTAssertTrue(detail.contains("id:hot_flash"), detail)
            XCTAssertTrue(detail.contains("cycle:2026-01-04"), detail)
            XCTAssertTrue(detail.contains("count:8"), detail)
            XCTAssertTrue(detail.contains("mean:1"), detail)
        }

        XCTContext.runActivity(named: "dose-change tick") { _ in
            robot.waitFor(id: "trends.tick.2026-02-01")
            let tick = robot.value(of: "trends.tick.2026-02-01")
            XCTAssertTrue(tick.contains("Estrogel"), tick)
            XCTAssertTrue(tick.contains("2 pumps"), tick)
            robot.tap("trends.tick.2026-02-01")
            robot.waitFor(id: "trends.tickCopy")
        }

        XCTContext.runActivity(named: "select replaces a series") { _ in
            robot.tap("trends.change")
            robot.waitFor(id: "sheet.trends")
            robot.waitFor(id: "trends.group.body")
            robot.waitFor(id: "trends.group.mood")
            robot.waitFor(id: "trends.group.urogenital")
            robot.waitFor(id: "trends.series.anxiety")
            XCTAssertEqual(robot.value(of: "trends.series.anxiety"), "off")
            robot.tap("trends.series.anxiety")
            XCTAssertEqual(robot.value(of: "trends.status"), "ids:hot_flash,mood,anxiety")
            XCTAssertEqual(robot.value(of: "trends.series.anxiety"), "on")
            XCTAssertEqual(robot.value(of: "trends.series.sleep"), "off")
            robot.tap("trends.done")
            robot.waitGone(id: "sheet.trends")
            robot.waitFor(id: "trends.series.anxiety")
            XCTAssertFalse(robot.exists("trends.series.sleep"))
        }
    }
}
