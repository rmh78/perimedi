import SwiftUI
import PeriMediDomain

struct SymptomSheet: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dialogClose) private var dialogClose

    let dateKey: String

    @State private var severity: [SymptomId: Int] = [:]
    @State private var noteText = ""
    @State private var noteId: String?

    private var dayScores: [SymptomScore] {
        store.symptomScores.filter { $0.date == dateKey }
    }

    var body: some View {
        DialogChrome(title: app.t("symptom.title"), icon: "ActionSymptom", identifier: A11yID.sheetSymptom, onClose: {
            persist(severity)
            dialogClose()
            dismiss()
        }, content: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text(app.t("symptom.date")).foregroundStyle(Theme.inkSoft)
                    Text(pretty(dateKey)).fontWeight(.semibold).foregroundStyle(Theme.ink)
                }
                .font(.subheadline)

                Text(app.t("symptom.scaleBlank"))
                    .font(.caption2)
                    .foregroundStyle(Theme.inkMuted)

                ForEach(SymptomGroup.allCases, id: \.self) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.t("symptom.group.\(group.rawValue)"))
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                        VStack(spacing: 0) {
                            ForEach(group.ids, id: \.self) { id in
                                scoreRow(id)
                            }
                        }
                    }
                }

            }
            .onAppear(perform: loadDay)
            .onChange(of: noteText) { _, _ in persist(severity) }
        }, footer: {
            VStack(alignment: .leading, spacing: 8) {
                Rectangle().fill(Theme.blush100).frame(height: 1)
                SoftField {
                    TextField(app.t("symptom.notePlaceholder"), text: $noteText)
                        .foregroundStyle(Theme.ink)
                        .submitLabel(.done)
                        .accessibilityIdentifier(A11yID.symptomBody)
                        .accessibilityLabel(app.t("symptom.note"))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
        })
    }

    private func scoreRow(_ id: SymptomId) -> some View {
        let chosen = severity[id]
        return HStack(alignment: .center, spacing: 6) {
            Text(app.t("symptom.id.\(id.rawValue)"))
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(width: 78, alignment: .leading)
            HStack(spacing: 4) {
                ForEach(1...4, id: \.self) { value in
                    let selected = chosen == value
                    let word = app.t("symptom.level.\(id.rawValue).\(value)")
                    Button {
                        var next = severity
                        if next[id] == value {
                            next[id] = nil
                        } else {
                            next[id] = value
                        }
                        severity = next
                        persist(next)
                    } label: {
                        VStack(spacing: 1) {
                            Text("\(value)")
                                .font(.caption.weight(.semibold))
                            Text(word)
                                .font(.system(size: 9, weight: selected ? .semibold : .regular))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(selected ? .white : Theme.blush800)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selected ? Theme.blush600 : Theme.blush50)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(app.t("symptom.id.\(id.rawValue)")), \(word)")
                    .accessibilityIdentifier(A11yID.symptomScore(id.rawValue, value))
                    .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func loadDay() {
        var next: [SymptomId: Int] = [:]
        for score in dayScores {
            guard let id = SymptomId(rawValue: score.id) else { continue }
            if (1...4).contains(score.severity) {
                next[id] = score.severity
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

    private func persist(_ map: [SymptomId: Int]) {
        let loggedAt = ISO8601DateFormatter().string(from: Date())
        var scores: [SymptomScore] = []
        for id in SymptomId.allCases {
            guard let value = map[id], (1...4).contains(value) else { continue }
            scores.append(
                SymptomScore(
                    id: id.rawValue,
                    date: dateKey,
                    severity: value,
                    loggedAt: loggedAt,
                    higherIsWorse: true
                )
            )
        }
        store.replaceDayScores(date: dateKey, scores: scores, note: noteText, noteId: noteId)
        if noteId == nil {
            noteId = store.remarks.first { DateKeys.toDateKey($0.occurredOn) == dateKey }?.id
        }
    }

    private func pretty(_ key: String) -> String {
        guard let date = DateKeys.parseDateKey(key) else { return key }
        let f = DateFormatter()
        f.locale = app.locale.language.locale
        f.setLocalizedDateFormatFromTemplate("MMMMd yyyy")
        return f.string(from: date)
    }
}
