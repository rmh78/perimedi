import SwiftUI

struct BrandHeader: View {
    var topBleed: CGFloat

    var body: some View {
        Image("BrandHeader")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 72 + topBleed, alignment: .bottom)
            .clipped()
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.blush100.opacity(0.7)).frame(height: 1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("PeriMedi")
    }
}
