import SwiftUI
import PeriMediDomain

struct SymptomSheet: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dialogClose) private var dialogClose

    let dateKey: String

    @State private var severity: [SymptomId: Int] = [:]
    @State private var hotCount: Int?
    @State private var noteText = ""
    @State private var noteId: String?

    private var dayScores: [SymptomScore] {
        store.symptomScores.filter { $0.date == dateKey }
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

                Text(app.t("symptom.scaleHint"))
                    .font(.caption)
                    .foregroundStyle(Theme.inkMuted)

                ForEach(SymptomGroup.allCases, id: \.self) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: app.t("symptom.group.\(group.rawValue)"))
                        VStack(spacing: 0) {
                            ForEach(Array(group.ids.enumerated()), id: \.element) { index, id in
                                scoreRow(id)
                                if index < group.ids.count - 1 {
                                    Rectangle().fill(Theme.blush100).frame(height: 1)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: app.t("symptom.note"))
                    SoftField {
                        TextField(app.t("symptom.notePlaceholder"), text: $noteText)
                            .foregroundStyle(Theme.ink)
                            .submitLabel(.done)
                            .accessibilityIdentifier(A11yID.symptomBody)
                    }
                }

                HStack(spacing: 10) {
                    PillButton(
                        title: app.t("symptom.saveEdit"),
                        kind: .primary,
                        identifier: A11yID.symptomSave
                    ) {
                        saveDay()
                    }
                    PillButton(title: app.t("common.close"), kind: .secondary) {
                        dialogClose()
                        dismiss()
                    }
                    Spacer()
                }
            }
            .onAppear(perform: loadDay)
        }
    }

    private func scoreRow(_ id: SymptomId) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(app.t("symptom.id.\(id.rawValue)"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 4) {
                    ForEach(0...4, id: \.self) { value in
                        let selected = severity[id] == value
                        Button {
                            if severity[id] == value {
                                severity[id] = nil
                                if id == .hot_flash { hotCount = nil }
                            } else {
                                severity[id] = value
                            }
                        } label: {
                            Text("\(value)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selected ? .white : Theme.blush700)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(selected ? Theme.blush600 : Theme.blush50))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(app.t("symptom.id.\(id.rawValue)")) \(value)")
                        .accessibilityIdentifier(A11yID.symptomScore(id.rawValue, value))
                        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
                    }
                }
            }
            if id == .hot_flash {
                HStack {
                    Text(app.t("symptom.count"))
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                    Spacer()
                    Stepper(value: hotCountBinding, in: 0...99) {
                        Text("\(hotCount ?? 0)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Theme.ink)
                            .frame(minWidth: 24, alignment: .trailing)
                    }
                    .accessibilityIdentifier(A11yID.symptomCount)
                    .disabled(severity[.hot_flash] == nil)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var hotCountBinding: Binding<Int> {
        Binding(
            get: { hotCount ?? 0 },
            set: { hotCount = $0 }
        )
    }

    private func loadDay() {
        var next: [SymptomId: Int] = [:]
        hotCount = nil
        for score in dayScores {
            guard let id = SymptomId(rawValue: score.id) else { continue }
            next[id] = score.severity
            if id == .hot_flash {
                hotCount = score.count
            }
            if noteText.isEmpty, let n = score.note, !n.isEmpty {
                noteText = n
            }
        }
        severity = next
        if let remark = store.remarks.first(where: { DateKeys.toDateKey($0.occurredOn) == dateKey }) {
            noteId = remark.id
            if noteText.isEmpty {
                noteText = remark.body
            }
        }
    }

    private func saveDay() {
        let loggedAt = ISO8601DateFormatter().string(from: Date())
        var scores: [SymptomScore] = []
        for id in SymptomId.allCases {
            guard let value = severity[id] else { continue }
            var count: Int?
            if id == .hot_flash, let hotCount {
                count = hotCount
            }
            scores.append(
                SymptomScore(
                    id: id.rawValue,
                    date: dateKey,
                    severity: value,
                    count: count,
                    loggedAt: loggedAt,
                    higherIsWorse: true
                )
            )
        }
        store.replaceDayScores(date: dateKey, scores: scores, note: noteText, noteId: noteId)
        dialogClose()
        dismiss()
    }

    private func pretty(_ key: String) -> String {
        guard let date = DateKeys.parseDateKey(key) else { return key }
        let f = DateFormatter()
        f.locale = app.locale.language.locale
        f.setLocalizedDateFormatFromTemplate("MMMMd yyyy")
        return f.string(from: date)
    }
}
