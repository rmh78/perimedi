import XCTest

/// One first-session path: a woman opens an empty app, logs her last period,
/// adds the medications she actually takes, marks this morning’s dose, notes a
/// symptom, and checks that Month agrees.
final class FirstUseJourneyTests: PeriMediUITestCase {
    func testFirstUseJourney() {
        robot.launch()

        XCTContext.runActivity(named: "01 empty home") { _ in
            robot.waitFor(id: "tab.cycle")
            robot.waitFor(id: "tab.month")
            robot.waitFor(id: "tab.more")
            robot.waitFor(id: "cycle.action.med")
            robot.waitFor(id: "cycle.action.period")
            robot.waitFor(id: "cycle.action.symptom")
            robot.waitFor(id: "cycle.empty.meds")
            XCTAssertTrue(robot.value(of: "cycle.empty.meds").contains("need-period"))
            XCTAssertTrue(robot.value(of: "cycle.empty.meds").contains("need-med"))
            robot.waitFor(id: "cycle.intro")
            XCTAssertFalse(robot.exists("cycle.lane.estrogen"))
            XCTAssertFalse(robot.exists("cycle.effect"))
        }

        XCTContext.runActivity(named: "02 log last period") { _ in
            robot.addPeriod()
            robot.waitFor(id: "cycle.strip.day.\(UITestDate.periodStart)")
            XCTAssertTrue(robot.value(of: "cycle.strip.day.\(UITestDate.periodStart)").contains("period"))
            XCTAssertTrue(robot.value(of: "cycle.strip.day.\(UITestDate.periodEnd)").contains("period"))
            robot.waitFor(id: "cycle.empty.meds")
            XCTAssertEqual(robot.value(of: "cycle.empty.meds"), "need-med")
            XCTAssertFalse(robot.exists("cycle.intro"))
            robot.waitFor(id: "cycle.effect")
            XCTAssertEqual(robot.value(of: "cycle.effect"), "no-previous")
        }

        XCTContext.runActivity(named: "03 add everyday estrogen") { _ in
            robot.addMedication(name: "Estrogen", dose: "1 mg", start: UITestDate.periodStart)
            robot.waitFor(id: "cycle.lane.estrogen")
            XCTAssertFalse(robot.exists("cycle.empty.meds"))
            XCTAssertFalse(robot.exists("cycle.intro"))
        }

        XCTContext.runActivity(named: "04 add cyclic progesterone") { _ in
            robot.addMedication(
                name: "Progesterone",
                dose: "200 mg",
                form: "Cream",
                cyclic: true,
                start: UITestDate.periodStart
            )
            robot.waitFor(id: "cycle.lane.progesterone")
            robot.waitFor(id: "cycle.lane.estrogen")
        }

        XCTContext.runActivity(named: "05 mark this morning taken") { _ in
            robot.tap("cycle.lane.estrogen")
            XCTAssertEqual(robot.value(of: "cycle.lane.estrogen.status"), "taken")
        }

        XCTContext.runActivity(named: "06 look back at the week") { _ in
            robot.waitFor(id: "cycle.pager.label")
            let onToday = robot.value(of: "cycle.pager.label")
            XCTAssertFalse(onToday.isEmpty)
            robot.tap("cycle.pager.prev")
            XCTAssertNotEqual(robot.value(of: "cycle.pager.label"), onToday)
            for _ in 0..<3 {
                robot.tap("cycle.pager.prev")
            }
            robot.waitFor(id: "cycle.chip.period")
            robot.tap("cycle.pager.next")
            robot.tap("cycle.pager.today")
            XCTAssertEqual(robot.value(of: "cycle.pager.label"), onToday)
            XCTAssertEqual(robot.value(of: "cycle.lane.estrogen.status"), "taken")
        }

        XCTContext.runActivity(named: "07 log structured symptoms") { _ in
            robot.addSymptom()
            robot.waitFor(id: "cycle.chip.score.hot_flash")
            XCTAssertTrue(robot.value(of: "cycle.chip.score.hot_flash").localizedCaseInsensitiveContains("strong"))
        }

        XCTContext.runActivity(named: "08 month overview agrees") { _ in
            robot.tap("tab.month")
            robot.waitFor(id: "month.day.\(UITestDate.today)")
            XCTAssertTrue(robot.value(of: "month.day.\(UITestDate.today)").contains("selected"))
            XCTAssertTrue(robot.value(of: "month.day.\(UITestDate.periodStart)").contains("period"))
            XCTAssertTrue(robot.value(of: "month.day.\(UITestDate.today)").contains("taken"))
            XCTAssertTrue(robot.value(of: "month.day.\(UITestDate.today)").contains("symptom"))
            robot.tap("tab.cycle")
            robot.waitFor(id: "cycle.lane.estrogen")
            robot.waitFor(id: "cycle.lane.progesterone")
            XCTAssertEqual(robot.value(of: "cycle.lane.estrogen.status"), "taken")
        }
    }

    func testMonthPager() {
        robot.launch()
        robot.tap("tab.month")
        robot.waitFor(id: "month.day.\(UITestDate.today)")
        XCTAssertTrue(robot.value(of: "month.day.\(UITestDate.today)").contains("selected"))
        robot.tap("month.pager.next")
        robot.waitFor(id: "month.day.2026-04-01")
        robot.tap("month.pager.prev")
        robot.waitFor(id: "month.day.\(UITestDate.today)")
        XCTAssertTrue(robot.value(of: "month.day.\(UITestDate.today)").contains("selected"))
        robot.tap("cycle.pager.today")
        XCTAssertTrue(robot.value(of: "month.day.\(UITestDate.today)").contains("selected"))
    }

    func testMoreRemindersControls() {
        robot.launch()
        robot.tap("tab.more")
        robot.waitFor(id: "more.lang.en")
        robot.waitFor(id: "more.lang.de")
        robot.tap("more.lang.en")
        robot.waitFor(id: "more.reminders")
        robot.tap("more.reminders")
        robot.waitFor(id: "more.reminderSound")
        robot.tap("more.reminderSoundPreview")
        if robot.exists("more.remindersSettings") {
            /* denied-settings row */
        }
        robot.app.swipeUp()
        robot.waitFor(id: "more.privacyPolicy")
        robot.waitFor(id: "more.sample")
        robot.waitFor(id: "more.export")
        robot.waitFor(id: "more.import")
        robot.waitFor(id: "more.clear")
        robot.tap("more.sample")
        robot.waitFor(id: "confirm.cancel")
        robot.tap("confirm.cancel")
        robot.waitGone(id: "confirm.cancel")
    }

    /// Springboard banners are unreliable in XCTest. `-remindIn` fires the next
    /// pending slot in-process; Taken uses the same path as the notification action.
    func testDoseReminderTaken() {
        robot.launch(extra: ["-remindIn=4"])

        XCTContext.runActivity(named: "add a dose that is still pending") { _ in
            robot.addMedication(name: "Estrogen", dose: "1 mg", start: UITestDate.today)
            robot.waitFor(id: "cycle.lane.estrogen")
            XCTAssertEqual(robot.value(of: "cycle.lane.estrogen.status"), "not-taken")
        }

        XCTContext.runActivity(named: "take from the reminder") { _ in
            robot.waitFor(id: "reminder.banner", timeout: 12)
            robot.tap("reminder.taken")
            robot.waitGone(id: "reminder.banner")
            XCTAssertEqual(robot.value(of: "cycle.lane.estrogen.status"), "taken")
        }
    }
}
