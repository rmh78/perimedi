import ObjectiveC
import XCTest

private func ignoringSnapshot(_ body: () -> Void) {
    let options = XCTExpectedFailure.Options()
    options.isStrict = false
    options.issueMatcher = { issue in
        let text = issue.compactDescription
        return text.contains("matching snapshot") || text.contains("kAXError")
    }
    XCTExpectFailure(options: options, failingBlock: body)
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

enum WidgetShell {
    static func prepare() {
        SpringboardIdleBypass.install()
        relaunchSpringBoard()
    }

    static func finish() {
        HomeWidgets().restoreAppIcon()
        SpringboardIdleBypass.restore()
    }

    static func recover() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if shellReady(springboard) { return }
        springboard.terminate()
        waitForShell(springboard)
    }

    /// Leave a running SpringBoard up; terminating it takes the shell down.
    private static func relaunchSpringBoard() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        switch springboard.state {
        case .runningForeground, .runningBackground:
            return
        case .notRunning:
            springboard.activate()
            waitForShell(springboard)
        default:
            springboard.terminate()
            waitForShell(springboard)
        }
    }

    private static func waitForShell(_ springboard: XCUIApplication) {
        let deadline = Date().addingTimeInterval(90)
        var stableSince: Date?
        while Date() < deadline {
            if shellReady(springboard) {
                let since = stableSince ?? Date()
                stableSince = since
                if Date().timeIntervalSince(since) >= 12 { return }
            } else {
                stableSince = nil
            }
            RunLoop.current.run(until: Date().addingTimeInterval(1))
        }
    }

    private static func shellReady(_ springboard: XCUIApplication) -> Bool {
        var ready = false
        ignoringSnapshot {
            let maps = springboard.icons.matching(
                NSPredicate(format: "identifier == 'Maps' OR identifier == 'Karten'")
            ).firstMatch
            let state = springboard.state
            let running = state == .runningForeground || state == .runningBackground
            ready = running && maps.exists
        }
        return ready
    }
}

enum WidgetFace { case icon, medium, small }

struct WidgetProof {
    let robot: AppRobot
    private let longName = "Estradiol gel morning dose"

    func run() {
        robot.launch(.widgetToday)
        dismissSystemAlert()

        let home = HomeWidgets()
        home.show(.medium)
        XCTAssertTrue(
            home.spin(8) { home.hasWidget },
            "icon did not become a widget. icons: \(home.iconLabels) buttons: \(home.buttonLabels)"
        )

        robot.app.activate()
        robot.addMedication(name: longName, dose: "1 mg", color: "#f472b6")
        robot.addMedication(name: "Progesterone", dose: "200 mg")
        robot.waitFor(id: "cycle.lane.estradiol-gel-morning-dose")
        robot.waitFor(id: "cycle.lane.progesterone")

        home.open()
        XCTAssertTrue(
            home.spin(20) {
                home.hasMed(longName) && home.hasMed("Progesterone") && home.hasTake && home.hasStillToTake
            },
            "rows, Take, or Still to take today missing. buttons: \(home.buttonLabels)"
        )
        home.tapTaken(beside: longName)
        XCTAssertTrue(
            home.spin(6) { home.hasCheck && home.hasStillToTake && home.hasMed("Progesterone") },
            "check beside the remaining row missing"
        )
        XCTAssertTrue(home.spin(15) { !home.hasMed(longName) }, "taken long name still on the widget")

        if robot.app.state != .runningForeground {
            robot.app.activate()
        }
        let status = "cycle.lane.estradiol-gel-morning-dose.status"
        robot.waitFor(id: "cycle.lane.estradiol-gel-morning-dose", timeout: 8)
        if robot.value(of: status) == "taken" {
            robot.tap("cycle.lane.estradiol-gel-morning-dose")
        }
        XCTAssertNotEqual(robot.value(of: status), "taken")
        home.open()
        XCTAssertTrue(home.spin(20) { home.hasMed(longName) }, "untaken long name did not return")

        home.tapTaken(beside: "Progesterone")
        XCTAssertTrue(
            home.spin(15) { !home.hasMed("Progesterone") && home.hasMed(longName) },
            "progesterone still on the widget"
        )
        home.show(.small)
        XCTAssertTrue(
            home.spin(8) { home.hasMed(longName) && home.hasTake && home.hasStillToTake },
            "small widget did not show the remaining dose"
        )
        home.tapTaken(beside: longName, direct: true)
        // The widget intent finishes on the Home Screen. Opening the app early
        // reads the lane before that write lands.
        var took = home.spin(8) { home.hasCheck || !home.hasMed(longName) }
        if !took {
            home.tapTaken(beside: longName)
            took = home.spin(8) { home.hasCheck || !home.hasMed(longName) }
        }
        if robot.app.state != .runningForeground {
            robot.app.activate()
        }
        let lane = "cycle.lane.estradiol-gel-morning-dose"
        robot.waitFor(id: lane, timeout: 8)
        XCTAssertEqual(robot.value(of: "\(lane).status"), "taken")
        home.open()
        let settled = {
            home.hasEmptyMessage && !home.hasMed(longName) && !home.hasMed("Progesterone")
        }
        if !home.spin(15, settled) {
            WidgetShell.recover()
            home.open()
        }
        XCTAssertTrue(home.spin(15, settled), "all-taken day did not show All taken for today")
        home.show(.icon)
        XCTAssertTrue(home.spin(8) { home.onScreenAppIcon }, "widget did not turn back into the app icon")
    }

    private func dismissSystemAlert() {
        let alert = robot.app.alerts.firstMatch
        guard alert.waitForExistence(timeout: 2) else { return }
        alert.buttons.firstMatch.tap()
    }
}

final class HomeWidgets {
    var springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    func open() {
        XCUIDevice.shared.press(.home)
        springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    }

    var hasWidget: Bool {
        onScreen(widgetIcon())
    }

    var onScreenAppIcon: Bool {
        onScreen(appIcon())
    }

    var buttonLabels: [String] {
        springboard.buttons.allElementsBoundByIndex.prefix(25).map(\.label)
    }

    var iconLabels: [String] {
        springboard.icons.allElementsBoundByIndex.prefix(20).map { "\($0.label)|\($0.identifier)" }
    }

    func show(_ face: WidgetFace, file: StaticString = #filePath, line: UInt = #line) {
        switch face {
        case .icon:
            restoreAppIcon()
        case .medium:
            open()
            revealPeriMedi()
            if onScreen(widgetIcon()), !onScreen(appIcon()) {
                openSizeMenu(on: widgetIcon())
                _ = tapLabel(Self.labels(.icon))
                _ = spin(6) { onScreen(appIcon()) }
            }
            guard spin(4, { onScreen(appIcon()) }) else {
                XCTFail(
                    "PeriMedi icon missing. icons: \(iconLabels) buttons: \(buttonLabels)",
                    file: file,
                    line: line
                )
                return
            }
            openSizeMenu(on: appIcon())
            XCTAssertTrue(
                tapLabel(Self.labels(.medium)),
                "Medium-sized widget missing. icons: \(iconLabels) buttons: \(buttonLabels)",
                file: file,
                line: line
            )
        case .small:
            open()
            revealPeriMedi()
            let target: XCUIElement
            if onScreen(widgetIcon()) {
                target = widgetIcon()
            } else if onScreen(appIcon()) {
                target = appIcon()
            } else {
                XCTFail(
                    "PeriMedi widget missing. icons: \(iconLabels) buttons: \(buttonLabels)",
                    file: file,
                    line: line
                )
                return
            }
            openSizeMenu(on: target)
            XCTAssertTrue(
                tapLabel(Self.labels(.small)),
                "Small widget missing. icons: \(iconLabels) buttons: \(buttonLabels)",
                file: file,
                line: line
            )
        }
    }

    func restoreAppIcon() {
        _ = tapLabel(["Abbrechen", "Cancel"], wait: 0.4)
        open()
        revealPeriMedi()
        for _ in 0..<3 {
            if onScreen(appIcon()) { return }
            if tapLabel(Self.labels(.icon), wait: 0.6), spin(5, { onScreen(appIcon()) }) { return }
            guard onScreen(widgetIcon()) else { return }
            openSizeMenu(on: widgetIcon())
            if tapLabel(Self.labels(.icon)), spin(6, { onScreen(appIcon()) }) { return }
            open()
            revealPeriMedi()
        }
    }

    func appIcon() -> XCUIElement {
        springboard.icons.matching(
            NSPredicate(format: "identifier == 'PeriMedi' AND NOT (value == 'Widget')")
        ).firstMatch
    }

    private func onScreen(_ element: XCUIElement) -> Bool {
        var frame = CGRect.null
        var screen = CGRect.null
        var matched = false
        ignoringSnapshot {
            guard element.exists else { return }
            frame = element.frame
            screen = springboard.frame
            matched = true
        }
        guard matched, frame.width > 8, frame.height > 8 else { return false }
        return screen.intersects(frame)
    }

    private func widgetIcon() -> XCUIElement {
        let predicate = NSPredicate(format: "identifier == 'PeriMedi' AND value == 'Widget'")
        let other = springboard.descendants(matching: .other).matching(predicate).firstMatch
        if other.exists { return other }
        let icon = springboard.icons.matching(predicate).firstMatch
        if icon.exists { return icon }
        return other
    }

    private static func labels(_ face: WidgetFace) -> [String] {
        switch face {
        case .small:
            return ["Small widget", "Small Widget", "Small", "Kleines Widget"]
        case .medium:
            return ["Medium-sized widget", "Medium Widget", "Medium", "Mittelgroßes Widget"]
        case .icon:
            return ["App icon", "App Icon", "App-Symbol"]
        }
    }

    private func revealPeriMedi() {
        // A failed SpringBoard snapshot is not "the widget is on another page".
        if spin(6, { visiblePeriMedi() }) { return }
        dragTowardNextPage()
        if spin(3, { visiblePeriMedi() }) { return }
        dragTowardFirstPage()
        dragTowardFirstPage()
        _ = spin(3, { visiblePeriMedi() })
    }

    private func visiblePeriMedi() -> Bool {
        onScreen(appIcon()) || onScreen(widgetIcon())
    }

    private func dragTowardFirstPage() {
        drag(from: 0.2, to: 0.85)
    }

    private func dragTowardNextPage() {
        drag(from: 0.85, to: 0.2)
    }

    private func drag(from startX: CGFloat, to endX: CGFloat) {
        let start = springboard.coordinate(withNormalizedOffset: CGVector(dx: startX, dy: 0.55))
        let end = springboard.coordinate(withNormalizedOffset: CGVector(dx: endX, dy: 0.55))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

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
        springboard.descendants(matching: .staticText)["All taken for today"].exists
    }

    var hasStillToTake: Bool {
        springboard.descendants(matching: .staticText)["Still to take today"].exists
    }

    var hasCheck: Bool {
        springboard.descendants(matching: .staticText)["✓"].exists
    }

    var hasTake: Bool {
        springboard.buttons["Take"].exists
    }

    func hasMed(_ name: String) -> Bool {
        springboard.descendants(matching: .staticText)[name].exists
    }

    func tapTaken(beside name: String? = nil, direct: Bool = false) {
        let deadline = Date().addingTimeInterval(8)
        let screen = springboard.frame
        var seen: [String] = []
        repeat {
            let buttons = springboard.buttons.matching(
                NSPredicate(format: "label == 'Take'")
            ).allElementsBoundByIndex
            seen = buttons.map { button in
                let frame = button.frame
                return "\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height))"
            }
            let visible = buttons.filter { capsule($0.frame, on: screen) }
            let chosen: XCUIElement?
            if let name {
                let label = springboard.descendants(matching: .staticText)[name]
                if label.exists {
                    let y = label.frame.midY
                    chosen = visible.min { abs($0.frame.midY - y) < abs($1.frame.midY - y) }
                } else {
                    chosen = nil
                }
            } else {
                chosen = visible.first
            }
            if let chosen {
                if direct {
                    chosen.tap()
                } else {
                    chosen.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        } while Date() < deadline
        XCTFail("Take missing. frames: \(seen) buttons: \(buttonLabels)")
    }

    private func capsule(_ frame: CGRect, on screen: CGRect) -> Bool {
        frame.width > 20 && frame.width < screen.width * 0.5
            && frame.height > 16 && frame.height < 64
            && screen.intersects(frame)
    }

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
