# backup-and-sample Specification

## Purpose

Let the user back up and restore local data, load a realistic sample dataset, or clear local data without a server.

## Requirements

### Requirement: Export and import local data
The system SHALL allow the user to export all app data as JSON and import a previously exported backup into local storage.

#### Scenario: Export
- **WHEN** the user exports data
- **THEN** a JSON backup download is produced containing medications, schedules, dose logs, remarks, periods, and cycle settings

#### Scenario: Import
- **WHEN** the user imports a valid backup file
- **THEN** local data is replaced with the imported payload

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
