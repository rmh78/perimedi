import SwiftUI
import PeriMediDomain

struct SymptomSheet: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dialogClose) private var dialogClose

    let dateKey: String

    private enum NameDraft: Equatable {
        case create
        case edit(CustomSymptomId)
        case confirmDelete(CustomSymptomId)
    }

    @State private var severity: [String: Int] = [:]
    @State private var draft = ""
    @State private var nameError: SymptomEditError?
    @State private var nameDraft: NameDraft?
    @FocusState private var nameFocused: Bool

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
        .overlay {
            if nameDraft != nil {
                nameDialog
            }
        }
    }

    private var atCap: Bool {
        store.symptomDirectory.customs.count >= SymptomDirectory.addCap
    }

    private var addRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            if atCap {
                Text(app.t("symptom.tooMany"))
                    .font(.caption2)
                    .foregroundStyle(Theme.blush800)
            } else if nameDraft == nil {
                PillButton(
                    title: app.t("symptom.addAction"),
                    kind: .secondary,
                    identifier: A11yID.symptomCustomCreate
                ) {
                    openDraft(.create, name: "")
                }
            }
        }
        .padding(.top, 12)
    }

    private var nameDialog: some View {
        ZStack(alignment: .bottom) {
            Theme.ink.opacity(0.28)
                .onTapGesture { closeDraft() }
            Group {
                if case .confirmDelete(let id) = nameDraft {
                    deletePrompt(id)
                } else {
                    editorFields
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
            .padding(.bottom, 12)
        }
        .accessibilityAddTraits(.isModal)
        .onAppear { nameFocused = nameDraft != nil }
    }

    private var editorFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(nameDraft == .create ? app.t("symptom.addAction") : app.t("symptom.rename"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            TextField(app.t("symptom.addPlaceholder"), text: $draft)
                .textFieldStyle(.roundedBorder)
                .font(.footnote)
                .focused($nameFocused)
                .submitLabel(.done)
                .accessibilityIdentifier(A11yID.symptomCustomAdd)
                .onSubmit(commitDraft)
            if let nameError, let message = nameMessage(nameError) {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(Theme.blush800)
            }
            HStack(spacing: 8) {
                PillButton(title: app.t("common.cancel"), kind: .secondary) {
                    closeDraft()
                }
                Spacer(minLength: 0)
                commitButton
            }
            if case .edit(let id) = nameDraft {
                PillButton(
                    title: app.t("common.delete"),
                    kind: .destructive,
                    identifier: A11yID.symptomCustomDelete(id.rawValue)
                ) {
                    nameFocused = false
                    nameDraft = .confirmDelete(id)
                }
            }
        }
    }

    private func deletePrompt(_ id: CustomSymptomId) -> some View {
        let name = store.symptomDirectory.customs.first { $0.id == id }?.name ?? draft
        return VStack(alignment: .leading, spacing: 12) {
            Text(app.t("confirm.title"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(app.t("symptom.deleteScores", ["name": name]))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
            HStack(spacing: 8) {
                PillButton(title: app.t("common.cancel"), kind: .secondary, identifier: A11yID.confirmCancel) {
                    nameDraft = .edit(id)
                    nameFocused = true
                }
                Spacer(minLength: 0)
                PillButton(
                    title: app.t("common.delete"),
                    kind: .destructive,
                    identifier: A11yID.confirmDelete
                ) {
                    try? store.deleteCustomSymptom(id: id)
                    severity[id.rawValue] = nil
                    closeDraft()
                }
            }
        }
    }

    @ViewBuilder
    private var commitButton: some View {
        switch nameDraft {
        case .create:
            PillButton(
                title: app.t("symptom.addAction"),
                kind: .primary,
                identifier: A11yID.symptomCustomCreate,
                action: commitDraft
            )
        case .edit(let id):
            PillButton(
                title: app.t("symptom.saveEdit"),
                kind: .primary,
                identifier: A11yID.symptomCustomSave(id.rawValue),
                action: commitDraft
            )
        case .confirmDelete, nil:
            EmptyView()
        }
    }

    private func customRow(_ symptom: CustomSymptom) -> some View {
        scoreRow(ref: .custom(symptom.id), title: symptom.name, nameWidth: 136) {
            openDraft(.edit(symptom.id), name: symptom.name)
        }
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
        nameWidth: CGFloat = 108,
        onName: (() -> Void)? = nil
    ) -> some View {
        let key = ref.storageId
        let chosen = severity[key]
        return HStack(alignment: .center, spacing: 8) {
            Group {
                if let onName {
                    Button(action: onName) {
                        Text(title)
                            .font(.footnote)
                            .underline()
                            .foregroundStyle(Theme.blush700)
                            .lineLimit(2)
                            .minimumScaleFactor(0.65)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(A11yID.symptomCustomName(key))
                } else {
                    Text(title)
                        .font(.footnote)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(width: nameWidth, alignment: .leading)
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

    private func openDraft(_ mode: NameDraft, name: String) {
        nameDraft = mode
        draft = name
        nameError = nil
        nameFocused = true
    }

    private func closeDraft() {
        nameDraft = nil
        draft = ""
        nameError = nil
        nameFocused = false
    }

    private func commitDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            switch nameDraft {
            case .create:
                _ = try store.addCustomSymptom(name: draft)
            case .edit(let id):
                try store.renameCustomSymptom(id: id, name: draft)
            case .confirmDelete, nil:
                return
            }
            closeDraft()
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
