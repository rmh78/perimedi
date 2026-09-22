import ObjectiveC
import XCTest

private enum SpringboardIdleBypass {
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

/// Home Screen widget: Taken drops a medication, un-take on Cycle brings it
/// back, and an all-taken day shows the empty message.
final class WidgetJourneyTests: PeriMediUITestCase {
    override func setUp() {
        super.setUp()
        SpringboardIdleBypass.install()
        executionTimeAllowance = 180
    }

    override func tearDown() {
        HomeWidgets().restoreAppIcon()
        SpringboardIdleBypass.restore()
        super.tearDown()
    }

    func testWidgetTakenUntakenAndEmptyMessage() {
        robot.launch(today: UITestDate.deviceToday)
        dismissSystemAlert()

        let home = HomeWidgets()
        home.open()
        home.ensureAppIcon()
        home.turnIconIntoWidget()
        guard home.spin(8, { home.hasWidget }) else {
            XCTFail("icon did not become a widget. icons: \(home.iconLabels) buttons: \(home.buttonLabels)")
            return
        }

        robot.app.activate()
        robot.addMedication(name: "Estrogen", dose: "1 mg")
        robot.addMedication(name: "Progesterone", dose: "200 mg")
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

    var iconLabels: [String] {
        springboard.icons.allElementsBoundByIndex.prefix(20).map { "\($0.label)|\($0.identifier)" }
    }

    /// Puts the PeriMedi app icon back. Does not fail the test. Safe to call twice, and from tearDown after an error.
    func restoreAppIcon() {
        _ = tapLabel(["Abbrechen", "Cancel"], wait: 0.4)
        open()
        for _ in 0..<3 {
            if onScreen(appIcon()) { return }
            if !onScreen(widgetIcon()) {
                dragTowardFirstPage()
            }
            if onScreen(appIcon()) { return }
            if tapLabel(Self.appIconLabels, wait: 0.6), spin(5, { onScreen(appIcon()) }) { return }
            guard onScreen(widgetIcon()) else { continue }
            openSizeMenu(on: widgetIcon())
            if tapLabel(Self.appIconLabels), spin(6, { onScreen(appIcon()) }) { return }
            open()
        }
    }

    func ensureAppIcon() {
        if !spin(2, { onScreen(appIcon()) || onScreen(widgetIcon()) }) {
            dragTowardFirstPage()
        }
        XCTAssertTrue(
            spin(6) { onScreen(appIcon()) || onScreen(widgetIcon()) },
            "PeriMedi is not on the first Home Screen page. icons: \(iconLabels) buttons: \(buttonLabels)"
        )
        guard spin(2, { onScreen(widgetIcon()) && !onScreen(appIcon()) }) else { return }
        openSizeMenu(on: widgetIcon())
        XCTAssertTrue(tapLabel(Self.appIconLabels), "App-Symbol missing. icons: \(iconLabels) buttons: \(buttonLabels)")
        XCTAssertTrue(
            spin(8) { onScreen(appIcon()) },
            "App-Symbol did not restore the PeriMedi icon. icons: \(iconLabels) buttons: \(buttonLabels)"
        )
    }

    func turnIconIntoWidget() {
        XCTAssertTrue(spin(4) { onScreen(appIcon()) }, "PeriMedi icon missing")
        openSizeMenu(on: appIcon())
        XCTAssertTrue(tapLabel(Self.widgetSizeLabels), "widget size missing. icons: \(iconLabels) buttons: \(buttonLabels)")
    }

    func turnWidgetIntoIcon() {
        restoreAppIcon()
        XCTAssertTrue(
            spin(4) { onScreen(appIcon()) },
            "widget did not turn back into the app icon. icons: \(iconLabels) buttons: \(buttonLabels)"
        )
    }

    private func dragTowardFirstPage() {
        let start = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.55))
        let end = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.55))
        start.press(forDuration: 0.05, thenDragTo: end)
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
        let frame = target.frame
        let screen = springboard.frame
        let dx = (frame.midX - screen.minX) / screen.width
        let dy = (frame.midY - screen.minY) / screen.height
        guard dx.isFinite, dy.isFinite, (0...1).contains(dx), (0...1).contains(dy) else {
            target.press(forDuration: 1.0)
            return
        }
        springboard.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: dy)).press(forDuration: 1.0)
    }

    private func tapLabel(_ labels: [String], wait: TimeInterval = 4) -> Bool {
        let deadline = Date().addingTimeInterval(wait)
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
            let screen = springboard.frame
            guard frame.origin.x.isFinite, frame.origin.y.isFinite,
                  frame.width > 8, frame.width.isFinite,
                  frame.height > 8, frame.height.isFinite,
                  screen.width > 8, screen.height > 8
            else { continue }
            let dx = (frame.midX - screen.minX) / screen.width
            let dy = (frame.midY - screen.minY) / screen.height
            guard dx.isFinite, dy.isFinite, (0...1).contains(dx), (0...1).contains(dy) else { continue }
            springboard.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: dy)).tap()
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
