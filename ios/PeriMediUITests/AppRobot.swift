import XCTest

enum UITestDate {
    static let today = "2026-03-15"
    static let yesterday = "2026-03-14"
    static let tomorrow = "2026-03-16"
    static let periodStart = "2026-03-07"
    static let periodEnd = "2026-03-11"

    static var deviceToday: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

/// Never `-journeyStep` or `-loadSample`.
/// `widgetToday` uses the device date; the widget shows rows only when that date matches.
enum JourneyLaunch: Equatable {
    case pinnedRemindIn(seconds: Int)
    case trendsChart
    case trendsNoScores
    case widgetToday

    var arguments: [String] {
        let base = ["-en", "-clear", "-uiTesting", "-today=\(pinnedDay)"]
        switch self {
        case .pinnedRemindIn(let seconds):
            return base + ["-remindIn=\(seconds)"]
        case .trendsChart:
            return base + ["-fixture=trends"]
        case .trendsNoScores:
            return base + ["-fixture=trends-noscores"]
        case .widgetToday:
            return base
        }
    }

    private var pinnedDay: String {
        switch self {
        case .widgetToday:
            return UITestDate.deviceToday
        case .pinnedRemindIn, .trendsChart, .trendsNoScores:
            return UITestDate.today
        }
    }
}

enum CatalogLaunch: Equatable {
    case empty
    case sample
    case trendsChart
    case trendsNoScores

    var arguments: [String] {
        var args = ["-en", "-clear", "-uiTesting", "-today=\(UITestDate.today)"]
        switch self {
        case .empty:
            break
        case .sample:
            args.append("-loadSample")
        case .trendsChart:
            args.append(contentsOf: ["-fixture=trends", "-tabTrends"])
        case .trendsNoScores:
            args.append(contentsOf: ["-fixture=trends-noscores", "-tabTrends"])
        }
        return args
    }
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

final class AppRobot {
    let app = XCUIApplication()
    private var lastJourney: JourneyLaunch?

    /// Fallback when an id has no hint. `trends.plot` is a scroll view. The reminder card matches `.any`.
    private static let lookupTypes: [XCUIElement.ElementType] = [
        .button, .textField, .textView, .staticText, .switch, .scrollView, .group, .other, .image, .cell,
    ]

    func launch(_ plan: JourneyLaunch, file: StaticString = #filePath, line: UInt = #line) {
        if lastJourney == plan {
            XCTFail("relaunch does not change the plan: \(plan)", file: file, line: line)
            return
        }
        lastJourney = plan
        app.terminate()
        app.launchArguments = plan.arguments
        app.launch()
        waitFor(id: "tab.cycle", file: file, line: line)
        waitFor(id: "cycle.action.med", file: file, line: line)
    }

    func launchCatalog(_ plan: CatalogLaunch, file: StaticString = #filePath, line: UInt = #line) {
        app.terminate()
        app.launchArguments = plan.arguments
        app.launch()
        waitFor(id: "tab.cycle", file: file, line: line)
        switch plan {
        case .trendsChart, .trendsNoScores:
            waitFor(id: "tab.trends", file: file, line: line)
            waitFor(id: "trends.screen", file: file, line: line)
        case .empty, .sample:
            waitFor(id: "cycle.action.med", file: file, line: line)
        }
    }

    /// One existence check per control type, and only until the first hit.
    private func hit(_ id: String) -> XCUIElement? {
        for type in Self.hintedTypes(for: id) ?? Self.lookupTypes {
            let match = Self.query(app, type, id)
            if match.exists { return match }
        }
        return nil
    }

    func element(_ id: String) -> XCUIElement {
        if let found = hit(id) { return found }
        let type = (Self.hintedTypes(for: id) ?? [.button])[0]
        return Self.query(app, type, id)
    }

    /// One or two control types, taken from the types XCTest actually resolved on the CI journey.
    /// A missing hint falls back to the full list. A wrong single type would hide the control.
    private static func hintedTypes(for id: String) -> [XCUIElement.ElementType]? {
        switch id {
        case "reminder.banner":
            return [.any]
        case "trends.plot":
            return [.scrollView]
        case "med.name", "med.dose":
            return [.textField]
        case "symptom.custom.add":
            return [.textField, .button]
        case "more.reminders":
            return [.switch]
        case "trends.detail", "trends.screen":
            return [.other]
        case "cycle.chip.period", "cycle.pager.label", "trends.status", "trends.empty",
             "trends.axis", "trends.sizeKey", "trends.tickCopy", "visit.range":
            return [.staticText]
        case "sheet.med", "sheet.period", "sheet.symptom", "sheet.trends",
             "cycle.empty.meds", "cycle.effect", "visit.pdf.preview":
            return [.button, .staticText]
        default:
            break
        }
        if id.hasSuffix(".status") || id.hasPrefix("trends.group.") {
            return [.staticText]
        }
        if id.hasPrefix("trends.series.") {
            return [.button, .staticText]
        }
        if id.hasPrefix("cycle.strip.") {
            return [.other, .button]
        }
        if id.hasPrefix("tab.") || id.hasPrefix("cycle.") || id.hasPrefix("period.")
            || id.hasPrefix("med.") || id.hasPrefix("month.") || id.hasPrefix("more.")
            || id.hasPrefix("symptom.") || id.hasPrefix("trends.") || id.hasPrefix("visit.")
            || id.hasPrefix("confirm.") || id.hasPrefix("reminder.")
            || id == "date.done" || id == "time.done" || id == "sheet.close" {
            return [.button]
        }
        return nil
    }

    private static func query(_ app: XCUIApplication, _ type: XCUIElement.ElementType, _ id: String) -> XCUIElement {
        app.descendants(matching: type)[id]
    }

    @discardableResult
    func spin(timeout: TimeInterval, _ predicate: () -> Bool) -> Bool {
        if predicate() { return true }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            if predicate() { return true }
        }
        return predicate()
    }

    func frameInsideChrome(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        let bounds = app.frame
        guard frame.width > 1, frame.height > 1 else { return false }
        return frame.minX >= bounds.minX - 1
            && frame.maxX <= bounds.maxX + 1
            && frame.minY >= bounds.minY - 1
            && frame.maxY <= bounds.height - 140
    }

    func scrollTo(_ id: String, timeout: TimeInterval = 6, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<4 {
            if frameInsideChrome(element(id)) { return }
            app.swipeUp()
        }
        waitFor(id: id, timeout: timeout, file: file, line: line)
    }

    func waitFor(id: String, timeout: TimeInterval = 3, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(spin(timeout: timeout) { exists(id) }, "missing \(id)", file: file, line: line)
    }

    func waitGone(id: String, timeout: TimeInterval = 2, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(spin(timeout: timeout) { hit(id) == nil }, "still present \(id)", file: file, line: line)
    }

    func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        press(ready(id, file: file, line: line))
    }

    private func ready(_ id: String, timeout: TimeInterval = 3, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        var found: XCUIElement?
        XCTAssertTrue(
            spin(timeout: timeout) {
                found = hit(id)
                return found != nil
            },
            "missing \(id)",
            file: file,
            line: line
        )
        return found ?? element(id)
    }

    func value(of id: String) -> String {
        let el = element(id)
        if let raw = el.value as? String, !raw.isEmpty { return raw }
        return el.label
    }

    func exists(_ id: String) -> Bool {
        hit(id) != nil
    }

    func setDateKey(_ id: String, _ key: String, file: StaticString = #filePath, line: UInt = #line) {
        press(ready(id, file: file, line: line))
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
            press(done)
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
            press(anyDay)
            return true
        }
        for needle in needles {
            let match = picker.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS[c] %@", needle)
            ).firstMatch
            if match.exists {
                press(match)
                return true
            }
        }
        let dayButton = picker.buttons["\(day)"]
        if dayButton.exists {
            press(dayButton)
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

    func clearAndType(_ id: String, _ text: String, dismiss: Bool = true, file: StaticString = #filePath, line: UInt = #line) {
        waitFor(id: id, file: file, line: line)
        let field = element(id)
        focus(field, id: id, file: file, line: line)
        typeAligned(field, text)
        if shown(field) != text {
            focus(field, id: id, file: file, line: line)
            typeAligned(field, text)
        }
        let have = shown(field)
        XCTAssertEqual(have, text, "\(id) is \(have.debugDescription)", file: file, line: line)
        if dismiss {
            dismissKeyboard()
        }
    }

    private func focus(_ field: XCUIElement, id: String, file: StaticString, line: UInt) {
        press(field)
        XCTAssertTrue(
            spin(timeout: 2) { app.keyboards.firstMatch.exists },
            "keyboard for \(id)",
            file: file,
            line: line
        )
    }

    private func typeAligned(_ field: XCUIElement, _ text: String) {
        let have = shown(field)
        if have == text { return }
        if text.hasPrefix(have) {
            let suffix = String(text.dropFirst(have.count))
            if !suffix.isEmpty { field.typeText(suffix) }
            return
        }
        let deletes = rawCount(field)
        if deletes > 0 {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: deletes))
        }
        field.typeText(text)
    }

    private func rawCount(_ field: XCUIElement) -> Int {
        let raw = (field.value as? String) ?? ""
        if raw.isEmpty || raw == "YYYY-MM-DD" { return 0 }
        return raw.count
    }

    private func shown(_ field: XCUIElement) -> String {
        ((field.value as? String) ?? field.label)
            .replacingOccurrences(of: "YYYY-MM-DD", with: "")
    }

    /// A coordinate tied to the element makes XCTest resolve that button again
    /// three times after the touch. A point on the app is one event.
    func press(_ element: XCUIElement) {
        let frame = element.frame
        let origin = app.frame.origin
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX - origin.x, dy: frame.midY - origin.y))
            .tap()
    }

    func dismissKeyboard() {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        for title in ["sheet.symptom", "sheet.med", "sheet.period"] {
            if let sheet = hit(title) {
                press(sheet)
                _ = spin(timeout: 1) { !keyboard.exists }
                return
            }
        }
        if keyboard.buttons["Return"].exists {
            press(keyboard.buttons["Return"])
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
        color: String? = nil,
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
        if let color {
            let swatch = app.descendants(matching: .any)[color]
            if !frameInsideChrome(swatch) { app.swipeUp() }
            press(app.descendants(matching: .any)[color])
        }
        waitFor(id: "med.since")
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
            press(byId)
            return
        }
        let menuChoice = app.collectionViews.buttons[option]
        if spin(timeout: 1.5) { menuChoice.exists } {
            press(menuChoice)
            return
        }
        let other = app.buttons.matching(
            NSPredicate(format: "label == %@ AND identifier != %@", option, id)
        ).firstMatch
        if spin(timeout: 1) { other.exists } {
            press(other)
            return
        }
        let any = app.descendants(matching: .any)[option]
        if spin(timeout: 1) { any.exists } {
            press(any)
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
}
