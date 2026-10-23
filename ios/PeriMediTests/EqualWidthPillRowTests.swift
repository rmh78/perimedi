import XCTest
@testable import PeriMedi

final class EqualWidthPillRowTests: XCTestCase {
    func testNoShrinkWhenTheWordsFit() {
        let scale = EqualWidthPillRow.scale(
            titles: ["Cancel", "Delete", "Save"],
            rowWidth: 390,
            base: 15
        )
        XCTAssertEqual(scale, 1)
    }

    func testSharedShrinkFitsTheWidestWord() {
        let titles = ["Abbrechen", "Löschen", "Speichern"]
        let width: CGFloat = 280
        let scale = EqualWidthPillRow.scale(titles: titles, rowWidth: width, base: 15)
        XCTAssertGreaterThan(scale, EqualWidthPillRow.minLabelScale)
        XCTAssertLessThan(scale, 1)
        let alone = EqualWidthPillRow.scale(titles: ["Abbrechen"], rowWidth: width, base: 15)
        XCTAssertEqual(alone, 1, "one word on the full row stays full size")
        let slot = (width - EqualWidthPillRow.spacing * 2) / 3
        let available = slot - PillButton.horizontalPadding * 2
        let font = UIFont.systemFont(ofSize: 15 * scale, weight: .semibold)
        let widest = titles.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        XCTAssertLessThanOrEqual(widest, available + 1)
    }

    func testFloorWhenTheSlotIsTooNarrow() {
        let scale = EqualWidthPillRow.scale(
            titles: ["Abbrechen", "Löschen", "Speichern"],
            rowWidth: 80,
            base: 15
        )
        XCTAssertEqual(scale, EqualWidthPillRow.minLabelScale)
    }

    func testSingleItemUsesTheWholeRow() {
        let one = EqualWidthPillRow.scale(titles: ["Abbrechen"], rowWidth: 90, base: 15)
        let three = EqualWidthPillRow.scale(
            titles: ["Abbrechen", "Löschen", "Speichern"],
            rowWidth: 90,
            base: 15
        )
        XCTAssertGreaterThan(one, EqualWidthPillRow.minLabelScale)
        XCTAssertEqual(three, EqualWidthPillRow.minLabelScale)
        XCTAssertGreaterThan(one, three)
    }

    func testLargestTextSizeFitsTheGermanRow() {
        let titles = ["Abbrechen", "Löschen", "Speichern"]
        let width: CGFloat = 318
        let base: CGFloat = 49
        let scale = EqualWidthPillRow.scale(titles: titles, rowWidth: width, base: base)
        XCTAssertGreaterThan(scale, EqualWidthPillRow.minLabelScale)
        XCTAssertLessThan(scale, 1)
        let slot = (width - EqualWidthPillRow.spacing * 2) / 3
        let available = slot - PillButton.horizontalPadding * 2
        let font = UIFont.systemFont(ofSize: base * scale, weight: .semibold)
        let widest = titles.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        XCTAssertLessThanOrEqual(widest, available + 1)
    }

    func testBoldTextShrinksAtLeastAsMuch() {
        let titles = ["Abbrechen", "Löschen", "Speichern"]
        let regular = EqualWidthPillRow.scale(titles: titles, rowWidth: 280, base: 15)
        let bold = EqualWidthPillRow.scale(titles: titles, rowWidth: 280, base: 15, bold: true)
        XCTAssertLessThan(bold, 1)
        XCTAssertLessThanOrEqual(bold, regular)
    }
}
