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
        let fit = EqualWidthPillRow.fit(
            titles: ["Abbrechen", "Löschen", "Speichern"],
            rowWidth: 80,
            base: 15
        )
        XCTAssertEqual(fit.scale, EqualWidthPillRow.minLabelScale)
        XCTAssertEqual(fit.lines, 2)
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
        XCTAssertEqual(
            EqualWidthPillRow.fit(titles: ["Abbrechen"], rowWidth: 90, base: 15).lines,
            1
        )
        XCTAssertEqual(
            EqualWidthPillRow.fit(
                titles: ["Abbrechen", "Löschen", "Speichern"],
                rowWidth: 90,
                base: 15
            ).lines,
            2
        )
    }

    func testGermanRowWrapsInsteadOfShrinkingBelowHalf() {
        let titles = ["Abbrechen", "Löschen", "Speichern"]
        let width: CGFloat = 318
        let base: CGFloat = 49
        let fit = EqualWidthPillRow.fit(titles: titles, rowWidth: width, base: base)
        XCTAssertEqual(fit.lines, 2)
        XCTAssertEqual(fit.scale, EqualWidthPillRow.minLabelScale)
        XCTAssertGreaterThanOrEqual(fit.scale, 0.5)
        let height = EqualWidthPillRow.rowHeight(scale: fit.scale, lines: fit.lines, base: base, bold: false)
        let line = UIFont.systemFont(ofSize: base * fit.scale, weight: .semibold).lineHeight
        XCTAssertGreaterThanOrEqual(height, ceil(line))
        XCTAssertGreaterThanOrEqual(height, ceil(line) * 2)
        let slot = (width - EqualWidthPillRow.spacing * 2) / 3
        let available = slot - PillButton.horizontalPadding * 2
        let font = UIFont.systemFont(ofSize: base * fit.scale, weight: .semibold)
        for title in titles {
            let shown = EqualWidthPillRow.wrapped(title, width: available, font: font)
            XCTAssertEqual(shown.replacingOccurrences(of: "\n", with: ""), title)
            for part in shown.split(separator: "\n") {
                let partWidth = (String(part) as NSString).size(withAttributes: [.font: font]).width
                XCTAssertLessThanOrEqual(partWidth, available + 1)
            }
        }
    }

    func testGermanWrapBreaksOnAHyphenAndVoiceOverStaysWhole() {
        let titles = ["Abbrechen", "Löschen", "Speichern"]
        let width: CGFloat = 318
        let base: CGFloat = 49
        let locale = Locale(identifier: "de")
        let slot = (width - EqualWidthPillRow.spacing * 2) / 3
        let available = slot - PillButton.horizontalPadding * 2
        let font = UIFont.systemFont(ofSize: base * EqualWidthPillRow.minLabelScale, weight: .semibold)
        let expected = [
            "Abbrechen": "Abbre-\nchen",
            "Löschen": "Lö-\nschen",
            "Speichern": "Spei-\nchern",
        ]
        for title in titles {
            let shown = EqualWidthPillRow.wrapped(title, width: available, font: font, locale: locale)
            XCTAssertEqual(shown, expected[title])
            let spoken = EqualWidthPillRow.spokenLabel(for: title)
            XCTAssertEqual(spoken, title)
            XCTAssertFalse(spoken.contains("\n"))
            XCTAssertFalse(spoken.contains("-"))
            for part in shown.split(separator: "\n") {
                let partWidth = (String(part) as NSString).size(withAttributes: [.font: font]).width
                XCTAssertLessThanOrEqual(partWidth, available + 1, title)
            }
        }
        let phraseFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
        let phrase = EqualWidthPillRow.wrapped("Not taken", width: 60, font: phraseFont, locale: locale)
        XCTAssertEqual(phrase, "Not\ntaken")
        XCTAssertEqual(EqualWidthPillRow.spokenLabel(for: "Not taken"), "Not taken")
    }

    func testBoldTextShrinksAtLeastAsMuch() {
        let titles = ["Abbrechen", "Löschen", "Speichern"]
        let regular = EqualWidthPillRow.scale(titles: titles, rowWidth: 280, base: 15)
        let bold = EqualWidthPillRow.scale(titles: titles, rowWidth: 280, base: 15, bold: true)
        XCTAssertLessThan(bold, 1)
        XCTAssertLessThanOrEqual(bold, regular)
    }
}
