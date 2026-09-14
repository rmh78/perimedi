import SwiftUI

enum TrendsStyle {
    static let seriesColors: [Color] = [
        Color(hex: "#c47f00"),
        Color(hex: "#d43d6c"),
        Color(hex: "#6b5ca5"),
    ]
}

enum TrendsSelectionStorage {
    static func parse(_ raw: String) -> [String]? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed == "-" { return [] }
        return trimmed.split(separator: ",").map(String.init)
    }
}
