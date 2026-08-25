import SwiftUI
import PeriMediDomain

struct SymptomSheet: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dialogClose) private var dialogClose

    let dateKey: String

    @State private var kind: RemarkKind = .cycle
    @State private var bodyText = ""
    @State private var editing: Remark?

    private var dayNotes: [Remark] {
        store.remarks.filter { DateKeys.toDateKey($0.occurredOn) == dateKey }
    }

    var body: some View {
        DialogChrome(title: app.t("symptom.title"), icon: "ActionSymptom", identifier: A11yID.sheetSymptom, onClose: {
            dialogClose()
            dismiss()
        }) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 4) {
                    Text(app.t("symptom.date")).foregroundStyle(Theme.inkSoft)
                    Text(pretty(dateKey)).fontWeight(.semibold).foregroundStyle(Theme.ink)
                }
                .font(.subheadline)

                SectionLabel(text: editing == nil ? app.t("symptom.addSection") : app.t("symptom.saveEdit"))
                FieldLabel(text: app.t("symptom.type"))
                SoftField {
                    Picker("", selection: $kind) {
                        ForEach(RemarkKind.allCases, id: \.self) { k in
                            Text(app.t("remark.\(k.rawValue)")).tag(k)
                        }
                    }
                    .labelsHidden()
                    .tint(Theme.ink)
                }
                FieldLabel(text: app.t("symptom.description"))
                SoftField {
                    TextField(app.t("symptom.placeholder"), text: $bodyText, axis: .vertical)
                        .lineLimit(3...5)
                        .submitLabel(.done)
                        .accessibilityIdentifier(A11yID.symptomBody)
                }

                HStack(spacing: 10) {
                    PillButton(
                        title: app.t(editing == nil ? "symptom.saveAdd" : "symptom.saveEdit"),
                        kind: .primary,
                        identifier: A11yID.symptomSave
                    ) {
                        saveNote()
                    }
                    PillButton(title: app.t("common.close"), kind: .secondary) {
                        dialogClose()
                        dismiss()
                    }
                    Spacer()
                }

                Rectangle().fill(Theme.blush100).frame(height: 1)
                SectionLabel(text: app.t("symptom.logged"))
                if dayNotes.isEmpty {
                    Text(app.t("symptom.empty")).font(.caption).foregroundStyle(Theme.inkMuted)
                }
                VStack(spacing: 0) {
                    ForEach(Array(dayNotes.enumerated()), id: \.element.id) { index, note in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.t("remark.\(note.kind.rawValue)"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                Text(note.body)
                                    .font(.caption)
                                    .foregroundStyle(Theme.inkMuted)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 4)
                            IconCircleButton(systemName: "pencil", label: app.t("common.edit")) {
                                editing = note
                                kind = note.kind
                                bodyText = note.body
                            }
                            IconCircleButton(systemName: "trash", label: app.t("common.delete"), tint: Theme.blush800) {
                                app.askConfirm(
                                    message: app.t("symptom.deleteConfirm"),
                                    confirmLabel: app.t("common.delete"),
                                    destructive: true
                                ) {
                                    store.deleteRemark(id: note.id)
                                    if editing?.id == note.id {
                                        editing = nil
                                        bodyText = ""
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        if index < dayNotes.count - 1 {
                            Rectangle().fill(Theme.blush100).frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private func saveNote() {
        let text = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let editing {
            store.updateRemark(id: editing.id, kind: kind, body: text)
        } else {
            store.addRemark(
                Remark(
                    id: createId(),
                    occurredOn: dateKey,
                    kind: kind,
                    body: text,
                    createdAt: ISO8601DateFormatter().string(from: Date())
                )
            )
        }
        editing = nil
        bodyText = ""
    }

    private func pretty(_ key: String) -> String {
        guard let date = DateKeys.parseDateKey(key) else { return key }
        let f = DateFormatter()
        f.locale = app.locale.language.locale
        f.setLocalizedDateFormatFromTemplate("MMMMd yyyy")
        return f.string(from: date)
    }
}
