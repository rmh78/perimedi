import SwiftUI
import PeriMediDomain

struct SymptomSheet: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dialogClose) private var dialogClose

    let dateKey: String

    @State private var severity: [String: Int] = [:]
    @State private var draft = ""
    @State private var nameError: SymptomEditError?
    @State private var editing: CustomSymptomId?
    @State private var renameDraft = ""

    private var dayScores: [SymptomScore] {
        store.symptomScores.filter { $0.date == dateKey }
    }

    var body: some View {
        DialogChrome(title: app.t("symptom.title"), icon: "ActionSymptom", identifier: A11yID.sheetSymptom, onClose: {
            dialogClose()
            dismiss()
        }, content: {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(app.t("symptom.date")).foregroundStyle(Theme.inkSoft)
                        Text(pretty(dateKey)).fontWeight(.semibold).foregroundStyle(Theme.ink)
                    }
                    .font(.subheadline)

                    Text(app.t("symptom.scaleBlank"))
                        .font(.caption2)
                        .foregroundStyle(Theme.inkMuted)
                }

                ForEach(Array(store.symptomDirectory.blocks.enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .catalog(let group, let ids):
                        groupTitle(app.t("symptom.group.\(group.rawValue)"))
                        VStack(spacing: 5) {
                            ForEach(ids, id: \.self) { id in
                                scoreRow(ref: .catalog(id), title: app.symptomTitle(id.rawValue))
                            }
                        }
                    case .custom(let rows):
                        groupTitle(app.t("symptom.group.custom"))
                        VStack(spacing: 5) {
                            ForEach(rows) { symptom in
                                customRow(symptom)
                            }
                        }
                        addRow
                    }
                }
            }
            .padding(.bottom, 28)
            .onAppear(perform: loadDay)
        })
    }

    private var atCap: Bool {
        store.symptomDirectory.customs.count >= SymptomDirectory.addCap
    }

    private var addRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                TextField(app.t("symptom.addPlaceholder"), text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .font(.footnote)
                    .disabled(atCap)
                    .accessibilityIdentifier(A11yID.symptomCustomAdd)
                    .onSubmit(create)
                Button(app.t("symptom.addAction"), action: create)
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.blush800)
                    .disabled(atCap)
                    .accessibilityIdentifier(A11yID.symptomCustomCreate)
            }
            if atCap {
                Text(app.t("symptom.tooMany"))
                    .font(.caption2)
                    .foregroundStyle(Theme.blush800)
            } else if let nameError, let message = nameMessage(nameError) {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(Theme.blush800)
            }
        }
        .padding(.top, 12)
    }

    private func customRow(_ symptom: CustomSymptom) -> some View {
        let renaming = editing == symptom.id
        return VStack(alignment: .leading, spacing: 4) {
            scoreRow(
                ref: .custom(symptom.id),
                title: symptom.name,
                nameControl: AnyView(renaming ? AnyView(renameField(symptom.id)) : AnyView(nameButton(symptom)))
            )
            HStack {
                if renaming {
                    renameSave(symptom.id)
                } else {
                    renameStart(symptom)
                    deleteButton(symptom)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func renameField(_ id: CustomSymptomId) -> some View {
        TextField(app.t("symptom.addPlaceholder"), text: $renameDraft)
            .textFieldStyle(.roundedBorder)
            .font(.footnote)
            .accessibilityIdentifier(A11yID.symptomCustomName(id.rawValue))
            .onSubmit { rename(id) }
    }

    private func renameSave(_ id: CustomSymptomId) -> some View {
        Button(app.t("symptom.saveEdit"), action: { rename(id) })
            .font(.caption2.weight(.semibold))
            .buttonStyle(.plain)
            .foregroundStyle(Theme.blush800)
            .accessibilityIdentifier(A11yID.symptomCustomSave(id.rawValue))
    }

    private func renameStart(_ symptom: CustomSymptom) -> some View {
        Button(app.t("symptom.rename")) {
            editing = symptom.id
            renameDraft = symptom.name
            nameError = nil
        }
        .font(.caption2.weight(.semibold))
        .buttonStyle(.plain)
        .foregroundStyle(Theme.blush800)
        .accessibilityIdentifier(A11yID.symptomCustomRename(symptom.id.rawValue))
    }

    private func nameButton(_ symptom: CustomSymptom) -> some View {
        Button {
            editing = symptom.id
            renameDraft = symptom.name
            nameError = nil
        } label: {
            Text(symptom.name)
                .font(.footnote)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(A11yID.symptomCustomName(symptom.id.rawValue))
        .disabled(editing == symptom.id)
    }

    private func deleteButton(_ symptom: CustomSymptom) -> some View {
        let id = symptom.id
        return Button {
            app.askConfirm(
                message: app.t("symptom.deleteScores", ["name": symptom.name]),
                confirmLabel: app.t("common.delete")
            ) {
                try? store.deleteCustomSymptom(id: id)
                severity[id.rawValue] = nil
                if editing == id { editing = nil }
            }
        } label: {
            Text(app.t("common.delete"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.blush800)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(A11yID.symptomCustomDelete(id.rawValue))
    }

    private func groupTitle(_ title: String) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.blush100)
                .frame(height: 1)
                .padding(.horizontal, -16)
                .padding(.top, 8)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
    }

    private func scoreRow(
        ref: SymptomRef,
        title: String,
        nameControl: AnyView? = nil
    ) -> some View {
        let key = ref.storageId
        let chosen = severity[key]
        return HStack(alignment: .center, spacing: 8) {
            Group {
                if let nameControl {
                    nameControl
                } else {
                    Text(title)
                        .font(.footnote)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(width: 108, alignment: .leading)
            HStack(spacing: 5) {
                ForEach(1...4, id: \.self) { value in
                    let selected = chosen == value
                    let word = app.symptomLevelWord(key, severity: value)
                    Button {
                        choose(ref, value: value)
                    } label: {
                        VStack(spacing: 0) {
                            Text("\(value)")
                                .font(.caption2.weight(.semibold))
                            Text(word)
                                .font(.system(size: 8, weight: selected ? .semibold : .regular))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(selected ? .white : Theme.blush800)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selected ? Theme.blush600 : Theme.blush50)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title), \(word)")
                    .accessibilityIdentifier(A11yID.symptomScore(key, value))
                    .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
                }
            }
        }
    }

    private func choose(_ ref: SymptomRef, value: Int) {
        let key = ref.storageId
        let next = severity[key] == value ? nil : value
        severity[key] = next
        try? store.setDaySeverity(date: dateKey, ref: ref, severity: next)
    }

    private func create() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            _ = try store.addCustomSymptom(name: draft)
            draft = ""
            nameError = nil
        } catch let error as SymptomEditError {
            nameError = error
        } catch {}
    }

    private func rename(_ id: CustomSymptomId) {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try store.renameCustomSymptom(id: id, name: renameDraft)
            editing = nil
            nameError = nil
        } catch let error as SymptomEditError {
            nameError = error
        } catch {}
    }

    private func nameMessage(_ error: SymptomEditError) -> String? {
        switch error {
        case .duplicateName: return app.t("symptom.nameDuplicate")
        case .nameTooLong: return app.t("symptom.nameTooLong")
        case .tooMany: return app.t("symptom.tooMany")
        case .blankName, .unknownId: return nil
        }
    }

    private func loadDay() {
        var next: [String: Int] = [:]
        for score in dayScores {
            guard SymptomRef.parse(score.id) != nil, (1...4).contains(score.severity) else { continue }
            next[score.id] = score.severity
        }
        severity = next
    }

    private func pretty(_ key: String) -> String {
        guard let date = DateKeys.parseDateKey(key) else { return key }
        let f = DateFormatter()
        f.locale = app.locale.language.locale
        f.setLocalizedDateFormatFromTemplate("MMMMd yyyy")
        return f.string(from: date)
    }
}
