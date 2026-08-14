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

    func launch() {
        XCTAssertFalse(
            ["-journeyStep", "-loadSample"].contains { flag in
                app.launchArguments.contains(where: { $0.hasPrefix(flag) })
            }
        )
        app.launchArguments = ["-en", "-clear", "-today=\(UITestDate.today)"]
        XCTAssertFalse(app.launchArguments.contains { $0.hasPrefix("-journeyStep") })
        XCTAssertFalse(app.launchArguments.contains { $0.hasPrefix("-loadSample") })
        app.launch()
        waitFor(id: "tab.cycle")
        waitFor(id: "cycle.action.med")
    }

    func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func waitFor(id: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        let el = element(id)
        XCTAssertTrue(el.waitForExistence(timeout: timeout), "missing \(id)", file: file, line: line)
    }

    func waitGone(id: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        let el = element(id)
        if !el.exists { return }
        let expired = Date().addingTimeInterval(timeout)
        while el.exists, Date() < expired {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertFalse(el.exists, "still present \(id)", file: file, line: line)
    }

    func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        waitFor(id: id, file: file, line: line)
        element(id).tap()
    }

    func value(of id: String) -> String {
        let el = element(id)
        if let raw = el.value as? String, !raw.isEmpty { return raw }
        return el.label
    }

    func exists(_ id: String) -> Bool {
        element(id).waitForExistence(timeout: 2)
    }

    func clearAndType(_ id: String, _ text: String, file: StaticString = #filePath, line: UInt = #line) {
        waitFor(id: id, file: file, line: line)
        let field = element(id)
        // Focus first so the sheet scrolls the field on-screen.
        field.tap()
        // Then put the caret at the end. A mid-field tap leaves the last
        // digits of a pre-filled date (e.g. today) in place.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 32))
        field.typeText(text)
        let written = ((field.value as? String) ?? field.label)
            .replacingOccurrences(of: "YYYY-MM-DD", with: "")
        XCTAssertTrue(
            written == text || written.hasPrefix(text),
            "\(id) is \(written.debugDescription), wanted \(text)",
            file: file,
            line: line
        )
        dismissKeyboard()
    }

    func dismissKeyboard() {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        if keyboard.buttons["Return"].exists {
            keyboard.buttons["Return"].tap()
        } else if keyboard.buttons["Done"].exists {
            keyboard.buttons["Done"].tap()
        }
    }

    func closeSheet(id: String) {
        tap("sheet.close")
        waitGone(id: id)
    }

    func addPeriod(start: String = UITestDate.periodStart, end: String = UITestDate.periodEnd) {
        tap("cycle.action.period")
        waitFor(id: "sheet.period")
        tap("period.add")
        clearAndType("period.start", start)
        clearAndType("period.end", end)
        tap("period.save")
        closeSheet(id: "sheet.period")
    }

    func addMedication(
        name: String,
        dose: String,
        form: String? = nil,
        cyclicPreset: String? = nil,
        start: String? = nil
    ) {
        tap("cycle.action.med")
        waitFor(id: "sheet.med")
        clearAndType("med.name", name)
        if let form {
            pick("med.form", form)
        }
        clearAndType("med.dose", dose)
        if let cyclicPreset {
            tap("med.mode.cyclic")
            pick("med.preset", cyclicPreset)
        } else {
            tap("med.mode.everyday")
        }
        if let start {
            clearAndType("med.start", start)
        }
        tap("med.save")
        waitGone(id: "sheet.med")
    }

    func pick(_ id: String, _ option: String) {
        tap(id)
        let button = app.buttons[option]
        if button.waitForExistence(timeout: 3) {
            button.tap()
            return
        }
        let any = app.descendants(matching: .any)[option]
        if any.waitForExistence(timeout: 3) {
            any.tap()
        }
    }

    func addSymptom(_ body: String) {
        tap("cycle.action.symptom")
        waitFor(id: "sheet.symptom")
        clearAndType("symptom.body", body)
        tap("symptom.save")
        closeSheet(id: "sheet.symptom")
    }
}
