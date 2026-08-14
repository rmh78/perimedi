import SwiftUI

struct DialogChrome<Content: View>: View {
    var title: String
    var icon: String?
    var onClose: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let icon {
                    Image(icon)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .background(Circle().fill(Theme.blush50))
                }
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.blush800)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.blush50))
                }
                .accessibilityLabel("Close")
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Rectangle().fill(Theme.blush100).frame(height: 1)

            ScrollView {
                content()
                    .padding(16)
            }
        }
        .background(Theme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Theme.blush100, lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Theme.ink.opacity(0.28).ignoresSafeArea())
    }
}

struct SoftField<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.blush200, lineWidth: 1)
            )
    }
}

struct FieldLabel: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.ink)
    }
}

struct SectionLabel: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.inkMuted)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}

func dialogPresentation() -> some ViewModifier {
    DialogPresentation()
}

private struct DialogPresentation: ViewModifier {
    func body(content: Content) -> some View {
        content
            .presentationBackground(.clear)
            .presentationDragIndicator(.hidden)
            .presentationDetents([.large])
    }
}

extension View {
    func periDialog() -> some View {
        modifier(DialogPresentation())
    }
}
