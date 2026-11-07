import UIKit
import XCTest

final class DialogFooterShotTests: PeriMediUITestCase {
    private let today = "2026-03-15"

    func testWriteDialogFooters() throws {
        let env = ProcessInfo.processInfo.environment
        let flag = env["DIALOG_SHOTS"] ?? env["TEST_RUNNER_DIALOG_SHOTS"] ?? ""
        guard flag == "1" else {
            let seen = env.keys.filter { key in
                key.contains("DIALOG") || key.contains("SHOT") || key.hasPrefix("TEST_RUNNER")
            }.sorted().joined(separator: ",")
            throw XCTSkip("DIALOG_SHOTS=1 seen=\(seen)")
        }
        let root = URL(fileURLWithPath: env["DIALOG_SHOTS_DIR"] ?? env["TEST_RUNNER_DIALOG_SHOTS_DIR"] ?? "/tmp/dialog-buttons")
        let passes = (env["DIALOG_SHOTS_PASSES"] ?? env["TEST_RUNNER_DIALOG_SHOTS_PASSES"] ?? "en-light,de-light,en-dark")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        for pass in passes {
            let parts = pass.split(separator: "-")
            let locale = String(parts.first ?? "en")
            let dark = pass.hasSuffix("dark")
            XCUIDevice.shared.appearance = dark ? .dark : .light
            try capture(locale: locale, tag: pass, root: root)
        }
    }

    override func tearDown() {
        XCUIDevice.shared.appearance = .light
        super.tearDown()
    }

    private func capture(locale: String, tag: String, root: URL) throws {
        let dir = root.appendingPathComponent(tag)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        print("dialog-footer-shots capturing \(tag)")
        let writer = DialogShotWriter(directory: dir)
        let base = [
            "-\(locale)",
            "-clear",
            "-uiTesting",
            "-today=\(today)",
            "-loadSample",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryXXL",
        ]

        robot.launch(arguments: base)
        robot.tap("cycle.action.med")
        robot.waitFor(id: "sheet.med")
        try writer.write("01-med-new")
        robot.scrollTo("med.start")
        robot.tap("med.start")
        robot.waitFor(id: "date.done", timeout: 6)
        try writer.write("18-date-picker")
        robot.tap("date.done")
        robot.waitGone(id: "date.done")
        let time = robot.app.buttons["20:00"]
        XCTAssertTrue(time.waitForExistence(timeout: 4), "take-time 20:00")
        time.tap()
        robot.waitFor(id: "time.done", timeout: 6)
        try writer.write("19-time-picker")
        robot.tap("time.done")
        robot.waitGone(id: "time.done")
        robot.closeSheet(id: "sheet.med")

        robot.scrollTo("cycle.lane.estradiol-gel.edit")
        robot.tap("cycle.lane.estradiol-gel.edit")
        robot.waitFor(id: "sheet.med")
        robot.scrollTo("med.delete")
        try writer.write("02-med-edit")
        robot.tap("med.delete")
        robot.waitFor(id: "confirm.delete", timeout: 6)
        try writer.write("03-delete-medication")
        robot.tap("confirm.cancel")
        robot.waitGone(id: "confirm.delete")
        robot.closeSheet(id: "sheet.med")

        robot.tap("cycle.action.period")
        robot.waitFor(id: "sheet.period")
        try writer.write("04-period-settings")
        robot.scrollTo("period.add")
        robot.tap("period.add")
        robot.waitFor(id: "period.save")
        try writer.write("05-period-new")
        robot.tap("confirm.cancel")
        robot.waitFor(id: "period.add")
        tapFirst(matching: "period.history.")
        robot.waitFor(id: "period.save")
        try writer.write("06-period-edit")
        robot.tap("period.delete")
        robot.waitFor(id: "confirm.delete")
        try writer.write("07-delete-period")
        robot.tap("confirm.cancel")
        robot.waitFor(id: "period.delete")
        robot.tap("confirm.cancel")
        robot.waitFor(id: "period.add")
        robot.closeSheet(id: "sheet.period")

        robot.tap("cycle.action.symptom")
        robot.waitFor(id: "sheet.symptom")
        try writer.write("08-symptom-log")
        robot.scrollTo("symptom.custom.create")
        robot.tap("symptom.custom.create")
        robot.waitFor(id: "symptom.custom.add")
        try writer.write("09-symptom-name-new")
        robot.clearAndType("symptom.custom.add", "Fog", dismiss: false)
        robot.tap("symptom.custom.create")
        let saved = button(matching: "symptom.custom.name.")
        XCTAssertTrue(saved.waitForExistence(timeout: 4), "saved custom name")
        robot.scrollTo(saved.identifier)
        let opened = button(matching: "symptom.custom.name.")
        opened.tap()
        robot.waitFor(id: "symptom.custom.add")
        try writer.write("10-symptom-name-edit")
        let raw = opened.identifier.replacingOccurrences(of: "symptom.custom.name.", with: "")
        robot.tap("symptom.custom.delete.\(raw)")
        robot.waitFor(id: "confirm.delete")
        try writer.write("11-delete-symptom")
        robot.tap("confirm.cancel")
        robot.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        robot.closeSheet(id: "sheet.symptom")

        robot.tap("tab.trends")
        robot.scrollTo("trends.change")
        robot.tap("trends.change")
        robot.waitFor(id: "sheet.trends")
        try writer.write("12-trends-picker")
        robot.closeSheet(id: "sheet.trends")

        robot.tap("tab.more")
        robot.scrollTo("more.sample")
        robot.tap("more.sample")
        robot.waitFor(id: "confirm.action")
        try writer.write("15-load-sample")
        robot.tap("confirm.cancel")
        robot.waitGone(id: "confirm.action")
        robot.scrollTo("more.clear")
        robot.tap("more.clear")
        robot.waitFor(id: "confirm.delete")
        try writer.write("16-clear-all")
        robot.tap("confirm.cancel")
        robot.waitGone(id: "confirm.delete")
        robot.scrollTo("more.sharePdf")
        robot.tap("more.sharePdf")
        robot.waitFor(id: "visit.range")
        try writer.write("13-visit-range")
        robot.tap("visit.range.continue")
        robot.waitFor(id: "visit.pdf.preview")
        try writer.write("14-visit-preview")
        robot.tap("visit.pdf.back")
        robot.waitFor(id: "visit.range")
        robot.closeSheet(id: "visit.range")

        robot.launch(arguments: [
            "-\(locale)",
            "-clear",
            "-uiTesting",
            "-today=\(today)",
            "-remindIn=2",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryXXL",
        ])
        robot.addMedication(name: "Estrogen", dose: "1 mg")
        robot.waitFor(id: "reminder.banner", timeout: 8)
        try writer.write("17-reminder")
        robot.tap("reminder.taken")
        robot.waitGone(id: "reminder.banner")
    }

    func testWriteCorrectedDialogFooters() throws {
        let env = ProcessInfo.processInfo.environment
        let flag = env["DIALOG_SHOTS"] ?? env["TEST_RUNNER_DIALOG_SHOTS"] ?? ""
        guard flag == "1" else {
            throw XCTSkip("DIALOG_SHOTS=1")
        }
        let root = URL(fileURLWithPath: env["DIALOG_SHOTS_DIR"] ?? env["TEST_RUNNER_DIALOG_SHOTS_DIR"] ?? "/tmp/dialog-buttons")
        let passes = (env["DIALOG_SHOTS_PASSES"] ?? env["TEST_RUNNER_DIALOG_SHOTS_PASSES"] ?? "en-light,de-light")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        for pass in passes {
            let parts = pass.split(separator: "-")
            let locale = String(parts.first ?? "en")
            let dark = pass.hasSuffix("dark")
            XCUIDevice.shared.appearance = dark ? .dark : .light
            try captureCorrected(locale: locale, tag: pass, root: root)
        }
    }

    func testImmediateActionsKeepWhatTheyShow() {
        let today = "2026-03-15"
        robot.launch(arguments: ["-en", "-clear", "-uiTesting", "-today=\(today)"])

        robot.tap("cycle.action.period")
        robot.waitFor(id: "sheet.period")
        XCTAssertFalse(robot.app.buttons["Cancel"].exists)
        XCTAssertTrue(robot.app.buttons["Done"].waitForExistence(timeout: 2))
        pickDayCount("period.cycleDays", from: "28", to: "29")
        robot.app.buttons["Done"].tap()
        robot.waitGone(id: "sheet.period")

        robot.tap("cycle.action.period")
        robot.waitFor(id: "sheet.period")
        XCTAssertEqual(robot.value(of: "period.cycleDays"), "29")
        XCTAssertEqual(robot.value(of: "period.periodDays"), "5")
        XCTAssertFalse(robot.app.buttons["Cancel"].exists)

        robot.scrollTo("period.add")
        robot.tap("period.add")
        robot.waitFor(id: "period.save")
        robot.setDateKey("period.end", "2026-03-10")
        XCTAssertTrue(robot.value(of: "period.end").contains("2026-03-10"))
        robot.tap("period.end")
        robot.waitFor(id: "date.done")
        let clear = robot.app.buttons["Clear"]
        XCTAssertTrue(clear.waitForExistence(timeout: 3))
        clear.tap()
        robot.waitGone(id: "date.done")
        XCTAssertFalse(robot.value(of: "period.end").contains("2026-03-10"))
        robot.tap("confirm.cancel")
        robot.waitFor(id: "period.add")

        robot.tap("period.add")
        robot.tap("period.save")
        robot.waitFor(id: "period.add")
        robot.tap("sheet.close")
        robot.waitGone(id: "sheet.period")

        robot.tap("cycle.action.symptom")
        robot.waitFor(id: "sheet.symptom")
        XCTAssertFalse(robot.app.buttons["Cancel"].exists)
        robot.tap("symptom.score.hot_flash.2")
        robot.app.buttons["Done"].tap()
        robot.waitGone(id: "sheet.symptom")
        robot.waitFor(id: "cycle.chip.score.hot_flash")
        robot.tap("cycle.action.symptom")
        robot.waitFor(id: "sheet.symptom")
        XCTAssertTrue(robot.app.buttons["symptom.score.hot_flash.2"].isSelected)
        robot.tap("sheet.close")
        robot.waitGone(id: "sheet.symptom")

        robot.tap("tab.trends")
        robot.scrollTo("trends.change")
        robot.tap("trends.change")
        robot.waitFor(id: "sheet.trends")
        XCTAssertFalse(robot.app.buttons["Done"].exists)
        XCTAssertFalse(robot.app.buttons["Cancel"].exists)
        let before = robot.value(of: "trends.series.hot_flash")
        robot.tap("trends.series.hot_flash")
        let changed = robot.value(of: "trends.series.hot_flash")
        XCTAssertNotEqual(before, changed)
        robot.tap("sheet.close")
        robot.waitGone(id: "sheet.trends")
        robot.tap("trends.change")
        robot.waitFor(id: "sheet.trends")
        XCTAssertEqual(robot.value(of: "trends.series.hot_flash"), changed)
        robot.tap("sheet.close")

        robot.tap("tab.cycle")
        robot.tap("cycle.action.med")
        robot.waitFor(id: "sheet.med")
        robot.scrollTo("med.start")
        changeDraftTakeTime(from: "20:00", to: "21:00")
        robot.setDateKey("med.start", "2026-03-01")
        XCTAssertTrue(robot.value(of: "med.start").contains("2026-03-01"))
        robot.closeSheet(id: "sheet.med")

        robot.launch(arguments: [
            "-en", "-clear", "-uiTesting", "-today=\(today)", "-remindIn=2",
        ])
        robot.addMedication(name: "Estrogen", dose: "1 mg")
        robot.waitFor(id: "reminder.banner", timeout: 8)
        XCTAssertTrue(robot.app.buttons["Close"].waitForExistence(timeout: 2))
        XCTAssertTrue(robot.exists("reminder.snooze"))
        XCTAssertTrue(robot.exists("reminder.taken"))
        XCTAssertFalse(robot.app.buttons["Cancel"].exists)
        robot.app.buttons["Close"].tap()
        robot.waitGone(id: "reminder.banner")
        robot.assertStatus("cycle.lane.estrogen.status", word: "Not taken", token: "not-taken")
        robot.scrollTo("cycle.lane.estrogen.edit")
        robot.tap("cycle.lane.estrogen.edit")
        robot.waitFor(id: "sheet.med")
        let toggle = robot.app.switches["med.remind"]
        for _ in 0..<5 where !toggle.exists {
            robot.app.swipeUp()
        }
        XCTAssertTrue(toggle.waitForExistence(timeout: 3), "med.remind switch")
        let raw = toggle.value
        let on = (raw as? String) == "1" || (raw as? NSNumber)?.intValue == 1
        XCTAssertTrue(on, "med.remind \(String(describing: raw))")
    }

    private func captureCorrected(locale: String, tag: String, root: URL) throws {
        let dir = root.appendingPathComponent(tag)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let writer = DialogShotWriter(directory: dir)
        let base = [
            "-\(locale)",
            "-clear",
            "-uiTesting",
            "-today=\(today)",
            "-loadSample",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryXXL",
        ]
        robot.launch(arguments: base)
        robot.tap("cycle.action.period")
        robot.waitFor(id: "sheet.period")
        try writer.write("04-period-settings")
        robot.closeSheet(id: "sheet.period")

        robot.tap("cycle.action.symptom")
        robot.waitFor(id: "sheet.symptom")
        try writer.write("08-symptom-log")
        robot.closeSheet(id: "sheet.symptom")

        robot.tap("tab.trends")
        robot.scrollTo("trends.change")
        robot.tap("trends.change")
        robot.waitFor(id: "sheet.trends")
        try writer.write("12-trends-picker")
        robot.closeSheet(id: "sheet.trends")

        robot.tap("tab.cycle")
        robot.tap("cycle.action.med")
        robot.waitFor(id: "sheet.med")
        robot.scrollTo("med.start")
        let time = robot.app.buttons["20:00"]
        XCTAssertTrue(time.waitForExistence(timeout: 4), "take-time 20:00")
        time.tap()
        robot.waitFor(id: "time.done", timeout: 6)
        try writer.write("19-time-picker")
        robot.tap("time.done")
        robot.waitGone(id: "time.done")
        let endTitle = locale == "de" ? "TT.MM.JJJJ" : "Optional"
        let end = robot.app.buttons[endTitle]
        XCTAssertTrue(end.waitForExistence(timeout: 4), "empty end date")
        end.tap()
        robot.waitFor(id: "date.done", timeout: 6)
        try writer.write("20-date-clear")
        robot.tap("date.done")
        robot.waitGone(id: "date.done")
        robot.tap("med.start")
        robot.waitFor(id: "date.done", timeout: 6)
        try writer.write("18-date-picker")
        robot.tap("date.done")
        robot.closeSheet(id: "sheet.med")

        robot.launch(arguments: [
            "-\(locale)",
            "-clear",
            "-uiTesting",
            "-today=\(today)",
            "-remindIn=2",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryXXL",
        ])
        robot.addMedication(name: "Estrogen", dose: "1 mg")
        robot.waitFor(id: "reminder.banner", timeout: 8)
        try writer.write("17-reminder")
    }

    private func changeDraftTakeTime(from current: String, to shown: String) {
        let open = robot.app.buttons[current]
        XCTAssertTrue(open.waitForExistence(timeout: 4), "default take time \(current)")
        open.tap()
        robot.waitFor(id: "time.done")
        let hour = robot.app.pickerWheels.element(boundBy: 0)
        XCTAssertTrue(hour.waitForExistence(timeout: 4), "hour wheel")
        let before = String(describing: hour.value ?? "")
        let target = nextHourWheelValue(before)
        hour.adjust(toPickerWheelValue: target)
        let moved = String(describing: hour.value ?? "")
        XCTAssertNotEqual(moved, before, "hour wheel stayed \(before)")
        robot.tap("time.done")
        robot.waitGone(id: "time.done")
        let kept = robot.app.buttons[shown]
        XCTAssertTrue(kept.waitForExistence(timeout: 4), "unsaved sheet keeps \(shown), wheel \(moved)")
        XCTAssertFalse(robot.app.buttons[current].exists, "unsaved sheet still shows \(current)")
        kept.tap()
        robot.waitFor(id: "time.done")
        let again = String(describing: robot.app.pickerWheels.element(boundBy: 0).value ?? "")
        XCTAssertEqual(again, moved, "reopened chooser shows \(again), wanted \(moved)")
        robot.tap("time.done")
        robot.waitGone(id: "time.done")
        XCTAssertTrue(robot.app.buttons[shown].waitForExistence(timeout: 4), "unsaved sheet still shows \(shown)")
    }

    private func nextHourWheelValue(_ value: String) -> String {
        guard let match = value.range(of: #"\d+"#, options: .regularExpression),
              let number = Int(value[match]) else {
            return "9"
        }
        let next = number == 12 ? 1 : number + 1
        return String(next)
    }

    private func pickDayCount(_ id: String, from current: String, to next: String) {
        XCTAssertEqual(robot.value(of: id), current)
        robot.tap(id)
        let choice = robot.app.buttons[next]
        XCTAssertTrue(choice.waitForExistence(timeout: 4), next)
        choice.tap()
    }

    private func button(matching prefix: String) -> XCUIElement {
        robot.app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", prefix)
        ).firstMatch
    }

    private func tapFirst(matching prefix: String) {
        let query = robot.app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", prefix)
        )
        for _ in 0..<4 {
            let row = query.firstMatch
            if row.exists, row.isHittable {
                row.tap()
                return
            }
            robot.app.swipeUp()
        }
        let row = query.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3), prefix)
        row.tap()
    }
}

private struct DialogShotWriter {
    var directory: URL

    func write(_ name: String) throws {
        let dest = directory.appendingPathComponent("\(name).png")
        try pngData(from: XCUIScreen.main.screenshot()).write(to: dest, options: .atomic)
    }

    private func pngData(from screenshot: XCUIScreenshot) -> Data {
        let image = screenshot.image
        let maxWidth: CGFloat = 430
        let scale = min(1, maxWidth / max(image.size.width, 1))
        let size = CGSize(
            width: (image.size.width * scale).rounded(),
            height: (image.size.height * scale).rounded()
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.pngData() ?? Data()
    }
}
