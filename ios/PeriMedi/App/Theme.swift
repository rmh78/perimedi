import SwiftUI
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

struct IconCircleButton: View {
    var systemName: String
    var label: String
    var tint: Color = Theme.blush700
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.blush50))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct PillButton: View {
    enum Kind {
        case primary, secondary, destructive
    }

    var title: String
    var kind: Kind = .secondary
    var identifier: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(foreground)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(Capsule().fill(fill))
                .overlay(Capsule().stroke(stroke, lineWidth: kind == .primary ? 0 : 1))
        }
        .buttonStyle(.plain)
        .a11y(identifier)
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

func medFormImage(_ form: MedForm) -> String {
    switch form {
    case .PILL: return "MedPill"
    case .CREAM: return "MedCream"
    case .DROPS: return "MedDrops"
    case .INJECTION: return "MedInjection"
    case .OTHER: return "MedOther"
    }
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
