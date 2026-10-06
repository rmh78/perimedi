import XCTest

final class SymptomTrendsTests: PeriMediUITestCase {
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
            robot.waitFor(id: "trends.tick.2026-03-01")
            XCTAssertTrue(robot.value(of: "trends.tick.2026-03-01").contains("2.5 pumps"))
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
            robot.tap("sheet.close")
            robot.waitGone(id: "sheet.trends")
            robot.waitFor(id: "trends.series.anxiety")
            XCTAssertFalse(robot.exists("trends.series.sleep"))
        }
    }

    func testCustomSymptomCreateScoreRenameChartAndDelete() {
        robot.launch(extra: ["-fixture=trends"])
        robot.tap("cycle.action.symptom")
        robot.waitFor(id: "sheet.symptom")
        reveal("symptom.custom.create")
        robot.tap("symptom.custom.create")
        robot.clearAndType("symptom.custom.add", "Brain fog", dismiss: false)
        assertFieldAboveKeyboard("symptom.custom.add")
        robot.tap("symptom.custom.create")

        let nameButton = robot.app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "symptom.custom.name.c.")
        ).firstMatch
        XCTAssertTrue(nameButton.waitForExistence(timeout: 3))
        let raw = nameButton.identifier.replacingOccurrences(of: "symptom.custom.name.", with: "")

        robot.scrollTo("symptom.score.hot_flash.3")
        robot.tap("symptom.score.hot_flash.3")
        reveal("symptom.score.\(raw).2")
        robot.tap("symptom.score.\(raw).2")
        XCTAssertTrue(robot.app.buttons["symptom.score.\(raw).2"].isSelected)
        robot.tap("sheet.close")
        robot.waitFor(id: "cycle.chip.score.\(raw)")
        robot.waitFor(id: "cycle.chip.score.hot_flash")
        XCTAssertTrue(robot.value(of: "cycle.chip.score.\(raw)").contains("Brain fog"))
        XCTAssertTrue(robot.value(of: "cycle.chip.score.hot_flash").contains("Hot flushes"))

        robot.tap("cycle.chip.score.\(raw)")
        robot.waitFor(id: "sheet.symptom")
        reveal("symptom.custom.name.\(raw)")
        robot.tap("symptom.custom.name.\(raw)")
        robot.clearAndType("symptom.custom.add", "Fog", dismiss: false)
        assertFieldAboveKeyboard("symptom.custom.add")
        robot.tap("symptom.custom.save.\(raw)")
        robot.tap("sheet.close")
        let chip = robot.value(of: "cycle.chip.score.\(raw)")
        XCTAssertTrue(chip.contains("Fog"))
        XCTAssertFalse(chip.contains("Brain"))
        XCTAssertTrue(robot.value(of: "cycle.chip.score.hot_flash").contains("strong"))

        robot.tap("tab.trends")
        robot.waitFor(id: "trends.change")
        robot.tap("trends.change")
        robot.waitFor(id: "trends.group.custom")
        robot.tap("trends.series.\(raw)")
        XCTAssertTrue(robot.value(of: "trends.status").contains(raw))
        robot.tap("sheet.close")

        robot.tap("tab.cycle")
        robot.tap("cycle.action.symptom")
        robot.waitFor(id: "sheet.symptom")
        reveal("symptom.custom.name.\(raw)")
        robot.tap("symptom.custom.name.\(raw)")
        robot.tap("symptom.custom.delete.\(raw)")
        XCTAssertTrue(robot.app.staticTexts["Delete Fog and all its past scores?"].waitForExistence(timeout: 2))
        robot.tap("confirm.delete")
        robot.waitGone(id: "confirm.delete")
        robot.waitGone(id: "symptom.custom.add")
        robot.tap("sheet.close")
        XCTAssertFalse(robot.exists("cycle.chip.score.\(raw)"))
        robot.waitFor(id: "cycle.chip.score.hot_flash")
        XCTAssertTrue(robot.value(of: "cycle.chip.score.hot_flash").contains("strong"))
        robot.tap("cycle.chip.score.hot_flash")
        robot.waitFor(id: "sheet.symptom")
        XCTAssertFalse(robot.exists("symptom.custom.name.\(raw)"))
        XCTAssertTrue(robot.app.buttons["symptom.score.hot_flash.3"].isSelected)
        robot.tap("sheet.close")
    }

    /// The new custom row sits on the sheet edge after Add. A hittable check can
    /// stop while the button center is still clipped, so the tap does nothing.
    private func reveal(_ id: String) {
        robot.scrollTo(id)
        let el = robot.app.descendants(matching: .any).matching(identifier: id).firstMatch
        guard el.frame.maxY > robot.app.frame.height - 140 else { return }
        let start = robot.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.58))
        let end = robot.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func assertFieldAboveKeyboard(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = robot.app.descendants(matching: .any).matching(identifier: id).firstMatch
        let keyboard = robot.app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 2), "keyboard for \(id)", file: file, line: line)
        let deadline = Date().addingTimeInterval(2)
        var above = false
        while Date() < deadline {
            if field.frame.maxY <= keyboard.frame.minY + 1, field.frame.height > 1 {
                above = true
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(
            above,
            "\(id) maxY \(field.frame.maxY) is behind keyboard minY \(keyboard.frame.minY)",
            file: file,
            line: line
        )
    }
}
