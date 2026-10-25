import XCTest
@testable import PeriMediDomain

final class DateCopyTests: XCTestCase {
    private let en = Locale(identifier: "en")
    private let de = Locale(identifier: "de")
    private let day = "2026-03-07"
    private let later = "2026-03-12"

    func testClosedAndOpenRanges() {
        XCTAssertEqual(
            DateCopy.closed(startKey: day, endKey: later, locale: en),
            "Mar 7, 2026 \u{2013} Mar 12, 2026"
        )
        XCTAssertEqual(
            DateCopy.closed(startKey: day, endKey: later, locale: de),
            "7. März 2026 \u{2013} 12. März 2026"
        )
        XCTAssertEqual(
            DateCopy.closed(startKey: day, endKey: day, locale: en),
            "Mar 7, 2026 \u{2013} Mar 7, 2026"
        )
        XCTAssertEqual(
            DateCopy.periodHistory(startKey: day, endKey: nil, locale: en),
            "Mar 7, 2026 \u{2192} \u{2026}"
        )
        XCTAssertEqual(
            DateCopy.periodHistory(startKey: day, endKey: nil, locale: de),
            "7. März 2026 \u{2192} \u{2026}"
        )
        XCTAssertEqual(
            DateCopy.periodHistory(startKey: "not-a-date", endKey: later, locale: en),
            "not-a-date"
        )
        XCTAssertEqual(
            DateCopy.periodHistory(startKey: day, endKey: "not-a-date", locale: en),
            "Mar 7, 2026 \u{2192} \u{2026}"
        )
    }

    func testEachStyleInEnglishAndGerman() {
        let month = DateKeys.parseDateKey("2026-03-01")!
        XCTAssertEqual(DateCopy.day(day, locale: en), "Mar 7, 2026")
        XCTAssertEqual(DateCopy.day(day, locale: de), "7. März 2026")
        XCTAssertEqual(DateCopy.shortDay(day, locale: en), "Mar 7")
        XCTAssertEqual(DateCopy.shortDay(day, locale: de), "7. März")
        XCTAssertEqual(DateCopy.weekdayMonth(day, locale: en), "Sat, Mar 7")
        XCTAssertEqual(DateCopy.weekdayMonth(day, locale: de), "Sa. 7. März")
        XCTAssertEqual(DateCopy.monthYear(month, locale: en), "March 2026")
        XCTAssertEqual(DateCopy.monthYear(month, locale: de), "März 2026")
        XCTAssertEqual(DateCopy.field(day, locale: en), "Mar 7, 2026")
        XCTAssertEqual(DateCopy.field(day, locale: de), "07.03.2026")
        XCTAssertEqual(DateCopy.field("not-a-date", locale: de), "not-a-date")
        XCTAssertEqual(DateCopy.day("not-a-date", locale: en), "not-a-date")
    }

    func testPredictedStartKeepsTheDayWithTheMonth() {
        XCTAssertEqual(DateCopy.predictedStart("2026-04-04", locale: de), "4.\u{00A0}April 2026")
        XCTAssertEqual(DateCopy.predictedStart("2026-09-04", locale: de), "4.\u{00A0}September 2026")
        XCTAssertEqual(DateCopy.predictedStart("2026-03-07", locale: en), "Mar\u{00A0}7, 2026")
        XCTAssertEqual(DateCopy.day("2026-04-04", locale: de), "4. Apr. 2026")
        XCTAssertEqual(DateCopy.predictedStart("not-a-date", locale: de), "not-a-date")
        XCTAssertEqual(DateCopy.predictedStart("not-a-date", locale: en), "not-a-date")
        let once = DateCopy.glue("4. April 2026")
        XCTAssertEqual(DateCopy.glue(once), once)
        let spelled = DateCopy.predictedStart("2026-04-04", locale: de)
        XCTAssertEqual(DateCopy.glue(spelled), spelled)
    }
}
