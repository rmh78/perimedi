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
        if let text = EffectCopy.sentence(result, t: app.t) {
            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(A11yID.cycleEffect)
                .accessibilityValue(effectValue(result))
        }
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
