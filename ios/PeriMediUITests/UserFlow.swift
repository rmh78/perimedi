import ObjectiveC
import XCTest

struct UserFlow {
    let robot: AppRobot

    func run() {
        robot.launch(.userFlow)
        robot.waitFor(id: "cycle.empty.meds")
        XCTAssertTrue(robot.value(of: "cycle.empty.meds").contains("need-med"))

        robot.addMedication(name: "Estrogen", dose: "1 mg")
        let lane = "cycle.lane.estrogen"
        let status = "\(lane).status"
        robot.waitFor(id: lane)

        logOnePeriod()
        logOneSymptom()

        robot.tap("tab.month")
        robot.waitFor(id: "month.day.\(UITestDate.deviceToday)")

        robot.tap("tab.trends")
        robot.waitFor(id: "trends.status")

        robot.tap("tab.more")
        robot.scrollTo("more.sharePdf")
        robot.tap("more.sharePdf")
        robot.waitFor(id: "visit.range")
        robot.tap("visit.range.continue")
        robot.waitFor(id: "visit.pdf.preview")
        robot.waitFor(id: "visit.pdf.share")
        robot.tap("sheet.close")
        robot.waitGone(id: "visit.pdf.preview")
        robot.tap("tab.cycle")
        robot.waitFor(id: lane)

        let home = HomeScreen()
        home.installMediumAndTake()
        robot.app.activate()
        robot.waitFor(id: lane)
        XCTAssertTrue(
            robot.spin(timeout: 4) { robot.value(of: status) == "taken" },
            "after widget Take, \(status) is \(robot.value(of: status))"
        )
    }

    private func logOnePeriod() {
        robot.tap("cycle.action.period")
        robot.waitFor(id: "sheet.period")
        if !robot.exists("period.add") {
            robot.app.swipeUp()
        }
        robot.tap("period.add")
        robot.tap("period.save")
        robot.waitFor(id: "period.add")
        robot.tap("sheet.close")
        robot.waitGone(id: "sheet.period")
    }

    private func logOneSymptom() {
        robot.tap("cycle.action.symptom")
        robot.waitFor(id: "sheet.symptom")
        robot.tap("symptom.score.hot_flash.3")
        robot.tap("sheet.close")
        robot.waitGone(id: "sheet.symptom")
        robot.waitFor(id: "cycle.chip.score.hot_flash")
    }

}

enum SpringboardIdleBypass {
    private static var saved: [(AnyClass, Selector, IMP)] = []

    static func install() {
        guard saved.isEmpty else { return }
        let skip: @convention(block) (AnyObject) -> Bool = { _ in true }
        let skipImp = imp_implementationWithBlock(skip)
        if let process = NSClassFromString("XCUIApplicationProcess") {
            replace(process, ["shouldSkipPreEventQuiescence", "shouldSkipPostEventQuiescence"], skipImp)
        }
        let noop: @convention(block) (AnyObject) -> Void = { _ in }
        replace(XCUIApplication.self, ["_waitForQuiescence"], imp_implementationWithBlock(noop))
        let noopBool: @convention(block) (AnyObject, Bool) -> Void = { _, _ in }
        replace(XCUIApplication.self, ["_waitForQuiescenceAsPreEvent:"], imp_implementationWithBlock(noopBool))
    }

    static func restore() {
        for (cls, selector, imp) in saved {
            if let method = class_getInstanceMethod(cls, selector) {
                method_setImplementation(method, imp)
            }
        }
        saved.removeAll()
    }

    private static func replace(_ cls: AnyClass, _ names: [String], _ imp: IMP) {
        for name in names {
            let selector = NSSelectorFromString(name)
            guard let method = class_getInstanceMethod(cls, selector) else { continue }
            saved.append((cls, selector, method_getImplementation(method)))
            method_setImplementation(method, imp)
        }
    }
}

/// SpringBoard queries stay on `icons` and `buttons`.
/// `descendants(matching: .other)` walked into the new widget process and the server returned `kAXErrorServerNotFound`.
final class HomeScreen {
    private var springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    static func prepare() {
        SpringboardIdleBypass.install()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        switch springboard.state {
        case .runningForeground, .runningBackground:
            return
        default:
            springboard.activate()
        }
    }

    func installMediumAndTake() {
        XCUIDevice.shared.press(.home)
        rebind()
        let icon = appIcon()
        XCTAssertTrue(ready(icon, timeout: 4), "PeriMedi icon missing")
        longPress(icon)
        let medium = waitButton(["Medium-sized widget", "Mittelgroßes Widget"], timeout: 4)
        tapCenter(medium)
        let take = waitButton(["Take", "Nehmen"], timeout: 8)
        tapCenter(take)
    }

    func restoreIcon() {
        XCUIDevice.shared.press(.home)
        rebind()
        if ready(appIcon(), timeout: 2) { return }
        let widget = widgetIcon()
        guard ready(widget, timeout: 2) else { return }
        longPress(widget)
        let chip = waitButton(["App icon", "App-Symbol"], timeout: 4)
        tapCenter(chip)
    }

    private func rebind() {
        springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    }

    private func appIcon() -> XCUIElement {
        springboard.icons.matching(
            NSPredicate(format: "identifier == 'PeriMedi' AND NOT (value == 'Widget')")
        ).firstMatch
    }

    private func widgetIcon() -> XCUIElement {
        springboard.icons.matching(
            NSPredicate(format: "identifier == 'PeriMedi' AND value == 'Widget'")
        ).firstMatch
    }

    private func waitButton(_ labels: [String], timeout: TimeInterval) -> XCUIElement {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            for label in labels {
                let button = springboard.buttons[label]
                if button.exists, button.frame.width > 8 { return button }
            }
            if Date() >= deadline { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTFail("missing \(labels.joined(separator: ", "))")
        return springboard.buttons[labels[0]]
    }

    private func ready(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            if element.exists, element.frame.width > 8 { return true }
            if Date() >= deadline { return false }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private func longPress(_ element: XCUIElement) {
        let frame = element.frame
        let screen = springboard.frame
        let dx = (frame.midX - screen.minX) / screen.width
        let dy = (frame.midY - screen.minY) / screen.height
        guard dx.isFinite, dy.isFinite, (0...1).contains(dx), (0...1).contains(dy) else {
            element.press(forDuration: 1.0)
            return
        }
        springboard.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: dy)).press(forDuration: 1.0)
    }

    private func tapCenter(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
