import XCTest
@testable import PeriMediDomain

final class SymptomLogTests: XCTestCase {
    private let day = "2026-03-15"
    private let logged = "2026-03-15T08:12:00Z"

    func testCatalogHasElevenIdsAndGroups() {
        XCTAssertEqual(SymptomId.allCases.count, 11)
        XCTAssertEqual(SymptomGroup.body.ids.map(\.rawValue), ["hot_flash", "heart", "sleep", "joints"])
        XCTAssertEqual(SymptomGroup.mood.ids.map(\.rawValue), ["mood", "irritability", "anxiety", "exhaustion"])
        XCTAssertEqual(
            SymptomGroup.urogenital.ids.map(\.rawValue),
            ["sexual", "bladder", "vaginal_dryness"]
        )
        for id in SymptomId.allCases {
            XCTAssertTrue(id.higherIsWorse)
        }
    }

    func testReplaceSameIdSameDay() {
        let first = row(id: "hot_flash", severity: 2)
        let second = row(id: "hot_flash", severity: 3)
        let sleep = row(id: "sleep", severity: 2)
        let next = SymptomLog.upserting(SymptomLog.upserting([first], incoming: sleep), incoming: second)
        XCTAssertEqual(next.filter { $0.date == day }.count, 2)
        XCTAssertEqual(next.first { $0.id == "hot_flash" }?.severity, 3)
    }

    func testUntouchedIdsAbsentFromDayReplace() {
        let dayScores = [
            row(id: "hot_flash", severity: 3),
            row(id: "sleep", severity: 2),
            row(id: "joints", severity: 1),
        ]
        let next = SymptomLog.replacingDay(
            [row(id: "mood", severity: 4, date: "2026-03-14")],
            date: day,
            with: dayScores
        )
        XCTAssertEqual(Set(next.filter { $0.date == day }.map(\.id)), ["hot_flash", "sleep", "joints"])
        XCTAssertNil(next.first { $0.date == day && $0.id == "mood" })
        XCTAssertEqual(next.first { $0.date == "2026-03-14" }?.id, "mood")
    }

    func testEncodeOmitsCountAndUntouchedIds() throws {
        let payload = ExportPayload(
            exportedAt: logged,
            medications: [],
            schedules: [],
            doseLogs: [],
            remarks: [
                Remark(id: "n1", occurredOn: day, kind: .note, body: "walked", createdAt: logged),
            ],
            cycleSettings: .default,
            periods: [],
            symptomScores: [
                row(id: "hot_flash", severity: 3),
                row(id: "sleep", severity: 2),
                row(id: "joints", severity: 1),
            ]
        )
        let data = try BackupCodec.encode(payload)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"id\" : \"hot_flash\""))
        XCTAssertTrue(json.contains("\"severity\" : 3"))
        XCTAssertFalse(json.contains("\"count\""))
        XCTAssertTrue(json.contains("\"loggedAt\""))
        XCTAssertTrue(json.contains("\"date\" : \"2026-03-15\""))
        XCTAssertFalse(json.contains("\"id\" : \"mood\""))

        let decoded = try BackupCodec.decode(data)
        XCTAssertEqual(decoded.symptomScores.count, 3)
        XCTAssertNil(decoded.symptomScores.first { $0.id == "hot_flash" }?.count)
        XCTAssertEqual(Set(decoded.symptomScores.map(\.id)), ["hot_flash", "sleep", "joints"])
    }

    func testOldBackupWithCountStillDecodes() throws {
        let json = """
        {"version":1,"exportedAt":"t","medications":[],"schedules":[],"doseLogs":[],"remarks":[],"cycleSettings":{"id":"default","averageCycleLength":28,"averagePeriodLength":5},"periods":[],"symptomScores":[{"id":"hot_flash","date":"2026-03-15","severity":3,"count":8,"loggedAt":"t","higherIsWorse":true}]}
        """
        let imported = try BackupCodec.decode(Data(json.utf8))
        XCTAssertEqual(imported.symptomScores.first?.severity, 3)
        XCTAssertEqual(imported.symptomScores.first?.count, 8)
    }

    func testOldBackupWithoutScoresStillDecodes() throws {
        let json = """
        {"version":1,"exportedAt":"t","medications":[],"schedules":[],"doseLogs":[],"remarks":[{"id":"r1","occurredOn":"2026-03-15","kind":"cycle","body":"Cramps day 1","createdAt":"t"}],"cycleSettings":{"id":"default","averageCycleLength":28,"averagePeriodLength":5},"periods":[]}
        """
        let imported = try BackupCodec.decode(Data(json.utf8))
        XCTAssertEqual(imported.symptomScores, [])
        XCTAssertEqual(imported.remarks.first?.body, "Cramps day 1")
        XCTAssertEqual(imported.remarks.first?.kind, .cycle)
    }

    func testRemarksDoNotChangeMeans() {
        let scores = [
            row(id: "hot_flash", severity: 3),
            row(id: "hot_flash", severity: 1, date: "2026-03-14"),
            row(id: "sleep", severity: 2),
        ]
        let mean = SymptomLog.meanSeverity(scores, id: "hot_flash")
        XCTAssertEqual(mean, 2.0)
        XCTAssertNil(SymptomLog.meanSeverity(scores, id: "mood"))
        XCTAssertEqual(SymptomLog.meanSeverity(scores, id: "sleep"), 2.0)
    }

    func testSampleIncludesTodayAcceptanceScores() {
        let sample = SampleData.payload(now: DateKeys.parseDateKey("2026-03-15")!)
        let today = sample.symptomScores.filter { $0.date == "2026-03-15" }
        XCTAssertEqual(today.first { $0.id == "hot_flash" }?.severity, 3)
        XCTAssertNil(today.first { $0.id == "hot_flash" }?.count)
        XCTAssertEqual(today.first { $0.id == "sleep" }?.severity, 2)
        XCTAssertEqual(today.first { $0.id == "joints" }?.severity, 1)
        XCTAssertNil(today.first { $0.id == "mood" })
        XCTAssertFalse(sample.remarks.contains { $0.kind == .cycle })
    }

    private func row(
        id: String,
        severity: Int,
        date: String? = nil
    ) -> SymptomScore {
        SymptomScore(
            id: id,
            date: date ?? day,
            severity: severity,
            loggedAt: logged,
            higherIsWorse: true
        )
    }
}
