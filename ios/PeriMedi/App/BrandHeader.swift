import SwiftUI

struct BrandHeader: View {
    var body: some View {
        Image("BrandHeader")
            .resizable()
            .scaledToFill()
            .frame(height: 72)
            .clipped()
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.blush100.opacity(0.7)).frame(height: 1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("PeriMedi")
    }
}
