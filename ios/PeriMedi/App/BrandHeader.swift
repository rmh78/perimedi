import SwiftUI

enum LaunchBeat {
    /// Skip the in-app fade under UI tests and reminder instrumentation.
    static var shouldPlay: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uiTesting") { return false }
        if args.contains(where: { $0.hasPrefix("-remindIn=") }) { return false }
        return true
    }
}

struct BrandHeader: View {
    private let peach = Color(hex: "#ffe4d6")
    /// Pulls Cycle/Month/More up into the fade so the header reads shorter.
    private let fadeOverlap: CGFloat = 36

    var body: some View {
        Image("BrandHeader")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.74),
                        .init(color: peach.opacity(0.22), location: 0.86),
                        .init(color: Theme.cream.opacity(0.78), location: 0.94),
                        .init(color: Theme.cream, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .background(peach)
            .padding(.bottom, -fadeOverlap)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("PeriMedi")
    }
}

/// Matches the system launch storyboard so the first SwiftUI frame does not flash.
struct LaunchBrandOverlay: View {
    private let peach = Color(hex: "#ffe4d6")

    var body: some View {
        ZStack {
            peach
            Text("PeriMedi")
                .font(.custom("Palatino-Bold", size: 44))
                .foregroundStyle(Theme.blush800)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
