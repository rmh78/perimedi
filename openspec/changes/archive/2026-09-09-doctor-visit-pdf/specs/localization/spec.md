## ADDED Requirements

### Requirement: Visit PDF follows the active language
The system SHALL present the More visit action and the generated PDF chrome in English or German according to the active language, and SHALL keep user-entered text untranslated.

#### Scenario: German visit action
- **WHEN** the active language is German and the user opens More
- **THEN** the visit PDF action label is in German

#### Scenario: English visit PDF
- **WHEN** the active language is English and the user generates a visit PDF
- **THEN** PDF headings and the disclaimer are in English
