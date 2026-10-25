import UIKit
import XCTest

struct StoreShot {
    let file: String
    let waitID: String
    let prepare: (AppRobot) -> Void
}

final class StoreScreenshotTests: PeriMediUITestCase {
    private static let today = "2026-03-15"

    private static let shots: [StoreShot] = [
        StoreShot(file: "01-cycle.png", waitID: "cycle.effect") { robot in
            robot.tap("tab.cycle")
        },
        StoreShot(file: "02-trends.png", waitID: "trends.detail") { robot in
            robot.tap("tab.trends")
            selectTrendDot(robot)
        },
        StoreShot(file: "05-month.png", waitID: "month.day.\(today)") { robot in
            robot.tap("tab.month")
        },
        StoreShot(file: "06-more.png", waitID: "more.privacyPolicy") { robot in
            robot.tap("tab.more")
            showMore(robot)
        },
        StoreShot(file: "04-visit.png", waitID: "visit.pdf.preview") { robot in
            robot.scrollTo("more.sharePdf")
            robot.tap("more.sharePdf")
            robot.waitFor(id: "visit.range.continue", timeout: 8)
            robot.tap("visit.range.continue")
            robot.waitFor(id: "visit.pdf.share", timeout: 15)
        },
        StoreShot(file: "03-symptoms.png", waitID: "symptom.custom.create") { robot in
            robot.tap("sheet.close")
            robot.waitGone(id: "visit.pdf.preview")
            robot.tap("tab.cycle")
            robot.tap("cycle.action.symptom")
            robot.waitFor(id: "sheet.symptom")
            robot.scrollTo("symptom.custom.create")
        },
    ]

    func testWriteStoreScreenshots() throws {
        let storeShots = ProcessInfo.processInfo.environment["STORE_SHOTS"] ?? ""
        print("STORE_SHOTS=\(storeShots)")
        guard storeShots == "1" else {
            throw XCTSkip("STORE_SHOTS=1")
        }
        for locale in ["en", "de"] {
            robot.launch(arguments: [
                "-\(locale)",
                "-clear",
                "-uiTesting",
                "-today=\(Self.today)",
                "-loadSample",
            ])
            for shot in Self.shots {
                shot.prepare(robot)
                robot.waitFor(id: shot.waitID, timeout: 15)
                try write(locale: locale, file: shot.file)
            }
        }
    }

    private static func selectTrendDot(_ robot: AppRobot) {
        robot.waitFor(id: "trends.plot", timeout: 8)
        let dots = robot.app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "trends.dot.hot_flash.")
        )
        var chosen: XCUIElement?
        var chosenID = ""
        for index in 0..<dots.count {
            let dot = dots.element(boundBy: index)
            let identifier = dot.identifier
            if identifier > chosenID {
                chosenID = identifier
                chosen = dot
            }
        }
        chosen?.tap()
    }

    private static func showMore(_ robot: AppRobot) {
        robot.waitFor(id: "more.lang.en")
        robot.waitFor(id: "more.sharePdf")
        robot.scrollTo("more.privacyPolicy")
        let footer = robot.app.staticTexts.matching(
            NSPredicate(
                format: "label CONTAINS %@ OR label CONTAINS %@",
                "not medical advice",
                "kein medizinischer Rat"
            )
        ).firstMatch
        let privacy = robot.element("more.privacyPolicy")
        let limit = tabTop(robot) - 4
        for _ in 0..<4 {
            let footerFrame = footer.frame
            let privacyFrame = privacy.frame
            let footerClear = footer.exists
                && footerFrame.height > 1
                && footerFrame.minY >= 0
                && footerFrame.maxY <= limit
            let privacyClear = privacyFrame.height > 1
                && privacyFrame.minY >= 0
                && privacyFrame.maxY <= limit
            if footerClear && privacyClear { return }
            let start = robot.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62))
            let end = robot.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }

    private static func tabTop(_ robot: AppRobot) -> CGFloat {
        let tab = robot.app.tabBars.firstMatch
        if tab.exists, tab.frame.minY > 1 {
            return tab.frame.minY
        }
        return robot.app.frame.height - 140
    }

    private func write(locale: String, file: String) throws {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        guard let image = UIImage(data: data)?.cgImage else {
            XCTFail("png \(locale)/\(file)")
            return
        }
        let accepted = (image.width == 1320 && image.height == 2868)
            || (image.width == 1290 && image.height == 2796)
        let directory = screenshotsRoot().appendingPathComponent(locale, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent(file), options: .atomic)
        XCTAssertTrue(accepted, "\(locale)/\(file) is \(image.width)x\(image.height)")
    }

    private func screenshotsRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/app-store/screenshots")
    }
}
