import Foundation

public enum DoseUnitCopy {
    public static func display(_ value: String, languageCode: String) -> String {
        var out = value
        if languageCode == "de" {
            for (source, dest) in [("pumps", "Hub"), ("pump", "Hub")] {
                out = replaceLetterBounded(out, source: source, dest: dest)
            }
        }
        return formatDecimalTokens(out, languageCode: languageCode)
    }

    public static func decimal(_ value: Double, languageCode: String) -> String {
        format(value, languageCode: languageCode, fractionDigits: 1, keepFraction: false)
    }

    private static func format(
        _ value: Double,
        languageCode: String,
        fractionDigits: Int,
        keepFraction: Bool
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: languageCode)
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.roundingMode = .halfUp
        formatter.maximumFractionDigits = fractionDigits
        formatter.minimumFractionDigits = keepFraction ? fractionDigits : 0
        return formatter.string(from: NSNumber(value: value)) ?? ""
    }

    private static func formatDecimalTokens(_ value: String, languageCode: String) -> String {
        var result = ""
        var index = value.startIndex
        while index < value.endIndex {
            if isDigit(value[index]) {
                let start = index
                index = advanceDigits(in: value, from: index)
                let wholeEnd = index
                if index < value.endIndex, value[index] == "." {
                    let afterDot = value.index(after: index)
                    var end = afterDot
                    var digits = 0
                    while end < value.endIndex, isDigit(value[end]) {
                        digits += 1
                        end = value.index(after: end)
                    }
                    if digits > 0, let number = Double(value[start..<end]) {
                        result += format(
                            number,
                            languageCode: languageCode,
                            fractionDigits: digits,
                            keepFraction: true
                        )
                        index = end
                        continue
                    }
                }
                result += value[start..<wholeEnd]
                continue
            }
            result.append(value[index])
            index = value.index(after: index)
        }
        return result
    }

    private static func isDigit(_ character: Character) -> Bool {
        character >= "0" && character <= "9"
    }

    private static func advanceDigits(in value: String, from start: String.Index) -> String.Index {
        var index = start
        while index < value.endIndex, isDigit(value[index]) {
            index = value.index(after: index)
        }
        return index
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
