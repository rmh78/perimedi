import SwiftUI
import UIKit
import PeriMediDomain

private struct DialogCloseKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

private struct DialogMaxHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 640
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension EnvironmentValues {
    var dialogClose: () -> Void {
        get { self[DialogCloseKey.self] }
        set { self[DialogCloseKey.self] = newValue }
    }

    var dialogMaxHeight: CGFloat {
        get { self[DialogMaxHeightKey.self] }
        set { self[DialogMaxHeightKey.self] = newValue }
    }
}

struct DialogChrome<Content: View>: View {
    var title: String
    var icon: String?
    var iconAccent: Color? = nil
    var identifier: String? = nil
    var onClose: () -> Void
    @ViewBuilder var content: () -> Content

    @EnvironmentObject private var app: AppModel
    @Environment(\.dialogMaxHeight) private var maxHeight
    @State private var bodyHeight: CGFloat = 360

    private let headerHeight: CGFloat = 69

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let icon {
                    Image(icon)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .padding(3)
                        .background(Circle().fill(iconAccent ?? Theme.blush50))
                }
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .a11y(identifier)
                    .onTapGesture(perform: resignKeyboard)
                Spacer(minLength: 8)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.blush800)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.blush50))
                }
                .accessibilityLabel("Close")
                .accessibilityIdentifier(A11yID.sheetClose)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Rectangle().fill(Theme.blush100).frame(height: 1)

            ScrollView {
                content()
                    .padding(16)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                        }
                    )
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .frame(height: min(bodyHeight, max(80, maxHeight - headerHeight)))
            .onPreferenceChange(ContentHeightKey.self) { bodyHeight = $0 }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(app.t("common.done"), action: resignKeyboard)
                .accessibilityIdentifier("keyboard.done")
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
        .frame(maxWidth: .infinity, alignment: .bottom)
    }

    private func resignKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

struct DateKeyPicker: View {
    @Binding var key: String
    var allowEmpty = false
    var identifier: String? = nil

    @Environment(\.locale) private var locale
    @State private var date = Date()
    @State private var showPicker = false

    var body: some View {
        Button {
            if key.isEmpty {
                let seed = DateKeys.todayKey()
                key = seed
                date = DateKeys.parseDateKey(seed) ?? Date()
            }
            showPicker = true
        } label: {
            Text(key.isEmpty ? "YYYY-MM-DD" : key)
                .font(.body)
                .foregroundStyle(key.isEmpty ? Theme.inkMuted : Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .a11y(identifier)
        .accessibilityValue(key)
        .sheet(isPresented: $showPicker) {
            VStack(spacing: 12) {
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .environment(\.calendar, DateKeys.calendar)
                    .environment(\.locale, locale)
                    .tint(Theme.blush600)
                    .onChange(of: date) { _, new in
                        key = DateKeys.toDateKey(new)
                    }
                HStack {
                    if allowEmpty {
                        Button("Clear") {
                            key = ""
                            showPicker = false
                        }
                        .foregroundStyle(Theme.inkMuted)
                    }
                    Spacer()
                    Button("Done") { showPicker = false }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.blush700)
                        .accessibilityIdentifier(A11yID.dateDone)
                }
                .padding(.horizontal, 4)
            }
            .padding()
            .environment(\.locale, locale)
            .environment(\.calendar, DateKeys.calendar)
            .presentationDetents([.medium])
            .presentationBackground(.ultraThinMaterial)
        }
        .onAppear { syncFromKey() }
        .onChange(of: showPicker) { _, open in
            if open { syncFromKey() }
        }
    }

    private func syncFromKey() {
        if let parsed = DateKeys.parseDateKey(key) {
            date = parsed
        }
    }
}

struct TimeOfDayPicker: View {
    @Binding var time: String
    var identifier: String? = nil
    var compact = false

    @Environment(\.locale) private var locale
    @State private var date = Date()
    @State private var showPicker = false

    var body: some View {
        Button {
            showPicker = true
        } label: {
            Text(time.isEmpty ? "08:00" : time)
                .font(.body)
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: compact ? nil : .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .a11y(identifier)
        .accessibilityValue(time)
        .sheet(isPresented: $showPicker) {
            VStack(spacing: 8) {
                DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.calendar, DateKeys.calendar)
                    .environment(\.locale, locale)
                    .tint(Theme.blush600)
                    .onChange(of: date) { _, new in
                        time = DateKeys.formatTimeOfDay(new)
                    }
                HStack {
                    Spacer()
                    Button("Done") { showPicker = false }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.blush700)
                        .accessibilityIdentifier(A11yID.timeDone)
                }
                .padding(.horizontal, 4)
            }
            .padding()
            .environment(\.locale, locale)
            .environment(\.calendar, DateKeys.calendar)
            .presentationDetents([.height(280)])
            .presentationBackground(.ultraThinMaterial)
        }
        .onAppear { syncFromTime() }
        .onChange(of: showPicker) { _, open in
            if open { syncFromTime() }
        }
    }

    private func syncFromTime() {
        date = DateKeys.parseTimeOfDay(time.isEmpty ? "08:00" : time)
    }
}

/// Flows children onto extra rows instead of shrinking them.
struct WrappingHStack: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(in: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arranged = arrange(in: bounds.width, subviews: subviews)
        for (subview, frame) in zip(subviews, arranged.frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(in maxWidth: CGFloat, subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, x - spacing)
        }
        return (frames, CGSize(width: min(usedWidth, maxWidth), height: y + rowHeight))
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

/// Partial-intensity blur. Fading `.ultraThinMaterial` with opacity kills sampling;
/// a blur animator parked at a fraction keeps frost without the full radius.
/// The animator is finished at the current frame so XCTest is not blocked waiting
/// for a paused animation to complete.
private final class IntensityBlurView: UIVisualEffectView {
    private let style: UIBlurEffect.Style
    var intensity: CGFloat {
        didSet { applyIntensity() }
    }

    private var clampedIntensity: CGFloat {
        min(max(intensity, 0.05), 0.95)
    }

    init(style: UIBlurEffect.Style, intensity: CGFloat) {
        self.style = style
        self.intensity = intensity
        super.init(effect: nil)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { nil }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { applyIntensity() }
    }

    private func applyIntensity() {
        effect = nil
        let animator = UIViewPropertyAnimator(duration: 1, curve: .linear)
        animator.addAnimations { [weak self] in
            self?.effect = UIBlurEffect(style: self?.style ?? .systemUltraThinMaterial)
        }
        animator.startAnimation()
        animator.pauseAnimation()
        animator.fractionComplete = clampedIntensity
        animator.stopAnimation(false)
        animator.finishAnimation(at: .current)
    }
}

private struct IntensityBlur: UIViewRepresentable {
    var intensity: CGFloat
    func makeUIView(context: Context) -> IntensityBlurView {
        IntensityBlurView(style: .systemUltraThinMaterial, intensity: intensity)
    }
    func updateUIView(_ uiView: IntensityBlurView, context: Context) {
        uiView.intensity = intensity
    }
}

struct DialogBackdrop<Content: View>: View {
    var onClose: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var shown = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                ZStack {
                    IntensityBlur(intensity: shown ? 0.22 : 0.05)
                    Theme.ink.opacity(shown ? 0.08 : 0)
                }
                .ignoresSafeArea()
                .onTapGesture(perform: requestClose)
                content()
                    .environment(\.dialogClose, requestClose)
                    .environment(\.dialogMaxHeight, geo.size.height * 0.9)
                    .offset(y: shown ? 0 : geo.size.height)
            }
        }
        .ignoresSafeArea()
        .accessibilityAddTraits(.isModal)
        .onAppear {
            if UIView.areAnimationsEnabled {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    shown = true
                }
            } else {
                shown = true
            }
        }
    }

    private func requestClose() {
        if UIView.areAnimationsEnabled {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.92)) {
                shown = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onClose()
            }
        } else {
            shown = false
            onClose()
        }
    }
}

struct ConfirmCard: View {
    @EnvironmentObject private var app: AppModel
    var prompt: ConfirmPrompt

    var body: some View {
        DialogBackdrop(onClose: { app.dismissConfirm() }) {
            VStack(alignment: .leading, spacing: 12) {
                Text(app.t("confirm.title"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(prompt.message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                HStack(spacing: 8) {
                    Spacer()
                    PillButton(title: app.t("common.cancel"), kind: .secondary, identifier: A11yID.confirmCancel) {
                        app.dismissConfirm()
                    }
                    PillButton(
                        title: prompt.confirmLabel,
                        kind: prompt.destructive ? .destructive : .primary,
                        identifier: prompt.destructive ? A11yID.confirmDelete : A11yID.confirmAction
                    ) {
                        let action = prompt.action
                        app.dismissConfirm()
                        action()
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cream)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Theme.blush100, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}

private struct DialogPresentation: ViewModifier {
    func body(content: Content) -> some View {
        content
            .presentationBackground(.ultraThinMaterial)
            .presentationDragIndicator(.hidden)
    }
}

extension View {
    func periDialog() -> some View {
        modifier(DialogPresentation())
    }
}
