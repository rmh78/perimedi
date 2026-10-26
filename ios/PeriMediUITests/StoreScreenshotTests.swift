import UIKit
import XCTest

struct FramePixels: Equatable {
    let width: Int
    let height: Int
}

enum StoreOutputError: Error {
    case missingFrameSpec
    case badDirectory
    case badFrame
    case screenshotsFolderClosed
}

struct StoreOutput {
    let directoryName: String
    let accepted: [FramePixels]

    private init(directoryName: String, accepted: [FramePixels]) {
        self.directoryName = directoryName
        self.accepted = accepted
    }

    static func parse(_ environment: [String: String]) throws -> StoreOutput {
        guard let rawDirectory = environment["STORE_DIR"], !rawDirectory.isEmpty,
              let rawFrame = environment["STORE_FRAME"], !rawFrame.isEmpty else {
            throw StoreOutputError.missingFrameSpec
        }
        let parts = rawDirectory.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 1 else { throw StoreOutputError.badDirectory }
        let name = String(parts[0])
        guard name != ".", name != ".." else { throw StoreOutputError.badDirectory }
        let tokens = rawFrame.split(separator: "+", omittingEmptySubsequences: false)
        var accepted: [FramePixels] = []
        for token in tokens {
            guard let pixels = framePixels(token) else { throw StoreOutputError.badFrame }
            if accepted.contains(pixels) { throw StoreOutputError.badFrame }
            accepted.append(pixels)
        }
        guard !accepted.isEmpty else { throw StoreOutputError.badFrame }
        if name == "screenshots" {
            let closed = [
                FramePixels(width: 1320, height: 2868),
                FramePixels(width: 1290, height: 2796),
            ]
            guard accepted.allSatisfy({ closed.contains($0) }) else {
                throw StoreOutputError.screenshotsFolderClosed
            }
        }
        return StoreOutput(directoryName: name, accepted: accepted)
    }

    private static func framePixels(_ token: Substring) -> FramePixels? {
        let parts = token.split(separator: "x", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        guard parts[0].allSatisfy(\.isNumber), parts[1].allSatisfy(\.isNumber) else { return nil }
        guard let width = Int(parts[0]), let height = Int(parts[1]), width > 0, height > 0 else {
            return nil
        }
        return FramePixels(width: width, height: height)
    }
}

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
        let output = try StoreOutput.parse(ProcessInfo.processInfo.environment)
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
                try write(locale: locale, file: shot.file, output: output)
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

    private func write(locale: String, file: String, output: StoreOutput) throws {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        guard let image = UIImage(data: data)?.cgImage else {
            XCTFail("png \(locale)/\(file)")
            return
        }
        let pixels = FramePixels(width: image.width, height: image.height)
        guard output.accepted.contains(pixels) else {
            XCTFail("\(locale)/\(file) is \(image.width)x\(image.height)")
            return
        }
        let directory = storeRoot(output.directoryName).appendingPathComponent(locale, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent(file), options: .atomic)
    }

    private func storeRoot(_ directoryName: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/app-store")
            .appendingPathComponent(directoryName, isDirectory: true)
    }
}
