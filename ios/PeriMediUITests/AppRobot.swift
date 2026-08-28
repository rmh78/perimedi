import XCTest

enum UITestDate {
    static let today = "2026-03-15"
    static let yesterday = "2026-03-14"
    static let tomorrow = "2026-03-16"
    static let periodStart = "2026-03-07"
    static let periodEnd = "2026-03-11"
}

class PeriMediUITestCase: XCTestCase {
    let robot = AppRobot()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        if let run = testRun, run.failureCount > 0 || run.unexpectedExceptionCount > 0 {
            let shot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: shot)
            attachment.lifetime = .keepAlways
            attachment.name = "failure-\(name)"
            add(attachment)
        }
        super.tearDown()
    }
}

struct AppRobot {
    let app = XCUIApplication()

    func launch(extra: [String] = []) {
        XCTAssertFalse(
            ["-journeyStep", "-loadSample"].contains { flag in
                app.launchArguments.contains(where: { $0.hasPrefix(flag) })
            }
        )
        XCTAssertFalse(extra.contains { $0.hasPrefix("-journeyStep") })
        XCTAssertFalse(extra.contains { $0.hasPrefix("-loadSample") })
        app.launchArguments = ["-en", "-clear", "-today=\(UITestDate.today)", "-uiTesting"] + extra
        XCTAssertFalse(app.launchArguments.contains { $0.hasPrefix("-journeyStep") })
        XCTAssertFalse(app.launchArguments.contains { $0.hasPrefix("-loadSample") })
        app.launch()
        waitFor(id: "tab.cycle")
        waitFor(id: "cycle.action.med")
    }

    func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// `waitForExistence` polls about once a second, so already-visible
    /// controls still cost ~1s each. Spin on `.exists` instead.
    @discardableResult
    private func spin(timeout: TimeInterval, _ predicate: () -> Bool) -> Bool {
        if predicate() { return true }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            if predicate() { return true }
        }
        return predicate()
    }

    func waitFor(id: String, timeout: TimeInterval = 3, file: StaticString = #filePath, line: UInt = #line) {
        let el = element(id)
        XCTAssertTrue(spin(timeout: timeout) { el.exists }, "missing \(id)", file: file, line: line)
    }

    func waitGone(id: String, timeout: TimeInterval = 2, file: StaticString = #filePath, line: UInt = #line) {
        let el = element(id)
        XCTAssertTrue(spin(timeout: timeout) { !el.exists }, "still present \(id)", file: file, line: line)
    }

    func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        waitFor(id: id, file: file, line: line)
        let el = element(id)
        if !el.isHittable {
            dismissKeyboard()
        }
        if el.isHittable {
            el.tap()
            return
        }
        el.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func value(of id: String) -> String {
        let el = element(id)
        if let raw = el.value as? String, !raw.isEmpty { return raw }
        return el.label
    }

    func exists(_ id: String) -> Bool {
        element(id).exists
    }

    func setDateKey(_ id: String, _ key: String, file: StaticString = #filePath, line: UInt = #line) {
        waitFor(id: id, file: file, line: line)
        element(id).tap()
        let picker = app.datePickers.firstMatch
        XCTAssertTrue(spin(timeout: 2) { picker.exists }, "date chooser for \(id)", file: file, line: line)
        XCTAssertTrue(
            tapDateChooserDay(picker, key: key),
            "day \(key) in chooser",
            file: file,
            line: line
        )
        let done = element("date.done")
        if spin(timeout: 1) { done.exists } {
            done.tap()
        }
        waitGone(id: "date.done", timeout: 2, file: file, line: line)
        let el = element(id)
        XCTAssertTrue(spin(timeout: 2) { el.exists }, "\(id) after date chooser", file: file, line: line)
        let shown = ((el.value as? String) ?? "") + el.label
        XCTAssertTrue(shown.contains(key), "\(id) is \(shown.debugDescription), wanted \(key)", file: file, line: line)
    }

    private func tapDateChooserDay(_ picker: XCUIElement, key: String) -> Bool {
        guard let date = dateFromKey(key) else { return false }
        let cal = Calendar(identifier: .gregorian)
        let day = cal.component(.day, from: date)
        var needles: [String] = []
        for template in ["EEEE, MMMM d, yyyy", "MMMM d, yyyy", "MMMM d,", "MMMM d", "d MMMM"] {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US")
            f.calendar = cal
            f.timeZone = TimeZone.current
            f.dateFormat = template
            needles.append(f.string(from: date))
        }
        let anyDay = picker.descendants(matching: .any)["\(day)"]
        if spin(timeout: 0.6) { anyDay.exists } {
            anyDay.tap()
            return true
        }
        for needle in needles {
            let match = picker.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS[c] %@", needle)
            ).firstMatch
            if match.exists {
                match.tap()
                return true
            }
        }
        let dayButton = picker.buttons["\(day)"]
        if dayButton.exists {
            dayButton.tap()
            return true
        }
        return false
    }

    private func dateFromKey(_ key: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: key)
    }

    /// Simulator `typeText` can drop characters when XCTest waits on interrupting
    /// elements (CI: `med.name` became "Es" instead of "Estrogen"). Retry on the
    /// same keyboard path. Do not paste: that is not how a user types.
    func clearAndType(_ id: String, _ text: String, file: StaticString = #filePath, line: UInt = #line) {
        waitFor(id: id, file: file, line: line)
        let field = element(id)

        func shown() -> String {
            ((field.value as? String) ?? field.label)
                .replacingOccurrences(of: "YYYY-MM-DD", with: "")
        }

        func focus() {
            if !field.isHittable {
                dismissKeyboard()
            }
            field.tap()
            _ = spin(timeout: 0.6) { app.keyboards.firstMatch.exists }
        }

        func clear() {
            let current = shown()
            guard !current.isEmpty else { return }
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 1))
        }

        for _ in 0..<4 {
            if shown() == text { break }
            focus()
            clear()
            field.typeText(text)
            if spin(timeout: 1) { shown() == text } { break }
        }

        let written = shown()
        XCTAssertTrue(
            written == text,
            "\(id) is \(written.debugDescription), wanted \(text)",
            file: file,
            line: line
        )
        dismissKeyboard()
    }

    func dismissKeyboard() {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        for title in ["sheet.symptom", "sheet.med", "sheet.period"] {
            if element(title).exists {
                element(title).tap()
                _ = spin(timeout: 1) { !keyboard.exists }
                return
            }
        }
        if keyboard.buttons["Return"].exists {
            keyboard.buttons["Return"].tap()
            _ = spin(timeout: 1) { !keyboard.exists }
        }
    }

    func closeSheet(id: String) {
        tap("sheet.close")
        waitGone(id: id)
    }

    func addPeriod(start: String = UITestDate.periodStart, end: String = UITestDate.periodEnd) {
        tap("cycle.action.period")
        waitFor(id: "sheet.period")
        if !element("period.add").exists {
            app.swipeUp()
        }
        tap("period.add")
        setDateKey("period.start", start)
        setDateKey("period.end", end)
        tap("period.save")
        closeSheet(id: "sheet.period")
    }

    func addMedication(
        name: String,
        dose: String,
        form: String? = nil,
        cyclic: Bool = false,
        start: String? = nil
    ) {
        tap("cycle.action.med")
        waitFor(id: "sheet.med")
        clearAndType("med.name", name)
        if let form {
            pick("med.form", form)
        }
        clearAndType("med.dose", dose)
        pick("med.mode", cyclic ? "med.mode.cyclic" : "med.mode.everyday")
        if let start {
            setDateKey("med.start", start)
        }
        tap("med.save")
        waitGone(id: "sheet.med")
    }

    func pick(_ id: String, _ option: String) {
        tap(id)
        let byId = element(option)
        if spin(timeout: 1.5) { byId.exists } {
            byId.tap()
            return
        }
        let menuChoice = app.collectionViews.buttons[option]
        if spin(timeout: 1.5) { menuChoice.exists } {
            menuChoice.tap()
            return
        }
        let other = app.buttons.matching(
            NSPredicate(format: "label == %@ AND identifier != %@", option, id)
        ).firstMatch
        if spin(timeout: 1) { other.exists } {
            other.tap()
            return
        }
        let any = app.descendants(matching: .any)[option]
        if spin(timeout: 1) { any.exists } {
            any.tap()
        }
    }

    func addSymptom(
        hotFlash: Int = 3,
        sleep: Int = 2,
        joints: Int = 1
    ) {
        tap("cycle.action.symptom")
        waitFor(id: "sheet.symptom")
        tap("symptom.score.hot_flash.\(hotFlash)")
        tap("symptom.score.sleep.\(sleep)")
        tap("symptom.score.joints.\(joints)")
        tap("sheet.close")
        waitGone(id: "sheet.symptom", timeout: 3)
    }

    /// Sheet bodies scroll; XCTest `isHittable` is false for rows below the fold.
    private func reveal(_ id: String) {
        for _ in 0..<6 {
            if element(id).isHittable { return }
            app.swipeUp()
        }
    }
}
