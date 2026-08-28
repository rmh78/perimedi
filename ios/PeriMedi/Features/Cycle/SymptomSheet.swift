import SwiftUI
import PeriMediDomain

struct SymptomSheet: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dialogClose) private var dialogClose

    let dateKey: String

    @State private var severity: [SymptomId: Int] = [:]

    private var dayScores: [SymptomScore] {
        store.symptomScores.filter { $0.date == dateKey }
    }

    var body: some View {
        DialogChrome(title: app.t("symptom.title"), icon: "ActionSymptom", identifier: A11yID.sheetSymptom, onClose: {
            persist(severity)
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

                ForEach(SymptomGroup.allCases, id: \\.self) { group in
                    Text(app.t("symptom.group.\(group.rawValue)"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    VStack(spacing: 5) {
                        ForEach(group.ids, id: \\.self) { id in
                            scoreRow(id)
                        }
                    }
                }

            }
            .padding(.bottom, 8)
            .onAppear(perform: loadDay)
        })
    }

    private func scoreRow(_ id: SymptomId) -> some View {
        let chosen = severity[id]
        return HStack(alignment: .center, spacing: 8) {
            Text(app.t("symptom.id.\(id.rawValue)"))
                .font(.footnote)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .truncationMode(.tail)
                .frame(width: 108, alignment: .leading)
            HStack(spacing: 5) {
                ForEach(1...4, id: \\.self) { value in
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
                    .accessibilityLabel("\(app.t("symptom.id.\(id.rawValue)")), \(word)")
                    .accessibilityIdentifier(A11yID.symptomScore(id.rawValue, value))
                    .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
                }
            }
        }
    }

    private func loadDay() {
        var next: [SymptomId: Int] = [:]
        for score in dayScores {
            guard let id = SymptomId(rawValue: score.id) else { continue }
            if (1...4).contains(score.severity) {
                next[id] = score.severity
            }
        }
        severity = next
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
        store.replaceDayScores(date: dateKey, scores: scores, note: nil, noteId: nil)
    }

    private func pretty(_ key: String) -> String {
        guard let date = DateKeys.parseDateKey(key) else { return key }
        let f = DateFormatter()
        f.locale = app.locale.language.locale
        f.setLocalizedDateFormatFromTemplate("MMMMd yyyy")
        return f.string(from: date)
    }
}
