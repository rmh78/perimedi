## ADDED Requirements

### Requirement: Backup and sample UI follows active language
The system SHALL present backup, sample-load, import, export, and clear-data UI chrome (titles, button labels, confirmations, status messages) in the active language.

#### Scenario: More backup section in German
- **WHEN** the active language is German and the user opens the More backup area
- **THEN** export, import, sample, and clear controls are labeled in German

### Requirement: Backup payload is language-independent
The system SHALL export and import user data without translating stored field values; language preference MAY be stored separately from clinical domain data and MUST NOT rewrite user text on import.

#### Scenario: Import keeps user text
- **WHEN** the user imports a backup containing medication names and notes
- **THEN** those strings are restored exactly as stored in the backup

### Requirement: Sample dataset content is fixed demo data
The system SHALL load sample domain data (medications, periods, logs, remarks) as a fixed demo set; sample chrome and confirmations follow the active language, but sample entity text need not be dual-authored for every language.

#### Scenario: Load sample under German UI
- **WHEN** the active language is German and the user confirms loading sample data
- **THEN** local data is replaced with the sample set and the confirmation/success chrome is in German
