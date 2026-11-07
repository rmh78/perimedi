import SwiftUI
import UIKit

public struct DialogAction: Identifiable {
    public var id: String
    public var title: String
    public var accessibilityIdentifier: String?
    public var action: () -> Void

    public init(
        id: String,
        title: String,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }
}

public struct DialogActions: View {
    private var slots: [Slot]

    public init(cancel: DialogAction, primary: DialogAction) {
        slots = [Slot(cancel, role: .secondary), Slot(primary, role: .primary)]
    }

    public init(cancel: DialogAction, destructive: DialogAction, primary: DialogAction) {
        slots = [
            Slot(cancel, role: .secondary),
            Slot(destructive, role: .destructive),
            Slot(primary, role: .primary),
        ]
    }

    public init(cancel: DialogAction, secondary: DialogAction, primary: DialogAction) {
        slots = [
            Slot(cancel, role: .secondary),
            Slot(secondary, role: .secondary),
            Slot(primary, role: .primary),
        ]
    }

    public init(cancel: DialogAction, destructivePrimary: DialogAction) {
        slots = [Slot(cancel, role: .secondary), Slot(destructivePrimary, role: .destructive)]
    }

    public init(primary: DialogAction) {
        slots = [Slot(primary, role: .primary)]
    }

    public init(secondary: DialogAction, primary: DialogAction) {
        slots = [Slot(secondary, role: .secondary), Slot(primary, role: .primary)]
    }

    public init(secondary: DialogAction, middle: DialogAction, primary: DialogAction) {
        slots = [
            Slot(secondary, role: .secondary),
            Slot(middle, role: .secondary),
            Slot(primary, role: .primary),
        ]
    }

    @ScaledMetric(relativeTo: .subheadline) private var subheadlineSize: CGFloat = 15
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Environment(\.locale) private var locale
    @State private var rowHeight: CGFloat = 0

    public var body: some View {
        let bold = legibilityWeight == .bold
        let open = rowHeight > 1
            ? rowHeight
            : max(
                DialogActionFit.rowHeight(scale: 1, lines: 1, base: subheadlineSize, bold: bold),
                DialogActionFit.rowHeight(scale: DialogActionFit.minLabelScale, lines: 2, base: subheadlineSize, bold: bold)
            )
        GeometryReader { geo in
            let titles = slots.map(\.title)
            let fit = DialogActionFit.largestWholeWordFit(
                titles: titles,
                rowWidth: geo.size.width,
                base: subheadlineSize,
                bold: bold,
                locale: locale
            )
            let height = DialogActionFit.rowHeight(scale: fit.scale, lines: fit.lines, base: subheadlineSize, bold: bold)
            let font = UIFont.systemFont(ofSize: subheadlineSize * fit.scale, weight: bold ? .bold : .semibold)
            let inset = fit.lines > 1
                ? DialogActionFit.inset(titles: titles, rowWidth: geo.size.width, font: font, locale: locale)
                : DialogActionFit.horizontalPadding
            let available = DialogActionFit.textWidth(rowWidth: geo.size.width, count: titles.count, inset: inset)
            HStack(spacing: DialogActionFit.spacing) {
                ForEach(slots) { slot in
                    let shown = fit.lines > 1
                        ? DialogActionFit.wrapped(slot.title, width: available, font: font, locale: locale)
                        : slot.title
                    Button(action: slot.action) {
                        Text(shown)
                    }
                    .buttonStyle(PeriButtonStyle(
                        role: slot.role,
                        fillsWidth: true,
                        lines: fit.lines,
                        labelScale: fit.scale,
                        barHeight: height - DialogActionFit.strokeWidth,
                        inset: inset
                    ))
                    .accessibilityLabel(DialogActionFit.spokenLabel(for: slot.title))
                    .modifier(DialogActionIdentifier(id: slot.accessibilityIdentifier))
                }
            }
            .preference(key: DialogActionRowHeightKey.self, value: height)
        }
        .frame(height: open)
        .onPreferenceChange(DialogActionRowHeightKey.self) { newValue in
            if abs(newValue - rowHeight) > 0.5 {
                rowHeight = newValue
            }
        }
    }
}

private struct Slot: Identifiable {
    var id: String
    var title: String
    var accessibilityIdentifier: String?
    var role: PeriButtonStyle.Role
    var action: () -> Void

    init(_ action: DialogAction, role: PeriButtonStyle.Role) {
        id = action.id
        title = action.title
        accessibilityIdentifier = action.accessibilityIdentifier
        self.role = role
        self.action = action.action
    }
}

private struct DialogActionIdentifier: ViewModifier {
    var id: String?

    func body(content: Content) -> some View {
        if let id, !id.isEmpty {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}

private struct DialogActionRowHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview("Edit symptom") {
    DialogActions(
        cancel: DialogAction(id: "cancel", title: "Cancel", action: {}),
        destructive: DialogAction(id: "delete", title: "Delete", action: {}),
        primary: DialogAction(id: "save", title: "Save", action: {})
    )
    .padding(PeriSpace.pad)
    .background(PeriColor.cream)
}

#Preview("Delete confirm") {
    DialogActions(
        cancel: DialogAction(id: "cancel", title: "Abbrechen", action: {}),
        destructivePrimary: DialogAction(id: "delete", title: "Löschen", action: {})
    )
    .padding(PeriSpace.pad)
    .background(PeriColor.cream)
}
