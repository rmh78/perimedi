import XCTest
@testable import PeriMedi

@MainActor
final class SymptomScaleWordTests: XCTestCase {
    func testSymptomLevelWords() {
        let defaultsKey = "perimedi.locale"
        let previous = UserDefaults.standard.string(forKey: defaultsKey)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            }
        }

        let locale = LocaleController()
        let ladders: [AppLanguage: [String: [String]]] = [
            .en: [
                "sleep": ["restless", "poor", "very poor", "awful"],
                "joints": ["mild", "mid", "strong", "intense"],
                "mood": ["mild", "mid", "strong", "intense"],
                "irritability": ["a bit", "quite", "very", "extreme"],
                "anxiety": ["a bit", "quite", "very", "extreme"],
                "sexual": ["less", "low", "minimal", "none"],
            ],
            .de: [
                "sleep": ["unruhig", "schlecht", "sehr schlecht", "miserabel"],
                "joints": ["leicht", "mittel", "stark", "extrem"],
                "mood": ["leicht", "mittel", "stark", "extrem"],
                "irritability": ["etwas", "ziemlich", "sehr", "extrem"],
                "anxiety": ["etwas", "ziemlich", "sehr", "extrem"],
                "sexual": ["weniger", "wenig", "kaum", "keine"],
            ],
        ]

        for (language, symptoms) in ladders {
            locale.language = language
            for (id, words) in symptoms {
                for step in 1...4 {
                    let key = "symptom.level.\(id).\(step)"
                    XCTAssertEqual(locale.t(key), words[step - 1], key)
                }
            }
        }
    }
}
