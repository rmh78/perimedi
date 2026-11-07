import UIKit
import XCTest

final class SelectionShotTests: PeriMediUITestCase {
    private let today = "2026-03-15"
    private let passes = ["en-light", "de-light", "en-dark"]

    func testWriteSelectionShots() throws {
        let env = ProcessInfo.processInfo.environment
        let flag = env["SELECTION_SHOTS"] ?? env["TEST_RUNNER_SELECTION_SHOTS"] ?? ""
        guard flag == "1" else {
            let seen = env.keys.filter { key in
                key.contains("SELECTION") || key.contains("SHOT") || key.hasPrefix("TEST_RUNNER")
            }.sorted().joined(separator: ",")
            throw XCTSkip("SELECTION_SHOTS=1 seen=\(seen)")
        }
        guard let rawDir = env["SELECTION_SHOTS_DIR"] ?? env["TEST_RUNNER_SELECTION_SHOTS_DIR"],
              !rawDir.isEmpty else {
            XCTFail("SELECTION_SHOTS_DIR missing")
            return
        }
        let root = URL(fileURLWithPath: rawDir)
        for pass in passes {
            let locale = String(pass.split(separator: "-").first ?? "en")
            let dark = pass.hasSuffix("dark")
            let lightFrames = ["cycle", "med-palette", "med-cyclic", "med-weekdays", "period-settings", "period-flow"]
            let needed = dark ? wants("period-settings") : lightFrames.contains { wants($0) }
            if !needed { continue }
            XCUIDevice.shared.appearance = dark ? .dark : .light
            if dark {
                try capturePeriodSettings(locale: locale, tag: pass, root: root)
            } else {
                try captureLight(locale: locale, tag: pass, root: root)
            }
        }
    }

    override func tearDown() {
        XCUIDevice.shared.appearance = .light
        super.tearDown()
    }

    private func captureLight(locale: String, tag: String, root: URL) throws {
        let writer = try writer(tag: tag, root: root)
        launch(locale)
        robot.waitFor(id: "cycle.lane.estradiol-gel.edit", timeout: 8)
        if wants("cycle") { try writer.write("cycle") }
        if wants("med-palette") || wants("med-cyclic") || wants("med-weekdays") {
            try captureMedication(locale: locale, writer: writer)
        }
        if wants("period-settings") || wants("period-flow") {
            openPeriodSettings()
            if wants("period-settings") { try writer.write("period-settings") }
            if wants("period-flow") { try capturePeriodFlow(locale: locale, writer: writer) }
        }
    }

    private func capturePeriodSettings(locale: String, tag: String, root: URL) throws {
        let writer = try writer(tag: tag, root: root)
        launch(locale)
        openPeriodSettings()
        try writer.write("period-settings")
    }

    private func openPeriodSettings() {
        robot.tap("cycle.action.period")
        robot.waitFor(id: "sheet.period")
        robot.scrollTo("period.cycleDays")
        robot.scrollTo("period.periodDays")
        XCTAssertTrue(robot.exists("period.cycleDays"), "cycle length menu")
        XCTAssertTrue(robot.exists("period.periodDays"), "period length menu")
    }

    private func capturePeriodFlow(locale: String, writer: SelectionShotWriter) throws {
        robot.scrollTo("period.add")
        robot.tap("period.add")
        robot.waitFor(id: "period.save")
        let flow = robot.app.buttons[locale == "de" ? "Mittel" : "Medium"]
        show(flow, name: "flow menu")
        XCTAssertTrue(flow.isHittable, "flow menu clipped")
        try writer.write("period-flow")
    }

    private func captureMedication(locale: String, writer: SelectionShotWriter) throws {
        robot.tap("cycle.action.med")
        robot.waitFor(id: "sheet.med")
        if wants("med-palette") {
            let swatch = robot.app.descendants(matching: .any)["#d43d6c"]
            show(swatch, name: "palette")
            try writer.write("med-palette")
        }

        if wants("med-cyclic") || wants("med-weekdays") {
            robot.scrollTo("med.mode")
            robot.pick("med.mode", "med.mode.cyclic")
            assertMode(locale == "de" ? "Zyklisch" : "Cyclic")
        }
        if wants("med-cyclic") {
            let apply = robot.app.buttons["21"]
            let pause = robot.app.buttons["7"]
            XCTAssertTrue(apply.waitForExistence(timeout: 4), "apply days \(buttonLabels())")
            XCTAssertTrue(pause.waitForExistence(timeout: 4), "pause days \(buttonLabels())")
            guard revealInDialog(apply, name: "apply days"), revealInDialog(pause, name: "pause days") else {
                return
            }
            try writer.write("med-cyclic")
        }

        if wants("med-weekdays") {
            guard revealInDialog(robot.element("med.mode"), name: "type menu") else { return }
            let specific = locale == "de" ? "Bestimmte Tage" : "Specific days"
            robot.pick("med.mode", specific)
            assertMode(specific)
            let mondayLabel = locale == "de" ? "Mo" : "Mon"
            let sundayLabel = locale == "de" ? "So" : "Sun"
            let monday = weekday(mondayLabel)
            let sunday = weekday(sundayLabel)
            XCTAssertTrue(monday.waitForExistence(timeout: 4), "Monday \(buttonLabels())")
            guard revealInDialog(monday, name: "Monday"), revealInDialog(sunday, name: "Sunday") else {
                return
            }
            assertWeekdaySelection(mondayLabel, selected: true)
            assertWeekdaySelection(sundayLabel, selected: false)
            try writer.write("med-weekdays")
        }
        robot.closeSheet(id: "sheet.med")
    }

    private func launch(_ locale: String) {
        robot.launch(arguments: [
            "-\(locale)",
            "-clear",
            "-uiTesting",
            "-loadSample",
            "-today=\(today)",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryXXL",
        ])
    }

    private func assertMode(_ label: String) {
        let mode = robot.value(of: "med.mode")
        XCTAssertTrue(
            mode == label || mode.contains(label),
            "mode \(mode) wanted \(label)"
        )
    }

    private func wants(_ name: String) -> Bool {
        let env = ProcessInfo.processInfo.environment
        let raw = env["SELECTION_SHOTS_FRAMES"] ?? env["TEST_RUNNER_SELECTION_SHOTS_FRAMES"] ?? ""
        let names = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if names.isEmpty { return true }
        return names.contains(name)
    }

    private func weekday(_ label: String) -> XCUIElement {
        robot.app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func assertWeekdaySelection(_ label: String, selected: Bool) {
        let matches = robot.app.buttons.matching(NSPredicate(format: "label == %@", label))
        var chips: [XCUIElement] = []
        for index in 0..<matches.count {
            let button = matches.element(boundBy: index)
            if inDialogBody(button) { chips.append(button) }
        }
        XCTAssertEqual(chips.count, 1, "weekday \(label) chips in the dialog \(chips.count) of \(matches.count)")
        guard let chip = chips.first else { return }
        XCTAssertEqual(chip.label, label)
        XCTAssertEqual(chip.isSelected, selected, "weekday \(label) selected \(chip.isSelected)")
    }

    @discardableResult
    private func revealInDialog(_ element: XCUIElement, name: String) -> Bool {
        var previous = CGRect.null
        var stale = 0
        for _ in 0..<6 {
            if inDialogBody(element) { return true }
            let frame = element.exists ? element.frame : .null
            if frame.width > 1, frame == previous {
                stale += 1
            } else {
                stale = 0
            }
            if stale >= 2 { break }
            previous = frame
            let up = shouldScrollUp(element)
            if stale == 1 || dialogScrollView() == nil {
                dragDialog(up: up)
            } else {
                swipeDialog(up: up)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertTrue(inDialogBody(element), "\(name) not in dialog body \(shotLog(name, element))")
        return false
    }

    private func inDialogBody(_ element: XCUIElement) -> Bool {
        guard element.exists, element.isHittable else { return false }
        let frame = element.frame
        guard frame.width > 8, frame.height > 8 else { return false }
        guard frame.maxY <= sheetFooterTop() - 6 else { return false }
        guard let scroll = dialogScrollView() else { return frame.minY >= 8 }
        let view = scroll.frame
        return frame.minY >= view.minY + 2 && frame.maxY <= view.maxY - 2
    }

    private func shouldScrollUp(_ element: XCUIElement) -> Bool {
        guard element.exists, element.frame.width > 1 else { return true }
        let viewport = dialogScrollView()?.frame ?? robot.app.frame
        return element.frame.maxY >= viewport.minY + 8
    }

    private func swipeDialog(up: Bool) {
        guard let scroll = dialogScrollView() else {
            dragDialog(up: up)
            return
        }
        if up {
            scroll.swipeUp(velocity: .slow)
        } else {
            scroll.swipeDown(velocity: .slow)
        }
    }

    private func dragDialog(up: Bool) {
        let area: CGRect
        if let scroll = dialogScrollView() {
            area = scroll.frame
        } else {
            let footer = sheetFooterTop()
            let top = robot.app.frame.height * 0.28
            area = CGRect(x: 20, y: top, width: robot.app.frame.width - 40, height: max(80, footer - 12 - top))
        }
        let travel = min(110, max(48, area.height * 0.45))
        let x = area.midX
        let startY = up ? min(area.maxY - 16, sheetFooterTop() - 16) : area.minY + 20
        let endY = up ? startY - travel : startY + travel
        let origin = robot.app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: x, dy: startY))
        let end = origin.withOffset(CGVector(dx: x, dy: endY))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.05)
    }

    private func dialogScrollView() -> XCUIElement? {
        let footer = sheetFooterTop()
        var best: XCUIElement?
        var bestGap = CGFloat.greatestFiniteMagnitude
        for scroll in robot.app.scrollViews.allElementsBoundByIndex {
            let frame = scroll.frame
            guard frame.width > 140, frame.height > 120 else { continue }
            let gap = footer - frame.maxY
            guard gap > -12, gap < 64 else { continue }
            if gap < bestGap {
                bestGap = gap
                best = scroll
            }
        }
        return best
    }

    private func sheetFooterTop() -> CGFloat {
        let save = robot.element("med.save")
        if save.exists, save.frame.height > 1, save.frame.minY > 40 {
            return save.frame.minY
        }
        return robot.app.frame.maxY - 96
    }

    private func shotLog(_ name: String, _ element: XCUIElement) -> String {
        let scrolls = robot.app.scrollViews.allElementsBoundByIndex.enumerated().map { index, scroll in
            "\(index):\(scroll.frame.debugDescription)"
        }.joined(separator: " ")
        let frame = element.exists ? element.frame.debugDescription : "missing"
        let hittable = element.exists && element.isHittable
        return "\(name) frame=\(frame) hittable=\(hittable) footer=\(sheetFooterTop()) scrolls=\(scrolls)"
    }

    private func show(_ element: XCUIElement, name: String) {
        let deadline = Date().addingTimeInterval(8)
        var previous = CGRect.null
        while Date() < deadline {
            if inSheet(element) { return }
            let frame = element.exists ? element.frame : .null
            if frame.width > 1, frame == previous { break }
            previous = frame
            if frame.width > 1, frame.minY < 8 {
                robot.app.swipeDown()
            } else {
                robot.app.swipeUp()
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
        XCTAssertTrue(inSheet(element), "\(name) not in view \(element.frame) \(buttonLabels())")
    }

    private func inSheet(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        let bounds = robot.app.frame
        guard frame.width > 1, frame.height > 1 else { return false }
        return frame.minY >= bounds.minY + 8 && frame.maxY <= bounds.maxY - 16
    }

    private func buttonLabels() -> String {
        robot.app.buttons.allElementsBoundByIndex.prefix(50).map(\.label).joined(separator: "|")
    }

    private func writer(tag: String, root: URL) throws -> SelectionShotWriter {
        let dir = root.appendingPathComponent(tag)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return SelectionShotWriter(directory: dir)
    }
}

private struct SelectionShotWriter {
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
