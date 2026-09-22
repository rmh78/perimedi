import ObjectiveC
import XCTest

private let skipSpringboardIdle: Void = {
    let skip: @convention(block) (AnyObject) -> Bool = { _ in true }
    let skipImp = imp_implementationWithBlock(skip)
    if let process = NSClassFromString("XCUIApplicationProcess") {
        for name in ["shouldSkipPreEventQuiescence", "shouldSkipPostEventQuiescence"] {
            let selector = NSSelectorFromString(name)
            if let method = class_getInstanceMethod(process, selector) {
                method_setImplementation(method, skipImp)
            }
        }
    }
    let noop: @convention(block) (AnyObject) -> Void = { _ in }
    let noopImp = imp_implementationWithBlock(noop)
    for name in ["_waitForQuiescence", "_waitForQuiescenceAsPreEvent:"] {
        let selector = NSSelectorFromString(name)
        if let method = class_getInstanceMethod(XCUIApplication.self, selector) {
            method_setImplementation(method, noopImp)
        }
    }
}()

/// Home Screen widget: Taken drops a medication, un-take on Cycle brings it
/// back, and an all-taken day shows the empty message.
final class WidgetJourneyTests: PeriMediUITestCase {
    override func setUp() {
        super.setUp()
        _ = skipSpringboardIdle
        executionTimeAllowance = 4
    }

    func testWidgetTakenUntakenAndEmptyMessage() {
        robot.launch()
        dismissSystemAlert()

        let home = HomeWidgets()
        home.open()
        home.ensureAppIcon()
        home.turnIconIntoWidget()
        defer { home.turnWidgetIntoIcon() }
        guard home.spin(8, { home.hasWidget }) else {
            XCTFail("icon did not become a widget. buttons: \(home.buttonLabels)")
            return
        }

        robot.app.activate()
        robot.addMedication(name: "Estrogen", dose: "1 mg", start: UITestDate.periodStart)
        robot.addMedication(name: "Progesterone", dose: "200 mg", start: UITestDate.periodStart)
        robot.waitFor(id: "cycle.lane.estrogen")
        robot.waitFor(id: "cycle.lane.progesterone")
        XCTAssertNotEqual(robot.value(of: "cycle.lane.estrogen.status"), "taken")

        home.open()
        XCTAssertTrue(home.spin(15, { home.hasMed("Estrogen") }), "estrogen missing on the widget")

        home.tapTaken()
        robot.waitFor(id: "tab.cycle", timeout: 8)
        home.open()
        XCTAssertTrue(home.spin(15, { !home.hasMed("Estrogen") }), "taken estrogen still on the widget")
        XCTAssertTrue(home.spin(15, { home.hasMed("Progesterone") }), "progesterone missing after estrogen was taken")

        robot.app.activate()
        robot.waitFor(id: "cycle.lane.estrogen")
        if robot.value(of: "cycle.lane.estrogen.status") == "taken" {
            robot.tap("cycle.lane.estrogen")
        }
        XCTAssertNotEqual(robot.value(of: "cycle.lane.estrogen.status"), "taken")
        home.open()
        XCTAssertTrue(home.spin(20) { home.hasMed("Estrogen") }, "untaken estrogen did not return")

        robot.app.activate()
        markTaken("estrogen")
        markTaken("progesterone")
        home.open()
        XCTAssertTrue(
            home.spin(20) {
                home.hasEmptyMessage && !home.hasMed("Estrogen") && !home.hasMed("Progesterone")
            },
            "all-taken day did not show the empty message"
        )
        home.turnWidgetIntoIcon()
        XCTAssertTrue(home.appIcon().exists, "widget did not turn back into the app icon")
    }

    private func markTaken(_ slug: String) {
        let status = "cycle.lane.\(slug).status"
        robot.waitFor(id: status)
        if robot.value(of: status) == "taken" { return }
        robot.tap("cycle.lane.\(slug)")
        XCTAssertEqual(robot.value(of: status), "taken")
    }

    private func dismissSystemAlert() {
        let alert = robot.app.alerts.firstMatch
        guard alert.waitForExistence(timeout: 2) else { return }
        alert.buttons.firstMatch.tap()
    }
}

private final class HomeWidgets {
    var springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    func open() {
        XCUIDevice.shared.press(.home)
        springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    }

    var hasWidget: Bool {
        onScreen(widgetIcon())
    }

    var buttonLabels: [String] {
        springboard.buttons.allElementsBoundByIndex.prefix(25).map(\.label)
    }

    func ensureAppIcon() {
        XCTAssertTrue(
            spin(8) { onScreen(appIcon()) || onScreen(widgetIcon()) },
            "PeriMedi is not on the current Home Screen page. buttons: \(buttonLabels)"
        )
        guard onScreen(widgetIcon()), !onScreen(appIcon()) else { return }
        openSizeMenu(on: widgetIcon())
        XCTAssertTrue(tapLabel(Self.appIconLabels), "App-Symbol missing. buttons: \(buttonLabels)")
        XCTAssertTrue(
            spin(8) { onScreen(appIcon()) },
            "App-Symbol did not restore the PeriMedi icon. buttons: \(buttonLabels)"
        )
    }

    func turnIconIntoWidget() {
        let icon = appIcon()
        XCTAssertTrue(onScreen(icon), "PeriMedi icon missing")
        openSizeMenu(on: icon)
        XCTAssertTrue(tapLabel(Self.widgetSizeLabels), "widget size missing. buttons: \(buttonLabels)")
    }

    func turnWidgetIntoIcon() {
        guard onScreen(widgetIcon()) else { return }
        openSizeMenu(on: widgetIcon())
        XCTAssertTrue(tapLabel(Self.appIconLabels), "App-Symbol missing. buttons: \(buttonLabels)")
        XCTAssertTrue(
            spin(8) { onScreen(appIcon()) },
            "widget did not turn back into the app icon. buttons: \(buttonLabels)"
        )
    }

    func appIcon() -> XCUIElement {
        springboard.icons.matching(
            NSPredicate(format: "identifier == 'PeriMedi' AND NOT (value == 'Widget')")
        ).firstMatch
    }

    private func onScreen(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        return frame.width > 8 && frame.height > 8 && springboard.frame.intersects(frame)
    }

    private func widgetIcon() -> XCUIElement {
        springboard.icons.matching(
            NSPredicate(format: "identifier == 'PeriMedi' AND value == 'Widget'")
        ).firstMatch
    }

    private static let widgetSizeLabels = ["Mittelgroßes Widget", "Medium Widget", "Medium"]
    private static let appIconLabels = ["App-Symbol", "App Icon"]

    private func openSizeMenu(on target: XCUIElement) {
        target.press(forDuration: 1.0)
    }

    private func tapLabel(_ labels: [String]) -> Bool {
        let deadline = Date().addingTimeInterval(4)
        repeat {
            if tapFirst(labels: labels) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
        return false
    }

    var hasEmptyMessage: Bool {
        labeled(["Nothing to take today", "Heute nichts zu nehmen"])
    }

    func hasMed(_ name: String) -> Bool {
        springboard.descendants(matching: .staticText)[name].exists
    }

    func tapTaken() {
        let buttons = springboard.buttons.matching(
            NSPredicate(format: "label == 'Taken' OR label == 'Genommen'")
        ).allElementsBoundByIndex
        let screen = springboard.frame
        let visible = buttons.first { button in
            let frame = button.frame
            return frame.width > 20 && screen.intersects(frame)
        }
        XCTAssertNotNil(visible, "Taken missing")
        visible?.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func labeled(_ names: [String]) -> Bool {
        names.contains { springboard.descendants(matching: .staticText)[$0].exists }
    }

    @discardableResult
    private func tapFirst(labels: [String]) -> Bool {
        for label in labels {
            let match = springboard.descendants(matching: .any)[label].firstMatch
            guard match.exists else { continue }
            let frame = match.frame
            guard frame.width > 8, frame.height > 8 else { continue }
            match.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            return true
        }
        return false
    }

    func spin(_ timeout: TimeInterval, _ predicate: () -> Bool) -> Bool {
        if predicate() { return true }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            if predicate() { return true }
        }
        return predicate()
    }
}
