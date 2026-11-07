import Foundation
import UIKit

public enum DialogActionFit {
    public struct Fit {
        public var scale: CGFloat
        public var lines: Int
    }

    public static let spacing: CGFloat = PeriSpace.row
    public static let minLabelScale: CGFloat = 0.5
    public static let fitSlack: CGFloat = 4
    public static let horizontalPadding: CGFloat = PeriSpace.pad
    public static let minHeight: CGFloat = PeriSpace.minControl
    public static let strokeWidth: CGFloat = PeriSpace.hairline
    public static let minimumInset: CGFloat = 6

    public static func scale(titles: [String], rowWidth: CGFloat, base: CGFloat, bold: Bool = false) -> CGFloat {
        fit(titles: titles, rowWidth: rowWidth, base: base, bold: bold).scale
    }

    public static func fit(titles: [String], rowWidth: CGFloat, base: CGFloat, bold: Bool = false) -> Fit {
        let single = oneLineScale(titles: titles, rowWidth: rowWidth, base: base, bold: bold)
        if single >= minLabelScale {
            return Fit(scale: single, lines: 1)
        }
        return Fit(scale: minLabelScale, lines: 2)
    }

    public static func largestWholeWordFit(
        titles: [String],
        rowWidth: CGFloat,
        base: CGFloat,
        bold: Bool,
        locale: Locale
    ) -> Fit {
        let single = fit(titles: titles, rowWidth: rowWidth, base: base, bold: bold)
        if single.scale >= 1, single.lines == 1 { return single }
        var candidate: CGFloat = 1
        while candidate >= minLabelScale - 0.001 {
            let weight: UIFont.Weight = bold ? .bold : .semibold
            let font = UIFont.systemFont(ofSize: base * candidate, weight: weight)
            let pad = inset(titles: titles, rowWidth: rowWidth, font: font, locale: locale)
            let width = textWidth(rowWidth: rowWidth, count: titles.count, inset: pad)
            let shown = titles.map { wrapped($0, width: width, font: font, locale: locale) }
            let broken = shown.contains { line in
                if line.contains("-\n") { return true }
                return line.split(separator: "\n").contains { part in
                    measured(String(part), font: font) > width + 1
                }
            }
            if !broken {
                let lines = shown.contains(where: { $0.contains("\n") }) ? 2 : 1
                return Fit(scale: candidate, lines: lines)
            }
            candidate -= 0.05
        }
        return single
    }

    public static func rowHeight(scale: CGFloat, lines: Int, base: CGFloat, bold: Bool) -> CGFloat {
        let font = UIFont.systemFont(ofSize: base * scale, weight: bold ? .bold : .semibold)
        let text = ceil(font.lineHeight) * CGFloat(max(lines, 1))
        return max(minHeight, text) + strokeWidth
    }

    public static func spokenLabel(for title: String) -> String {
        title
    }

    public static func inset(titles: [String], rowWidth: CGFloat, font: UIFont, locale: Locale) -> CGFloat {
        let slot = slotWidth(rowWidth: rowWidth, count: titles.count)
        let needed = titles.map { requiredTextWidth($0, font: font, locale: locale) }.max() ?? 0
        let room = (slot - needed) / 2
        if room >= horizontalPadding {
            return horizontalPadding
        }
        return max(minimumInset, room)
    }

    public static func wrapped(_ title: String, width: CGFloat, font: UIFont, locale: Locale = .current) -> String {
        guard measured(title, font: font) > width + 0.5 else { return title }
        guard let piece = bestPiece(breakPieces(title, locale: locale), width: width, font: font) else {
            return title
        }
        return "\(piece.left)\n\(piece.right)"
    }

    public static func textWidth(rowWidth: CGFloat, count: Int, inset: CGFloat = horizontalPadding) -> CGFloat {
        slotWidth(rowWidth: rowWidth, count: count) - inset * 2
    }

    private struct BreakPiece {
        var left: String
        var right: String
        var hyphen: Bool
    }

    private static func breakPieces(_ title: String, locale: Locale) -> [BreakPiece] {
        let ns = title as NSString
        var pieces: [BreakPiece] = []
        for index in 0..<ns.length where ns.character(at: index) == 32 {
            let left = ns.substring(to: index)
            let right = ns.substring(from: index + 1)
            if !left.isEmpty, !right.isEmpty {
                pieces.append(BreakPiece(left: left, right: right, hyphen: false))
            }
        }
        let cf = title as CFString
        let length = CFStringGetLength(cf)
        var cursor = length
        let cfLocale = locale as CFLocale
        while cursor > 0 {
            var hyphenChar: UTF32Char = 0
            let location = CFStringGetHyphenationLocationBeforeIndex(
                cf,
                cursor,
                CFRange(location: 0, length: length),
                0,
                cfLocale,
                &hyphenChar
            )
            if location == kCFNotFound || location <= 0 {
                break
            }
            let right = ns.substring(from: location)
            if !right.isEmpty {
                pieces.append(BreakPiece(left: ns.substring(to: location) + "-", right: right, hyphen: true))
            }
            cursor = location
        }
        return pieces
    }

    private static func bestPiece(_ pieces: [BreakPiece], width: CGFloat, font: UIFont) -> BreakPiece? {
        struct Scored {
            var piece: BreakPiece
            var overflow: CGFloat
            var gap: CGFloat
            var fits: Bool
        }
        let scored = pieces.map { piece in
            let left = measured(piece.left, font: font)
            let right = measured(piece.right, font: font)
            return Scored(
                piece: piece,
                overflow: max(0, left - width) + max(0, right - width),
                gap: abs(left - right),
                fits: left <= width + 0.5 && right <= width + 0.5
            )
        }
        let fitting = scored.filter(\.fits)
        if fitting.isEmpty {
            return scored.min { lhs, rhs in
                if abs(lhs.overflow - rhs.overflow) > 0.5 { return lhs.overflow < rhs.overflow }
                if lhs.piece.hyphen != rhs.piece.hyphen { return !lhs.piece.hyphen }
                return lhs.gap < rhs.gap
            }?.piece
        }
        return fitting.min { lhs, rhs in
            if lhs.piece.hyphen != rhs.piece.hyphen { return !lhs.piece.hyphen }
            return lhs.gap < rhs.gap
        }?.piece
    }

    private static func requiredTextWidth(_ title: String, font: UIFont, locale: Locale) -> CGFloat {
        let pieces = breakPieces(title, locale: locale)
        let widths = pieces.map { max(measured($0.left, font: font), measured($0.right, font: font)) }
        if let legal = widths.min() {
            return legal
        }
        return measured(title, font: font)
    }

    private static func measured(_ text: String, font: UIFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    private static func oneLineScale(titles: [String], rowWidth: CGFloat, base: CGFloat, bold: Bool) -> CGFloat {
        guard rowWidth > 1, !titles.isEmpty else { return 1 }
        let available = textWidth(rowWidth: rowWidth, count: titles.count)
        guard available > 1 else { return 0 }
        let font = UIFont.systemFont(ofSize: base, weight: bold ? .bold : .semibold)
        let widest = titles.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        guard widest > available + 0.5 else { return 1 }
        return (available - fitSlack) / widest
    }

    private static func slotWidth(rowWidth: CGFloat, count: Int) -> CGFloat {
        (rowWidth - spacing * CGFloat(max(count - 1, 0))) / CGFloat(max(count, 1))
    }
}
