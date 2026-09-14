enum TrendsStrings {
    static let table: [AppLanguage: [String: String]] = [
        .en: en,
        .de: de,
    ]

    static let en: [String: String] = [
        "trends.needCyclesTitle": "Need more cycles",
        "trends.needCycles": "Trends needs at least two logged cycles. Log a period on Cycle, then come back.",
        "trends.noScoresTitle": "No scores yet",
        "trends.noScores": "No symptom scores in these cycles yet.",
        "trends.axis": "Days scored",
        "trends.sizeKey": "Bigger dot = stronger on those days.",
        "trends.change": "Choose Symptoms",
        "trends.sheet": "Show on chart",
        "trends.detail": "{{name}} · {{start}} – {{end}} · {{count}} days · average {{mean}}",
        "trends.tick.dose": "Dose change on {{date}}: {{name}}, {{value}}. Context only, not a cause.",
        "trends.tick.schedule": "Schedule change on {{date}}: {{name}}, {{value}}. Context only, not a cause.",
    ]

    static let de: [String: String] = [
        "trends.needCyclesTitle": "Mehr Zyklen nötig",
        "trends.needCycles": "Verlauf braucht mindestens zwei erfasste Zyklen. Trag eine Periode unter Zyklus ein, dann komm zurück.",
        "trends.noScoresTitle": "Noch keine Werte",
        "trends.noScores": "Noch keine Symptomwerte in diesen Zyklen.",
        "trends.axis": "Erfasste Tage",
        "trends.sizeKey": "Größerer Punkt = stärker an diesen Tagen.",
        "trends.change": "Symptome wählen",
        "trends.sheet": "Im Diagramm zeigen",
        "trends.detail": "{{name}} · {{start}} – {{end}} · {{count}} Tage · Mittel {{mean}}",
        "trends.tick.dose": "Dosiswechsel am {{date}}: {{name}}, {{value}}. Nur Kontext, keine Ursache.",
        "trends.tick.schedule": "Schemawechsel am {{date}}: {{name}}, {{value}}. Nur Kontext, keine Ursache.",
    ]
}
