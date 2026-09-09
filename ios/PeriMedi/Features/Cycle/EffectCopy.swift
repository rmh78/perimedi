import PeriMediDomain

enum EffectCopy {
    static func sentence(
        _ result: EffectResult,
        t: (String, [String: String]) -> String
    ) -> String? {
        let body: String
        switch result.kind {
        case .hidden:
            return nil
        case .noPreviousCycle:
            body = t("effect.noPrevious", [:])
        case .notEnoughDays:
            body = t("effect.notEnough", [:])
        case .similar:
            body = t("effect.similar", [:])
        case .changed(let shifts):
            let clauses = shifts.map { shift in
                let name = t("symptom.id.\(shift.id)", [:])
                let key = shift.direction == .improved ? "effect.clause.down" : "effect.clause.worse"
                return t(key, ["name": name])
            }
            var sentence = clauses.joined(separator: t("effect.join", [:]))
            if shifts.last?.direction == .worse {
                sentence += t("effect.thanLast", [:])
            }
            body = sentence
        }
        if let ctx = result.context {
            let key = ctx.field == .dose ? "effect.sinceDose" : "effect.sinceSchedule"
            return t(key, ["name": ctx.nameSnapshot]) + body
        }
        return body
    }
}
