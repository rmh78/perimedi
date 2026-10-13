import XCTest
@testable import PeriMedi

final class VisitDateRangeTests: XCTestCase {
    func testClosedAndOpenRanges() {
        let en = Locale(identifier: "en")
        let de = Locale(identifier: "de")
        XCTAssertEqual(
            VisitDateRange.closed(startKey: "2026-03-07", endKey: "2026-03-12", locale: en),
            "Mar 7, 2026 \u{2013} Mar 12, 2026"
        )
        XCTAssertEqual(
            VisitDateRange.closed(startKey: "2026-03-07", endKey: "2026-03-12", locale: de),
            "7. März 2026 \u{2013} 12. März 2026"
        )
        XCTAssertEqual(
            VisitDateRange.closed(startKey: "2026-03-07", endKey: "2026-03-07", locale: en),
            "Mar 7, 2026 \u{2013} Mar 7, 2026"
        )
        XCTAssertEqual(
            VisitDateRange.periodHistory(startKey: "2026-03-07", endKey: nil, locale: en),
            "Mar 7, 2026 \u{2192} \u{2026}"
        )
    }
}
