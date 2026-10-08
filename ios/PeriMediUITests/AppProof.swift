import XCTest

struct AppProof {
    let robot: AppRobot

    func run() {
        robot.launch(.pinnedRemindIn(seconds: 2))
        assertEmptyHome()
        assertEmptyTrends()
        editDeleteAndRelogPeriod()
        trackMedsReminderMonthAndMore()
        robot.launch(.trendsChart)
        assertTrendsChart()
        assertCustomSymptom()
        robot.launch(.trendsNoScores)
        assertNoScores()
    }

    private func assertEmptyHome() {
        robot.waitFor(id: "tab.cycle")
        robot.waitFor(id: "tab.trends")
        robot.waitFor(id: "tab.month")
        robot.waitFor(id: "tab.more")
        robot.waitFor(id: "cycle.action.med")
        robot.waitFor(id: "cycle.action.period")
        robot.waitFor(id: "cycle.action.symptom")
        robot.waitFor(id: "cycle.empty.meds")
        XCTAssertTrue(robot.value(of: "cycle.empty.meds").contains("need-period"))
        XCTAssertTrue(robot.value(of: "cycle.empty.meds").contains("need-med"))
        robot.waitFor(id: "cycle.intro")
        XCTAssertFalse(robot.exists("cycle.lane.estrogen"))
        XCTAssertFalse(robot.exists("cycle.effect"))
    }

    private func assertEmptyTrends() {
        robot.tap("tab.trends")
        robot.waitFor(id: "trends.screen")
        robot.waitFor(id: "trends.status")
        XCTAssertEqual(robot.value(of: "trends.status"), "need-cycles")
        robot.waitFor(id: "trends.empty")
        XCTAssertEqual(robot.value(of: "trends.empty"), "need-cycles")
        XCTAssertFalse(robot.exists("trends.series.hot_flash"))
        XCTAssertFalse(robot.exists("trends.intro"))
        XCTAssertFalse(robot.exists("trends.change"))
        robot.tap("tab.cycle")
        robot.waitFor(id: "cycle.intro")
    }

    private func editDeleteAndRelogPeriod() {
        robot.addPeriod()
        robot.tap("cycle.action.period")
        robot.waitFor(id: "sheet.period")
        if !robot.exists("period.add") {
            robot.app.swipeUp()
        }
        robot.tap("period.add")
        robot.waitFor(id: "period.end")
        let end = robot.element("period.end")
        let endValue = (end.value as? String) ?? ""
        XCTAssertTrue(
            endValue.isEmpty || endValue == "YYYY-MM-DD",
            "period.end is \(endValue)"
        )
        robot.tap("confirm.cancel")
        robot.waitGone(id: "period.end")
        tapHistory()

        let start = robot.element("period.start")
        let startShown = ((start.value as? String) ?? "") + start.label
        XCTAssertTrue(startShown.contains("2026-03-07"), startShown)
        XCTAssertTrue(robot.exists("period.delete"))
        robot.setDateKey("period.end", "2026-03-12")
        robot.tap("period.save")

        let edited = historyRow()
        XCTAssertTrue(edited.waitForExistence(timeout: 2))
        XCTAssertEqual(edited.label, "7–12 Mar 2026")
        robot.press(edited)
        robot.tap("period.delete")
        XCTAssertTrue(robot.app.staticTexts["Delete 7–12 Mar 2026?"].waitForExistence(timeout: 2))
        robot.tap("confirm.delete")
        assertNoHistoryRows()

        robot.closeSheet(id: "sheet.period")
        robot.waitFor(id: "cycle.intro")
        robot.waitFor(id: "cycle.empty.meds")
        XCTAssertTrue(robot.value(of: "cycle.empty.meds").contains("need-period"))
        XCTAssertFalse(robot.exists("cycle.strip.day.2026-03-07"))

        robot.addPeriod()
        robot.waitFor(id: "cycle.strip.day.\(UITestDate.periodStart)")
        XCTAssertTrue(robot.value(of: "cycle.strip.day.\(UITestDate.periodStart)").contains("period"))
        XCTAssertTrue(robot.value(of: "cycle.strip.day.\(UITestDate.periodEnd)").contains("period"))
        robot.waitFor(id: "cycle.empty.meds")
        XCTAssertEqual(robot.value(of: "cycle.empty.meds"), "need-med")
        XCTAssertFalse(robot.exists("cycle.intro"))
        robot.waitFor(id: "cycle.effect")
        XCTAssertEqual(robot.value(of: "cycle.effect"), "no-previous")
    }

    private func trackMedsReminderMonthAndMore() {
        robot.addMedication(name: "Estrogen", dose: "1 mg", start: UITestDate.periodStart)
        robot.waitFor(id: "cycle.lane.estrogen")
        XCTAssertFalse(robot.exists("cycle.empty.meds"))
        XCTAssertFalse(robot.exists("cycle.intro"))
        XCTAssertEqual(robot.value(of: "cycle.lane.estrogen.status"), "not-taken")
        XCTAssertTrue(
            robot.spin(timeout: 12) { robot.exists("reminder.banner") },
            "reminder.banner late"
        )
        robot.tap("reminder.taken")
        robot.waitGone(id: "reminder.banner")
        XCTAssertEqual(robot.value(of: "cycle.lane.estrogen.status"), "taken")

        robot.tap("cycle.lane.estrogen")
        XCTAssertEqual(robot.value(of: "cycle.lane.estrogen.status"), "not-taken")
        robot.waitFor(id: "reminder.banner", timeout: 12)
        robot.tap("reminder.snooze")
        robot.waitGone(id: "reminder.banner")
        XCTAssertEqual(robot.value(of: "cycle.lane.estrogen.status"), "not-taken")
        robot.tap("cycle.lane.estrogen")
        XCTAssertEqual(robot.value(of: "cycle.lane.estrogen.status"), "taken")

        robot.addMedication(
            name: "Progesterone",
            dose: "200 mg",
            form: "Cream",
            cyclic: true,
            start: UITestDate.periodStart
        )
        robot.waitFor(id: "cycle.lane.progesterone")
        robot.waitFor(id: "cycle.lane.estrogen")
        robot.waitFor(id: "reminder.banner", timeout: 12)
        robot.tap("reminder.taken")
        robot.waitGone(id: "reminder.banner")
        XCTAssertEqual(robot.value(of: "cycle.lane.progesterone.status"), "taken")

        robot.waitFor(id: "cycle.pager.label")
        let onToday = robot.value(of: "cycle.pager.label")
        XCTAssertFalse(onToday.isEmpty)
        robot.tap("cycle.pager.prev")
        XCTAssertNotEqual(robot.value(of: "cycle.pager.label"), onToday)
        for _ in 0..<3 {
            robot.tap("cycle.pager.prev")
        }
        robot.waitFor(id: "cycle.chip.period")
        robot.tap("cycle.pager.next")
        robot.tap("cycle.pager.today")
        XCTAssertEqual(robot.value(of: "cycle.pager.label"), onToday)
        XCTAssertEqual(robot.value(of: "cycle.lane.estrogen.status"), "taken")

        robot.addSymptom()
        robot.waitFor(id: "cycle.chip.score.hot_flash")
        XCTAssertTrue(robot.value(of: "cycle.chip.score.hot_flash").localizedCaseInsensitiveContains("strong"))

        robot.tap("tab.month")
        robot.waitFor(id: "month.day.\(UITestDate.today)")
        XCTAssertTrue(robot.value(of: "month.day.\(UITestDate.today)").contains("selected"))
        XCTAssertTrue(robot.value(of: "month.day.\(UITestDate.periodStart)").contains("period"))
        XCTAssertTrue(robot.value(of: "month.day.\(UITestDate.today)").contains("taken"))
        XCTAssertTrue(robot.value(of: "month.day.\(UITestDate.today)").contains("symptom"))
        robot.tap("month.pager.next")
        robot.waitFor(id: "month.day.2026-04-01")
        robot.tap("month.pager.prev")
        robot.waitFor(id: "month.day.\(UITestDate.today)")
        XCTAssertTrue(robot.value(of: "month.day.\(UITestDate.today)").contains("selected"))
        robot.tap("cycle.pager.today")
        XCTAssertTrue(robot.value(of: "month.day.\(UITestDate.today)").contains("selected"))
        robot.tap("month.day.\(UITestDate.periodStart)")
        XCTAssertTrue(robot.value(of: "month.day.\(UITestDate.periodStart)").contains("selected"))
        robot.tap("tab.cycle")
        let strip = "cycle.strip.day.\(UITestDate.periodStart)"
        robot.waitFor(id: strip)
        XCTAssertTrue(robot.value(of: strip).contains("period"))
        XCTAssertTrue(robot.element(strip).isHittable, "selected day should be in the visible plot")
        robot.tap("cycle.pager.today")
        robot.waitFor(id: "cycle.lane.estrogen")
        robot.waitFor(id: "cycle.lane.progesterone")
        XCTAssertEqual(robot.value(of: "cycle.lane.estrogen.status"), "taken")
        XCTAssertEqual(robot.value(of: "cycle.lane.progesterone.status"), "taken")

        robot.tap("tab.more")
        robot.waitFor(id: "more.lang.en")
        robot.waitFor(id: "more.lang.de")
        robot.tap("more.lang.de")
        XCTAssertEqual(robot.element("tab.more").label, "Mehr")
        robot.tap("more.lang.en")
        XCTAssertEqual(robot.element("tab.more").label, "More")
        robot.waitFor(id: "more.reminders")
        robot.tap("more.reminders")
        robot.waitFor(id: "more.reminderSound")
        robot.tap("more.reminderSoundPreview")
        _ = robot.exists("more.remindersSettings")
        robot.scrollTo("more.sharePdf")
        robot.waitFor(id: "more.sharePdf")
        robot.tap("more.sharePdf")
        robot.waitFor(id: "visit.range")
        robot.waitFor(id: "visit.range.continue")
        robot.tap("visit.range.continue")
        robot.waitFor(id: "visit.pdf.preview")
        robot.waitFor(id: "visit.pdf.share")
        robot.tap("sheet.close")
        robot.waitGone(id: "visit.pdf.preview")
        robot.waitFor(id: "more.privacyPolicy")
        robot.waitFor(id: "more.sample")
        robot.waitFor(id: "more.export")
        robot.waitFor(id: "more.import")
        robot.waitFor(id: "more.clear")
        robot.tap("more.sample")
        robot.waitFor(id: "confirm.cancel")
        robot.tap("confirm.cancel")
        robot.waitGone(id: "confirm.cancel")
    }

    private func assertTrendsChart() {
        robot.tap("tab.trends")
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

        robot.waitFor(id: "trends.dot.hot_flash.2026-01-04")
        let mild = robot.value(of: "trends.dot.hot_flash.2026-01-04")
        XCTAssertTrue(mild.contains("count:8"), mild)
        XCTAssertTrue(mild.contains("mean:1"), mild)
        XCTAssertFalse(mild.contains("count:99"), mild)
        let severe = robot.value(of: "trends.dot.hot_flash.2026-02-01")
        XCTAssertTrue(severe.contains("count:2"), severe)
        XCTAssertTrue(severe.contains("mean:4"), severe)

        XCTAssertFalse(robot.exists("trends.dot.sleep.2026-01-04"))
        robot.waitFor(id: "trends.dot.sleep.2026-02-01")
        let sleep = robot.value(of: "trends.dot.sleep.2026-02-01")
        XCTAssertTrue(sleep.contains("count:4"), sleep)
        XCTAssertFalse(sleep.contains("count:0"), sleep)

        robot.tap("trends.dot.hot_flash.2026-01-04")
        robot.waitFor(id: "trends.detail")
        let detail = robot.value(of: "trends.detail")
        XCTAssertTrue(detail.contains("id:hot_flash"), detail)
        XCTAssertTrue(detail.contains("cycle:2026-01-04"), detail)
        XCTAssertTrue(detail.contains("count:8"), detail)
        XCTAssertTrue(detail.contains("mean:1"), detail)

        robot.waitFor(id: "trends.tick.2026-02-01")
        let tick = robot.value(of: "trends.tick.2026-02-01")
        XCTAssertTrue(tick.contains("Estrogel"), tick)
        XCTAssertTrue(tick.contains("2 pumps"), tick)
        robot.waitFor(id: "trends.tick.2026-03-01")
        XCTAssertTrue(robot.value(of: "trends.tick.2026-03-01").contains("2.5 pumps"))
        robot.tap("trends.tick.2026-02-01")
        robot.waitFor(id: "trends.tickCopy")

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

    private func assertCustomSymptom() {
        robot.tap("tab.cycle")
        robot.tap("cycle.action.symptom")
        robot.waitFor(id: "sheet.symptom")
        robot.scrollTo("symptom.custom.create")
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
        robot.scrollTo("symptom.score.\(raw).2")
        robot.tap("symptom.score.\(raw).2")
        XCTAssertTrue(robot.app.buttons["symptom.score.\(raw).2"].isSelected)
        robot.tap("sheet.close")
        robot.waitFor(id: "cycle.chip.score.\(raw)")
        robot.waitFor(id: "cycle.chip.score.hot_flash")
        XCTAssertTrue(robot.value(of: "cycle.chip.score.\(raw)").contains("Brain fog"))
        XCTAssertTrue(robot.value(of: "cycle.chip.score.hot_flash").contains("Hot flushes"))

        robot.tap("cycle.chip.score.\(raw)")
        robot.waitFor(id: "sheet.symptom")
        robot.scrollTo("symptom.custom.name.\(raw)")
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
        robot.scrollTo("symptom.custom.name.\(raw)")
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

    private func assertNoScores() {
        robot.tap("tab.trends")
        robot.waitFor(id: "trends.screen")
        XCTAssertEqual(robot.value(of: "trends.status"), "no-scores")
        XCTAssertEqual(robot.value(of: "trends.empty"), "no-scores")
        XCTAssertFalse(robot.exists("trends.series.hot_flash"))
        XCTAssertFalse(robot.exists("trends.intro"))
        XCTAssertFalse(robot.exists("trends.change"))
    }

    private func historyRow() -> XCUIElement {
        robot.app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "period.history.")
        ).firstMatch
    }

    private func tapHistory() {
        let row = historyRow()
        for _ in 0..<8 {
            if robot.frameInsideChrome(row) { break }
            robot.app.swipeUp()
        }
        XCTAssertTrue(row.waitForExistence(timeout: 2))
        if !robot.frameInsideChrome(row) {
            robot.app.swipeUp()
        }
        robot.press(historyRow())
    }

    private func assertNoHistoryRows() {
        let leftover = robot.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "period.history.")
        )
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline, leftover.count > 0 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertEqual(leftover.count, 0)
    }

    private func assertFieldAboveKeyboard(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = robot.element(id)
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
