import SwiftUI

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
