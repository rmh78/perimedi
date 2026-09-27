import XCTest
@testable import PeriMediDomain

final class DoseWidgetSnapshotTests: XCTestCase {
    func testLegacyTakenActionDecodesAsTake() throws {
        let taken = try decode(chromeTake: nil, legacy: "Taken")
        XCTAssertEqual(taken.chrome.takeAction, "Take")
        let genommen = try decode(chromeTake: nil, legacy: "Genommen")
        XCTAssertEqual(genommen.chrome.takeAction, "Nehmen")
    }

    func testAckShowsCheckUntilTheHorizon() throws {
        let now = Date(timeIntervalSince1970: 1_758_960_000)
        let day = DateKeys.toDateKey(now)
        let inside = try snapshot(
            day: day,
            meds: false,
            until: now.addingTimeInterval(DoseWidgetAck.duration),
            finished: false
        )
        let face = inside.face(at: now)
        XCTAssertTrue(face.showsCheck)
        XCTAssertEqual(face.helper, "Still to take today")
        XCTAssertTrue(face.helperBlank)
        XCTAssertEqual(face.actionLabel, "Take")
        XCTAssertNil(face.emptyTitle)

        let beside = try snapshot(
            day: day,
            meds: true,
            until: now.addingTimeInterval(DoseWidgetAck.duration),
            finished: false,
            pendingId: "m2"
        )
        let besideFace = beside.face(at: now)
        XCTAssertTrue(besideFace.showsCheck)
        XCTAssertEqual(besideFace.helper, "Still to take today")
        XCTAssertFalse(besideFace.helperBlank)

        let expired = try snapshot(day: day, meds: false, until: now, finished: false)
        XCTAssertFalse(expired.face(at: now).showsCheck)

        let tooFar = try snapshot(
            day: day,
            meds: false,
            until: now.addingTimeInterval(DoseWidgetAck.horizon + 1),
            finished: false
        )
        XCTAssertFalse(tooFar.face(at: now).showsCheck)
    }

    func testFinishedDayUsesDoneTitleAfterTheCheck() throws {
        let now = Date(timeIntervalSince1970: 1_758_960_000)
        let day = DateKeys.toDateKey(now)
        let done = try snapshot(day: day, meds: false, until: nil, finished: true)
        let face = done.face(at: now)
        XCTAssertEqual(face.emptyTitle, "All taken for today")
        XCTAssertNil(face.helper)
        XCTAssertFalse(face.helperBlank)
        XCTAssertFalse(face.showsCheck)

        let idle = try snapshot(day: day, meds: false, until: nil, finished: false)
        XCTAssertEqual(idle.face(at: now).emptyTitle, "Nothing to take today")
    }

    func testLightCapsuleDarkensUntilWhiteTextClearsTheMinimum() {
        let pink = WidgetCapsuleFill.hex("#d43d6c")
        let light = WidgetCapsuleFill.hex("#f472b6")
        XCTAssertGreaterThanOrEqual(WidgetCapsuleFill.contrastWithWhite(pink) ?? 0, WidgetCapsuleFill.minimumContrast)
        XCTAssertGreaterThanOrEqual(WidgetCapsuleFill.contrastWithWhite(light) ?? 0, WidgetCapsuleFill.minimumContrast)
        XCTAssertEqual(WidgetCapsuleFill.hex("#94274b"), "#94274b")
    }

    private func decode(chromeTake: String?, legacy: String) throws -> DoseWidgetSnapshot {
        let take = chromeTake.map { "\"takeAction\":\"\($0)\"," } ?? ""
        let json = """
        {"version":2,"chrome":{"brandTitle":"PeriMedi","emptyTitle":"Nothing to take today","emptyBody":"No untaken medications planned today.",\(take)"takenAction":"\(legacy)"},"date":"2026-09-27","meds":[],"nextDate":"2026-09-28","nextMeds":[]}
        """
        return try JSONDecoder().decode(DoseWidgetSnapshot.self, from: Data(json.utf8))
    }

    private func snapshot(
        day: String,
        meds: Bool,
        until: Date?,
        finished: Bool,
        pendingId: String = "m1"
    ) throws -> DoseWidgetSnapshot {
        let medsJSON = meds
            ? "[{\"medicationId\":\"\(pendingId)\",\"name\":\"Estrogen\",\"doseLabel\":\"1 mg\",\"color\":\"#d43d6c\",\"icon\":\"pill\",\"earliestTimeOfDay\":\"20:00\"}]"
            : "[]"
        var json = """
        {"version":2,"chrome":{"brandTitle":"PeriMedi","emptyTitle":"Nothing to take today","emptyBody":"No untaken medications planned today.","takeAction":"Take","stillToTake":"Still to take today","doneTitle":"All taken for today"},"date":"\(day)","meds":\(medsJSON),"nextDate":"","nextMeds":[],"finishedToday":\(finished)
        """
        if let until {
            let row = "{\"medicationId\":\"m1\",\"name\":\"Estrogen\",\"doseLabel\":\"1 mg\",\"color\":\"#d43d6c\",\"icon\":\"pill\",\"earliestTimeOfDay\":\"20:00\"}"
            json += ",\"ack\":{\"row\":\(row),\"index\":0,\"until\":\(until.timeIntervalSinceReferenceDate)}"
        }
        json += "}"
        return try JSONDecoder().decode(DoseWidgetSnapshot.self, from: Data(json.utf8))
    }
}
