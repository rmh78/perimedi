import Foundation

public enum DoseUnitCopy {
    public static func display(_ value: String, languageCode: String) -> String {
        guard languageCode == "de" else { return value }
        var out = value
        for (source, dest) in [("pumps", "Hub"), ("pump", "Hub")] {
            out = replaceLetterBounded(out, source: source, dest: dest)
        }
        return replaceDecimalDots(out)
    }

    public static func decimal(_ value: Double, languageCode: String) -> String {
        let rounded = (value * 10).rounded() / 10
        if abs(rounded - rounded.rounded()) < 0.05 {
            return String(Int(rounded.rounded()))
        }
        let text = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), rounded)
        guard languageCode == "de" else { return text }
        return text.replacingOccurrences(of: ".", with: ",")
    }

    private static func replaceLetterBounded(_ value: String, source: String, dest: String) -> String {
        let pattern = "(?<![A-Za-z])\(NSRegularExpression.escapedPattern(for: source))(?![A-Za-z])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return value
        }
        let range = NSRange(value.startIndex..., in: value)
        return regex.stringByReplacingMatches(in: value, options: [], range: range, withTemplate: dest)
    }

    private static func replaceDecimalDots(_ value: String) -> String {
        let pattern = "(?<=[0-9])\\.(?=[0-9])"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        let range = NSRange(value.startIndex..., in: value)
        return regex.stringByReplacingMatches(in: value, options: [], range: range, withTemplate: ",")
    }
}
