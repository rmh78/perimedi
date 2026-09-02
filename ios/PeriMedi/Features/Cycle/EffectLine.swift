import SwiftUI
import PeriMediDomain

struct EffectLine: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: Store

    var body: some View {
        let result = EffectLogic.summarize(
            today: DateKeys.todayKey(),
            periods: store.periods,
            settings: store.settings,
            scores: store.symptomScores,
            changes: store.medicationChanges
        )
        if let text = effectText(result) {
            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(A11yID.cycleEffect)
                .accessibilityValue(effectValue(result))
        }
    }

    private func effectText(_ result: EffectResult) -> String? {
        let body: String
        switch result.kind {
        case .hidden:
            return nil
        case .noPreviousCycle:
            body = app.t("effect.noPrevious")
        case .notEnoughDays:
            body = app.t("effect.notEnough")
        case .similar:
            body = app.t("effect.similar")
        case .changed(let shifts):
            let clauses = shifts.map { shift in
                let name = app.t("symptom.id.\(shift.id)")
                let key = shift.direction == .improved ? "effect.clause.down" : "effect.clause.worse"
                return app.t(key, ["name": name])
            }
            var sentence = clauses.joined(separator: app.t("effect.join"))
            if shifts.last?.direction == .worse {
                sentence += app.t("effect.thanLast")
            }
            body = sentence
        }
        if let ctx = result.context {
            let key = ctx.field == .dose ? "effect.sinceDose" : "effect.sinceSchedule"
            return app.t(key, ["name": ctx.nameSnapshot]) + body
        }
        return body
    }

    private func effectValue(_ result: EffectResult) -> String {
        switch result.kind {
        case .hidden:
            return ""
        case .noPreviousCycle:
            return "no-previous"
        case .notEnoughDays:
            return "not-enough"
        case .similar:
            return "similar"
        case .changed(let shifts):
            return shifts.map { shift in
                "\(shift.id):\(shift.direction == .improved ? "down" : "worse")"
            }.joined(separator: ",")
        }
    }
}
