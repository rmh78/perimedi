import Foundation

public enum DoseUnitCopy {
    public static func display(_ value: String, languageCode: String) -> String {
        guard languageCode == "de" else { return value }
        var out = value
        for (source, dest) in [("pumps", "Hub"), ("pump", "Hub")] {
            out = replaceLetterBounded(out, source: source, dest: dest)
        }
        return out
    }

    private static func replaceLetterBounded(_ value: String, source: String, dest: String) -> String {
        let pattern = "(?<![A-Za-z])\(NSRegularExpression.escapedPattern(for: source))(?![A-Za-z])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return value
        }
        let range = NSRange(value.startIndex..., in: value)
        return regex.stringByReplacingMatches(in: value, options: [], range: range, withTemplate: dest)
    }
}
