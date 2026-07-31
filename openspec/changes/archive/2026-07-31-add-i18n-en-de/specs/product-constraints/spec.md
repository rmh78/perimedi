## ADDED Requirements

### Requirement: Localized clear UI copy
The system SHALL provide clear, compact product chrome in each supported language and SHALL keep the not-medical-advice stance in the active language’s copy where such messaging appears.

#### Scenario: German compact actions
- **WHEN** the active language is German
- **THEN** primary actions use short German labels equivalent in role to the English actions (for example add medication, cycle settings, add symptom)

#### Scenario: Demo stance in active language
- **WHEN** the user views product messaging about the demo or medical advice stance
- **THEN** that messaging is shown in the active language and does not claim clinical medical advice
