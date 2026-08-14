# backup-and-sample Specification

## Purpose

Let the user back up and restore local data, load a realistic sample dataset, or clear local data without a server.

## Requirements

### Requirement: Export and import local data
The system SHALL allow the user to export all app data as a JSON file and import a previously exported backup into the on-device store. Export SHALL produce a shareable or savable file (not only a browser download). Import SHALL accept a valid backup produced by this iOS app or by the web companion.

#### Scenario: Export
- **WHEN** the user exports data
- **THEN** a JSON backup file is produced containing medications, schedules, dose logs, remarks, periods, and cycle settings and the user can save or share that file

#### Scenario: Import
- **WHEN** the user imports a valid backup file
- **THEN** local data is replaced with the imported payload

#### Scenario: Import web companion backup
- **WHEN** the user imports a valid version-1 JSON backup exported from the web companion
- **THEN** local iOS data is replaced with that payload

### Requirement: Sample data
The system SHALL provide a loadable sample dataset that demonstrates a perimenopause-oriented medication set, non-overlapping periods with ~26–29 day cycles between starts, and sample dose logs and symptoms.

#### Scenario: Load sample
- **WHEN** the user confirms loading sample data
- **THEN** local data is replaced with the sample set and cycle settings reflect the sample averages

### Requirement: Clear data
The system SHALL allow the user to clear local app data and restore default cycle settings.

#### Scenario: Clear all
- **WHEN** the user confirms clear data
- **THEN** medications, schedules, dose logs, remarks, and periods are removed and default cycle settings are restored

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
