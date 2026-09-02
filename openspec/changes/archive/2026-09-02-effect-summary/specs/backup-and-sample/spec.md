## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Change events round-trip in backup
New exports SHALL include the dose/schedule change-event list. Import SHALL restore those events when present. The system SHALL NOT invent change events that were not in the backup or recorded from a medication save.

#### Scenario: Export after two dose changes
- **WHEN** the user changes a medication’s dose, changes it back, and exports
- **THEN** the JSON includes both change events
