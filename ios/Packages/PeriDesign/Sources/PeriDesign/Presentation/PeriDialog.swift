import SwiftUI
import UIKit

extension View {
    /// `onClose` runs after the exit, or in this turn when motion snaps.
    /// Read `dialogClose` in the modified content. A parent closure sees the outer layer.
    public func periDialog(onClose: @escaping () -> Void) -> some View {
        modifier(PeriDialogModifier(onClose: onClose))
    }
}

extension EnvironmentValues {
    /// Animated dismiss for the innermost presenter. Default does nothing.
    public var dialogClose: () -> Void {
        get { self[DialogCloseKey.self] }
        set { self[DialogCloseKey.self] = newValue }
    }

    public var dialogMaxHeight: CGFloat {
        get { self[DialogMaxHeightKey.self] }
        set { self[DialogMaxHeightKey.self] = newValue }
    }
}

private struct DialogCloseKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: () -> Void = {}
}

private struct DialogMaxHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 640
}

private struct PeriDialogModifier: ViewModifier {
    var onClose: () -> Void

    func body(content: Content) -> some View {
        PeriDialogPresenter(onClose: onClose) { content }
    }
}

private enum PeriDialogPolicy {
    static let entrance = Animation.spring(response: 0.42, dampingFraction: 0.86)
    static let exit = Animation.spring(response: 0.36, dampingFraction: 0.92)
    static let creamOpacity = 0.22
    static let inkOpacity = 0.28
    static let heightFraction: CGFloat = 0.92
    static let minimumHeight: CGFloat = 180

    static func snaps(animationsEnabled: Bool, reduceMotion: Bool) -> Bool {
        !animationsEnabled || reduceMotion
    }

    static func overlap(viewMaxY: CGFloat, keyboard: CGRect) -> CGFloat {
        guard !keyboard.isEmpty else { return 0 }
        return max(0, viewMaxY - keyboard.minY)
    }

    static func maxPanelHeight(availableHeight: CGFloat, overlap: CGFloat) -> CGFloat {
        max(minimumHeight, availableHeight - overlap) * heightFraction
    }
}

private struct PeriDialogPresenter<Content: View>: View {
    var onClose: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var shown = false
    @State private var closing = false
    @State private var keyboardFrame: CGRect = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let overlap = PeriDialogPolicy.overlap(
                viewMaxY: geo.frame(in: .global).maxY,
                keyboard: keyboardFrame
            )
            let available = max(0, geo.size.height - overlap)
            ZStack(alignment: .bottom) {
                veil
                    .ignoresSafeArea()
                    .onTapGesture(perform: requestClose)
                FittedCard(maxHeight: available) { content() }
                    .padding(.bottom, overlap)
                    .offset(y: shown ? 0 : geo.size.height)
                    .allowsHitTesting(!closing)
            }
            .environment(\.dialogClose, requestClose)
            .environment(
                \.dialogMaxHeight,
                PeriDialogPolicy.maxPanelHeight(
                    availableHeight: geo.size.height,
                    overlap: overlap
                )
            )
        }
        .accessibilityAddTraits(.isModal)
        .onAppear(perform: enter)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            syncKeyboard(note)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { note in
            setKeyboardFrame(.zero, from: note)
        }
    }

    private var veil: some View {
        ZStack {
            PeriColor.cream.opacity(shown ? PeriDialogPolicy.creamOpacity : 0)
            PeriColor.ink.opacity(shown ? PeriDialogPolicy.inkOpacity : 0)
        }
    }

    private var snaps: Bool {
        PeriDialogPolicy.snaps(
            animationsEnabled: UIView.areAnimationsEnabled,
            reduceMotion: reduceMotion
        )
    }

    private func enter() {
        guard !closing else { return }
        if snaps {
            shown = true
        } else {
            withAnimation(PeriDialogPolicy.entrance) {
                shown = true
            }
        }
    }

    private func requestClose() {
        guard !closing else { return }
        closing = true
        let close = onClose
        if snaps {
            shown = false
            close()
            return
        }
        withAnimation(PeriDialogPolicy.exit) {
            shown = false
        } completion: {
            close()
        }
    }

    private func syncKeyboard(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        setKeyboardFrame(frame, from: note)
    }

    private func setKeyboardFrame(_ frame: CGRect, from note: Notification) {
        let duration = (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        if snaps {
            keyboardFrame = frame
        } else {
            withAnimation(.easeOut(duration: duration)) {
                keyboardFrame = frame
            }
        }
    }
}

private struct HeightOfferLayout: Layout {
    var offer: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let width = proposal.width ?? offer
        let size = child.sizeThatFits(ProposedViewSize(width: width, height: offer))
        return CGSize(width: width, height: min(size.height, offer))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let child = subviews.first else { return }
        let size = child.sizeThatFits(ProposedViewSize(width: bounds.width, height: offer))
        let height = min(size.height, offer)
        child.place(
            at: CGPoint(x: bounds.minX, y: bounds.maxY - height),
            proposal: ProposedViewSize(width: bounds.width, height: offer)
        )
    }
}

private struct FittedCard<Content: View>: View {
    var maxHeight: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        HeightOfferLayout(offer: max(maxHeight, 1)) {
            content()
        }
    }
}

#if DEBUG
#Preview("Stacked cards") {
    PeriDialogPreviewHost()
}

private struct PeriDialogPreviewHost: View {
    @State private var sheet = false
    @State private var card = false

    var body: some View {
        ZStack {
            PeriColor.pageWash
            Button("Open sheet") { sheet = true }
        }
        .overlay {
            if sheet {
                PreviewSheetFace(card: $card)
                    .periDialog(onClose: { sheet = false })
            }
        }
    }
}

private struct PreviewSheetFace: View {
    @Binding var card: Bool
    @Environment(\.dialogClose) private var dialogClose

    var body: some View {
        VStack(spacing: PeriSpace.row) {
            Text("Sheet")
                .font(PeriFont.pillLabel)
                .foregroundStyle(PeriColor.ink)
            Button("Open card") { card = true }
            Button("Close") { dialogClose() }
        }
        .padding(PeriSpace.pad)
        .frame(maxWidth: .infinity)
        .background(PeriColor.cream)
        .clipShape(RoundedRectangle(cornerRadius: PeriRadius.card, style: .continuous))
        .padding(.horizontal, PeriSpace.pad)
        .padding(.bottom, PeriSpace.pad)
        .overlay {
            if card {
                PreviewCardFace()
                    .periDialog(onClose: { card = false })
            }
        }
    }
}

private struct PreviewCardFace: View {
    @Environment(\.dialogClose) private var dialogClose

    var body: some View {
        VStack(spacing: PeriSpace.row) {
            Text("Card")
                .font(PeriFont.pillLabel)
                .foregroundStyle(PeriColor.ink)
            Button("Close card") { dialogClose() }
        }
        .padding(PeriSpace.pad)
        .frame(maxWidth: .infinity)
        .background(PeriColor.cream)
        .clipShape(RoundedRectangle(cornerRadius: PeriRadius.card, style: .continuous))
        .padding(.horizontal, PeriSpace.pad)
        .padding(.bottom, PeriSpace.row)
    }
}
#endif
