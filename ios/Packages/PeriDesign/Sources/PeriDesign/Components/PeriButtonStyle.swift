import SwiftUI

public struct PeriButtonStyle: ButtonStyle {
    public enum Role {
        case primary, secondary, destructive
    }

    public var role: Role
    var fillsWidth: Bool
    var lines: Int
    var labelScale: CGFloat?
    var barHeight: CGFloat?
    var inset: CGFloat

    public init(role: Role) {
        self.role = role
        fillsWidth = false
        lines = 1
        labelScale = nil
        barHeight = nil
        inset = PeriSpace.pad
    }

    init(
        role: Role,
        fillsWidth: Bool,
        lines: Int,
        labelScale: CGFloat?,
        barHeight: CGFloat?,
        inset: CGFloat
    ) {
        self.role = role
        self.fillsWidth = fillsWidth
        self.lines = lines
        self.labelScale = labelScale
        self.barHeight = barHeight
        self.inset = inset
    }

    public func makeBody(configuration: Configuration) -> some View {
        PeriButtonFace(
            role: role,
            fillsWidth: fillsWidth,
            lines: lines,
            labelScale: labelScale,
            barHeight: barHeight,
            inset: inset,
            label: configuration.label
        )
    }
}

private struct PeriButtonFace<Label: View>: View {
    var role: PeriButtonStyle.Role
    var fillsWidth: Bool
    var lines: Int
    var labelScale: CGFloat?
    var barHeight: CGFloat?
    var inset: CGFloat
    var label: Label

    @ScaledMetric(relativeTo: .subheadline) private var subheadlineSize: CGFloat = 15

    var body: some View {
        label
            .font(labelFont)
            .foregroundStyle(foreground)
            .lineLimit(fillsWidth ? lines : nil)
            .minimumScaleFactor(fillsWidth ? 0.8 : 1)
            .multilineTextAlignment(.center)
            .padding(.horizontal, inset)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(minHeight: barHeight ?? PeriSpace.minControl)
            .background(Capsule().fill(fill))
            .overlay(Capsule().stroke(stroke, lineWidth: role == .primary ? 0 : PeriSpace.hairline))
    }

    private var labelFont: Font {
        if let labelScale {
            return .system(size: subheadlineSize * labelScale, weight: .semibold)
        }
        return PeriFont.pillLabel
    }

    private var foreground: Color {
        switch role {
        case .primary: return .white
        case .secondary: return PeriColor.blush700
        case .destructive: return PeriColor.blush800
        }
    }

    private var fill: AnyShapeStyle {
        switch role {
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
        switch role {
        case .primary: return .clear
        case .destructive: return PeriColor.blush300
        case .secondary: return PeriColor.blush200
        }
    }
}
