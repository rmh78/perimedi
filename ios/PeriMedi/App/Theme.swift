import SwiftUI
import UIKit
import PeriMediDomain
import PeriDesign

enum Theme {
    static var pageBackground: some View {
        ZStack {
            PeriColor.cream
            RadialGradient(
                colors: [PeriColor.pageWash, .clear],
                center: UnitPoint(x: 0.1, y: -0.05),
                startRadius: 10,
                endRadius: 280
            )
            RadialGradient(
                colors: [PeriColor.pageWashLilac.opacity(0.9), .clear],
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
                RoundedRectangle(cornerRadius: PeriRadius.card, style: .continuous)
                    .fill(Color.white.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PeriRadius.card, style: .continuous)
                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: PeriColor.blush700.opacity(0.12), radius: 16, y: 8)
    }
}

struct PillButton: View {
    enum Kind {
        case primary, secondary, destructive
    }

    static let horizontalPadding: CGFloat = PeriSpace.pad
    static let minHeight: CGFloat = PeriSpace.minControl
    static let fillsWidthFloor: CGFloat = 0.8
    static let strokeWidth: CGFloat = PeriSpace.hairline

    var title: String
    var kind: Kind = .secondary
    var identifier: String? = nil
    var fillsWidth = false
    var lines = 1
    var barHeight: CGFloat? = nil
    var labelScale: CGFloat? = nil
    var spokenTitle: String? = nil
    var inset: CGFloat = Self.horizontalPadding
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
                .padding(.horizontal, inset)
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
        return PeriFont.pillLabel
    }

    private var foreground: Color {
        switch kind {
        case .primary: return .white
        case .secondary: return PeriColor.blush700
        case .destructive: return PeriColor.blush800
        }
    }

    private var fill: AnyShapeStyle {
        switch kind {
        case .primary:
            return AnyShapeStyle(LinearGradient(
                colors: [PeriColor.blush500, PeriColor.pillGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .secondary, .destructive:
            return AnyShapeStyle(PeriColor.cream)
        }
    }

    private var stroke: Color {
        switch kind {
        case .primary: return .clear
        case .secondary: return PeriColor.blush200
        case .destructive: return PeriColor.blush300
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

    static let spacing: CGFloat = DialogActionFit.spacing
    static let minLabelScale: CGFloat = DialogActionFit.minLabelScale

    var items: [Item]

    @ScaledMetric(relativeTo: .subheadline) private var subheadlineSize: CGFloat = 15
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Environment(\.locale) private var locale
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
            let inset = fit.lines > 1
                ? Self.inset(titles: titles, rowWidth: geo.size.width, font: font, locale: locale)
                : PillButton.horizontalPadding
            let available = Self.textWidth(rowWidth: geo.size.width, count: titles.count, inset: inset)
            HStack(spacing: Self.spacing) {
                ForEach(items) { item in
                    PillButton(
                        title: fit.lines > 1
                            ? Self.wrapped(item.title, width: available, font: font, locale: locale)
                            : item.title,
                        kind: item.kind,
                        identifier: item.identifier,
                        fillsWidth: true,
                        lines: fit.lines,
                        barHeight: height - PillButton.strokeWidth,
                        labelScale: fit.scale,
                        spokenTitle: Self.spokenLabel(for: item.title),
                        inset: inset,
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
        DialogActionFit.scale(titles: titles, rowWidth: rowWidth, base: base, bold: bold)
    }

    static func fit(titles: [String], rowWidth: CGFloat, base: CGFloat, bold: Bool = false) -> Fit {
        let fitted = DialogActionFit.fit(titles: titles, rowWidth: rowWidth, base: base, bold: bold)
        return Fit(scale: fitted.scale, lines: fitted.lines)
    }

    static func rowHeight(scale: CGFloat, lines: Int, base: CGFloat, bold: Bool) -> CGFloat {
        DialogActionFit.rowHeight(scale: scale, lines: lines, base: base, bold: bold)
    }

    static func spokenLabel(for title: String) -> String {
        DialogActionFit.spokenLabel(for: title)
    }

    static let minimumInset: CGFloat = DialogActionFit.minimumInset

    static func inset(titles: [String], rowWidth: CGFloat, font: UIFont, locale: Locale) -> CGFloat {
        DialogActionFit.inset(titles: titles, rowWidth: rowWidth, font: font, locale: locale)
    }

    static func wrapped(_ title: String, width: CGFloat, font: UIFont, locale: Locale = .current) -> String {
        DialogActionFit.wrapped(title, width: width, font: font, locale: locale)
    }

    static func textWidth(rowWidth: CGFloat, count: Int, inset: CGFloat = PillButton.horizontalPadding) -> CGFloat {
        DialogActionFit.textWidth(rowWidth: rowWidth, count: count, inset: inset)
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
