import XCTest
@testable import PeriMediDomain

final class DoseUnitCopyTests: XCTestCase {
    func testEnglishLeavesStoredText() {
        XCTAssertEqual(DoseUnitCopy.display("2 pumps", languageCode: "en"), "2 pumps")
        XCTAssertEqual(DoseUnitCopy.display("pumpkin", languageCode: "en"), "pumpkin")
    }

    func testGermanMapsPumpTokensToHub() {
        XCTAssertEqual(DoseUnitCopy.display("1 pump", languageCode: "de"), "1 Hub")
        XCTAssertEqual(DoseUnitCopy.display("2 pumps", languageCode: "de"), "2 Hub")
        XCTAssertEqual(DoseUnitCopy.display("2.5 pumps", languageCode: "de"), "2.5 Hub")
        XCTAssertEqual(DoseUnitCopy.display("0.25 pump", languageCode: "de"), "0.25 Hub")
        XCTAssertEqual(DoseUnitCopy.display("2 PUMPS", languageCode: "de"), "2 Hub")
    }

    func testGermanDoesNotHalfTranslateOddValues() {
        XCTAssertEqual(DoseUnitCopy.display("pumpkin", languageCode: "de"), "pumpkin")
        XCTAssertEqual(DoseUnitCopy.display("pumpkins", languageCode: "de"), "pumpkins")
        XCTAssertEqual(DoseUnitCopy.display("pumping", languageCode: "de"), "pumping")
    }
}
