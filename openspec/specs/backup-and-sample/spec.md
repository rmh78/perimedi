# backup-and-sample Specification

## Purpose

Let the user back up and restore local data, load a realistic sample dataset, or clear local data without a server.

## Requirements

### Requirement: Export and import local data
The system SHALL allow the user to export all app data as a JSON file and import a previously exported backup into the on-device store. Export SHALL produce a shareable or savable file. Import SHALL accept a valid version-1 PeriMedi JSON backup.

#### Scenario: Export
- **WHEN** the user exports data
- **THEN** a JSON backup file is produced containing medications, schedules, dose logs, remarks, symptom scores, periods, cycle settings, and dose/schedule change events and the user can save or share that file

#### Scenario: Import
- **WHEN** the user imports a valid backup file
- **THEN** local data is replaced with the imported payload

#### Scenario: Import version-1 backup
- **WHEN** the user imports a valid version-1 JSON backup
- **THEN** local data is replaced with that payload

#### Scenario: Import older backup without change events
- **WHEN** the user imports a valid version-1 backup that has no change-event list
- **THEN** medications, periods, scores, and other payload fields restore and change events are empty

### Requirement: Change events round-trip in backup
New exports SHALL include the dose/schedule change-event list. Import SHALL restore those events when present. The system SHALL NOT invent change events that were not in the backup or recorded from a medication save.

#### Scenario: Export after two dose changes
- **WHEN** the user changes a medication’s dose, changes it back, and exports
- **THEN** the JSON includes both change events

### Requirement: Sample data
The system SHALL provide a loadable sample dataset for a typical woman about 40 (35–45) in perimenopause: transdermal estradiol, cyclic micronized progesterone, local vaginal estradiol, common supplements, non-overlapping irregular periods (mixed short and long gaps, mixed flow), recent dose logs, and structured symptom scores. Sample dates SHALL be anchored on the app’s current today so Cycle shows the sample immediately. Loading sample SHALL move the selected day to today.

#### Scenario: Load sample
- **WHEN** the user confirms loading sample data
- **THEN** local data is replaced with the sample set, cycle settings reflect the sample averages, the selected day is today, and Cycle shows the sample medications and the current cycle window

#### Scenario: Sample and clear use a confirm card
- **WHEN** the user activates load sample or clear data
- **THEN** an inset cream confirm card appears over a light blur of the app (not a system action sheet), with Cancel and a confirm action

### Requirement: Clear data
The system SHALL allow the user to clear local app data and restore default cycle settings.

#### Scenario: Clear all
- **WHEN** the user confirms clear data
- **THEN** medications, schedules, dose logs, remarks, symptom scores, and periods are removed and default cycle settings are restored

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
The system SHALL load sample domain data (medications, periods, logs, remarks, symptom scores) as a fixed demo set; sample chrome and confirmations follow the active language, but sample entity text need not be dual-authored for every language.

#### Scenario: Load sample under German UI
- **WHEN** the active language is German and the user confirms loading sample data
- **THEN** local data is replaced with the sample set and the confirmation/success chrome is in German
