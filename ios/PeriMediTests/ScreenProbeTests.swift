import CoreGraphics
import XCTest

final class ScreenProbeTests: XCTestCase {
    private let phone = CGRect(x: 0, y: 0, width: 402, height: 874)

    func testARealIconPressesItsCenter() {
        let frame = CGRect(x: 160, y: 400, width: 76, height: 76)
        guard case .at(let point) = IconLongPressPlan.decide(
            frame: frame,
            screen: phone,
            elementExists: true
        ) else {
            XCTFail("a mid-screen icon was not pressed")
            return
        }
        XCTAssertEqual(point.dx, 198 / 402, accuracy: 0.001)
        XCTAssertEqual(point.dy, 438 / 874, accuracy: 0.001)
    }

    func testASmallFrameNearTheOriginDoesNotPressTheCorner() {
        let frame = CGRect(x: 1, y: 1, width: 9, height: 9)
        let decision = IconLongPressPlan.decide(frame: frame, screen: phone, elementExists: true)
        XCTAssertEqual(decision, .skip)
    }

    func testAMissingIconIsNotPressed() {
        let decision = IconLongPressPlan.decide(
            frame: .zero,
            screen: phone,
            elementExists: false
        )
        XCTAssertEqual(decision, .skip)
    }

    func testAMissedRestoreMenuIsNotTapped() {
        XCTAssertEqual(RestoreMenuPlan.decide(buttonExists: false, buttonWidth: 0), .missing)
    }

    func testRestoreFailsWhenNeitherIconNorWidgetIsOnScreen() {
        XCTAssertEqual(RestoreTargetPlan.decide(appIcon: nil, widget: nil), .absent)
    }

    func testMedicationNameFocusDoesNotWalkTheWholeTree() {
        XCTAssertEqual(NameFieldLookupPlan.focusWalk(id: "med.name.focused"), .textField)
        XCTAssertEqual(NameFieldLookupPlan.focusWalk(id: "med.name"), .textField)
    }
}
