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
