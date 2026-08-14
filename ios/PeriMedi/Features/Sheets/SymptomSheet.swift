import SwiftUI
import PeriMediDomain

struct SymptomSheet: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    let dateKey: String

    @State private var kind: RemarkKind = .cycle
    @State private var bodyText = ""
    @State private var editing: Remark?

    private var dayNotes: [Remark] {
        store.remarks.filter { DateKeys.toDateKey($0.occurredOn) == dateKey }
    }

    var body: some View {
        DialogChrome(title: app.t("symptom.title"), icon: "ActionSymptom", onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 4) {
                    Text(app.t("symptom.date")).foregroundStyle(Theme.inkSoft)
                    Text(pretty(dateKey)).fontWeight(.semibold).foregroundStyle(Theme.ink)
                }
                .font(.subheadline)

                SectionLabel(text: app.t("symptom.logged"))
                if dayNotes.isEmpty {
                    Text(app.t("symptom.empty")).font(.caption).foregroundStyle(Theme.inkMuted)
                }
                ForEach(dayNotes) { note in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.t("remark.\(note.kind.rawValue)"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(hex: "#6d28d9"))
                            Text(note.body).font(.subheadline).foregroundStyle(Theme.ink)
                        }
                        Spacer()
                        Button(app.t("common.edit")) {
                            editing = note
                            kind = note.kind
                            bodyText = note.body
                        }
                        .buttonStyle(.bordered)
                        Button(app.t("common.delete")) { store.deleteRemark(id: note.id) }
                            .buttonStyle(.bordered)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.blush700)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).stroke(Theme.blush200))
                }

                Rectangle().fill(Theme.blush100).frame(height: 1)
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
                }

                HStack(spacing: 10) {
                    PillButton(title: app.t(editing == nil ? "symptom.saveAdd" : "symptom.saveEdit"), filled: true) {
                        saveNote()
                    }
                    PillButton(title: app.t("common.close"), filled: false) { dismiss() }
                    Spacer()
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
