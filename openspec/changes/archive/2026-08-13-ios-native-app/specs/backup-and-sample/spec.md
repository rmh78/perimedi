## MODIFIED Requirements

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
