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
    var title: String
    var filled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(filled ? .white : Theme.blush700)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(
                    Capsule().fill(filled
                        ? AnyShapeStyle(LinearGradient(colors: [Theme.blush500, Color(hex: "#c45a9a")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color.white.opacity(0.7)))
                )
                .overlay(Capsule().stroke(Theme.blush200, lineWidth: filled ? 0 : 1))
        }
        .buttonStyle(.plain)
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
