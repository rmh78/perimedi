import SwiftUI
import UIKit
import PeriMediDomain

enum Theme {
    static let blush25 = Color(hex: "#fffafb")
    static let blush50 = Color(hex: "#fff1f4")
    static let blush100 = Color(hex: "#ffe4eb")
    static let blush200 = Color(hex: "#fecdd9")
    static let blush300 = Color(hex: "#fda4b8")
    static let blush400 = Color(hex: "#f4729a")
    static let blush500 = Color(hex: "#e85a84")
    static let blush600 = Color(hex: "#d43d6c")
    static let blush700 = Color(hex: "#b12d57")
    static let blush800 = Color(hex: "#94274b")
    static let lilac50 = Color(hex: "#f7f3fb")
    static let cream = Color(hex: "#fff9f6")
    static let ink = Color(hex: "#3d2c33")
    static let inkSoft = Color(hex: "#6b5560")
    static let inkMuted = Color(hex: "#9a8490")
    static let taken = Color(hex: "#5a9e7a")
    static let pending = Color(hex: "#b8a0ab")
    static let symptom = Color(hex: "#c47f00")

    static var pageBackground: some View {
        ZStack {
            cream
            RadialGradient(
                colors: [Color(hex: "#fde2ea"), .clear],
                center: UnitPoint(x: 0.1, y: -0.05),
                startRadius: 10,
                endRadius: 280
            )
            RadialGradient(
                colors: [Color(hex: "#ebe0f5").opacity(0.9), .clear],
                center: UnitPoint(x: 1, y: 0),
                startRadius: 10,
                endRadius: 260
            )
        }
        .ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: Theme.blush700.opacity(0.12), radius: 16, y: 8)
    }
}

struct PillButton: View {
    enum Kind {
        case primary, secondary, destructive
    }

    static let horizontalPadding: CGFloat = 14
    static let minHeight: CGFloat = 36
    static let fillsWidthFloor: CGFloat = 0.8
    static let strokeWidth: CGFloat = 1

    var title: String
    var kind: Kind = .secondary
    var identifier: String? = nil
    var fillsWidth = false
    var lines = 1
    var barHeight: CGFloat? = nil
    var labelScale: CGFloat? = nil
    var spokenTitle: String? = nil
    var action: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var subheadlineSize: CGFloat = 15

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(labelFont)
                .foregroundStyle(foreground)
                .lineLimit(fillsWidth ? lines : nil)
                .minimumScaleFactor(labelScale == nil && fillsWidth ? Self.fillsWidthFloor : 1)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Self.horizontalPadding)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .frame(minHeight: barHeight ?? Self.minHeight)
                .background(Capsule().fill(fill))
                .overlay(Capsule().stroke(stroke, lineWidth: kind == .primary ? 0 : Self.strokeWidth))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spokenTitle ?? title)
        .a11y(identifier)
    }

    private var labelFont: Font {
        if let labelScale {
            return .system(size: subheadlineSize * labelScale, weight: .semibold)
        }
        return .subheadline.weight(.semibold)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return .white
        case .secondary: return Theme.blush700
        case .destructive: return Theme.blush800
        }
    }

    private var fill: AnyShapeStyle {
        switch kind {
        case .primary:
            return AnyShapeStyle(LinearGradient(
                colors: [Theme.blush500, Color(hex: "#c45a9a")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .secondary, .destructive:
            return AnyShapeStyle(Theme.cream)
        }
    }

    private var stroke: Color {
        switch kind {
        case .primary: return .clear
        case .secondary: return Theme.blush200
        case .destructive: return Theme.blush300
        }
    }
}

struct EqualWidthPillRow: View {
    struct Item: Identifiable {
        let id: String
        var title: String
        var kind: PillButton.Kind
        var identifier: String? = nil
        var action: () -> Void
    }

    struct Fit {
        var scale: CGFloat
        var lines: Int
    }

    static let spacing: CGFloat = 8
    static let minLabelScale: CGFloat = 0.5
    static let fitSlack: CGFloat = 4

    var items: [Item]

    @ScaledMetric(relativeTo: .subheadline) private var subheadlineSize: CGFloat = 15
    @Environment(\.legibilityWeight) private var legibilityWeight
    @State private var rowHeight: CGFloat = 0

    var body: some View {
        let bold = legibilityWeight == .bold
        let open = rowHeight > 1
            ? rowHeight
            : max(
                Self.rowHeight(scale: 1, lines: 1, base: subheadlineSize, bold: bold),
                Self.rowHeight(scale: Self.minLabelScale, lines: 2, base: subheadlineSize, bold: bold)
            )
        GeometryReader { geo in
            let titles = items.map(\.title)
            let fit = Self.fit(
                titles: titles,
                rowWidth: geo.size.width,
                base: subheadlineSize,
                bold: bold
            )
            let height = Self.rowHeight(scale: fit.scale, lines: fit.lines, base: subheadlineSize, bold: bold)
            let font = UIFont.systemFont(ofSize: subheadlineSize * fit.scale, weight: bold ? .bold : .semibold)
            let available = Self.textWidth(rowWidth: geo.size.width, count: titles.count)
            HStack(spacing: Self.spacing) {
                ForEach(items) { item in
                    PillButton(
                        title: fit.lines > 1
                            ? Self.wrapped(item.title, width: available, font: font)
                            : item.title,
                        kind: item.kind,
                        identifier: item.identifier,
                        fillsWidth: true,
                        lines: fit.lines,
                        barHeight: height - PillButton.strokeWidth,
                        labelScale: fit.scale,
                        spokenTitle: item.title,
                        action: item.action
                    )
                }
            }
            .preference(key: EqualWidthRowHeightKey.self, value: height)
        }
        .frame(height: open)
        .onPreferenceChange(EqualWidthRowHeightKey.self) { newValue in
            if abs(newValue - rowHeight) > 0.5 {
                rowHeight = newValue
            }
        }
    }

    static func scale(titles: [String], rowWidth: CGFloat, base: CGFloat, bold: Bool = false) -> CGFloat {
        fit(titles: titles, rowWidth: rowWidth, base: base, bold: bold).scale
    }

    static func fit(titles: [String], rowWidth: CGFloat, base: CGFloat, bold: Bool = false) -> Fit {
        let single = oneLineScale(titles: titles, rowWidth: rowWidth, base: base, bold: bold)
        if single >= minLabelScale {
            return Fit(scale: single, lines: 1)
        }
        return Fit(scale: minLabelScale, lines: 2)
    }

    static func rowHeight(scale: CGFloat, lines: Int, base: CGFloat, bold: Bool) -> CGFloat {
        let font = UIFont.systemFont(ofSize: base * scale, weight: bold ? .bold : .semibold)
        let text = ceil(font.lineHeight) * CGFloat(max(lines, 1))
        return max(PillButton.minHeight, text) + PillButton.strokeWidth
    }

    static func wrapped(_ title: String, width: CGFloat, font: UIFont) -> String {
        let full = (title as NSString).size(withAttributes: [.font: font]).width
        guard full > width + 0.5 else { return title }
        let chars = Array(title)
        guard chars.count > 1 else { return title }
        var best = chars.count / 2
        var bestGap = CGFloat.greatestFiniteMagnitude
        var found = false
        for index in 1..<chars.count {
            let left = String(chars.prefix(index))
            let right = String(chars.suffix(chars.count - index))
            let leftWidth = (left as NSString).size(withAttributes: [.font: font]).width
            let rightWidth = (right as NSString).size(withAttributes: [.font: font]).width
            guard leftWidth <= width + 0.5, rightWidth <= width + 0.5 else { continue }
            let gap = abs(leftWidth - rightWidth)
            if gap < bestGap {
                bestGap = gap
                best = index
                found = true
            }
        }
        if !found {
            best = chars.count / 2
        }
        let left = String(chars.prefix(best))
        let right = String(chars.suffix(chars.count - best))
        return "\(left)\n\(right)"
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

    private static func textWidth(rowWidth: CGFloat, count: Int) -> CGFloat {
        let slot = (rowWidth - spacing * CGFloat(max(count - 1, 0))) / CGFloat(max(count, 1))
        return slot - PillButton.horizontalPadding * 2
    }
}

private struct EqualWidthRowHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

func medFormImage(_ form: MedForm) -> String {
    form.assetName
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}
