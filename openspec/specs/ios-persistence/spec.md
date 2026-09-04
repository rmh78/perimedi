# ios-persistence Specification

## Purpose

Keep the current user’s PeriMedi data on the iOS device and restore it for the same Apple ID after a device switch, without a PeriMedi server or extra product account.

## Requirements

### Requirement: On-device store for domain data
The system SHALL persist medications, schedules, dose logs, remarks, symptom scores, periods, and cycle settings in on-device iOS storage so the data is still present after the user force-quits the app or reboots the Simulator or device.

#### Scenario: Restart keeps data
- **WHEN** the user adds a medication and a period, then force-quits and relaunches the app on the same Simulator
- **THEN** that medication and period are still present

### Requirement: No PeriMedi account
The system SHALL NOT require a PeriMedi username, password, or API key to store or read the current user’s data.

#### Scenario: Use without product login
- **WHEN** the user launches the app with no PeriMedi account configured
- **THEN** they can create and later retrieve local tracking data

### Requirement: Restore on device switch for the same Apple ID
When iCloud is enabled for the app and the user is signed into the same Apple ID, the system SHALL make the current user’s domain data available on a second iOS destination signed into that Apple ID, without a custom backend.

#### Scenario: Second destination with same Apple ID
- **WHEN** the user has saved tracking data on one iOS destination with iCloud enabled and later opens the app on a second destination signed into the same Apple ID with iCloud enabled for the app
- **THEN** the previously saved medications, schedules, dose logs, remarks, symptom scores, periods, and cycle settings become available on the second destination

#### Scenario: Second destination already running
- **WHEN** the user has saved tracking data on one iOS destination with iCloud enabled and a second destination signed into the same Apple ID is already running or returns to the foreground, with iCloud enabled for the app
- **THEN** those medications, schedules, dose logs, remarks, symptom scores, periods, and cycle settings become available on the second destination without a local write on that destination

#### Scenario: Simulator without iCloud sign-in
- **WHEN** the Simulator is not signed into iCloud
- **THEN** on-device persistence still works and the app remains usable; device-switch restore is not required until iCloud is available

### Requirement: Import a version-1 JSON backup
The system SHALL accept a valid PeriMedi version-1 JSON backup and replace local domain data with that payload.

#### Scenario: Import version-1 backup
- **WHEN** the user imports a valid version-1 backup
- **THEN** medications, schedules, dose logs, remarks, symptom scores (when present), periods, and cycle settings match the backup

#### Scenario: Reject invalid file
- **WHEN** the user selects a file that is not a valid PeriMedi backup
- **THEN** existing local data is left unchanged and the user is told the import failed

### Requirement: Failed local save leaves stored data unchanged
The system SHALL leave already-persisted domain data unchanged when a local write cannot be stored, SHALL NOT show tracking data that was not saved, and SHALL tell the user that the save failed.

#### Scenario: Local save failure
- **WHEN** a local write cannot be stored
- **THEN** Cycle and Month still show the last successfully stored data and the user is told the save failed

### Requirement: Offline after first launch
The system SHALL allow core tracking (viewing and updating already-local data) without a network connection after the app has launched at least once with a local store.

#### Scenario: Airplane mode
- **WHEN** the device or Simulator has no network and the user already has local data
- **THEN** they can view that data and log a dose or note that is stored locally

### Requirement: Uninstall without backup loses only local copy
The system SHALL treat uninstall of the app as removal of the on-device copy. Data remains recoverable only from iCloud (when enabled) or from a previously exported backup.

#### Scenario: Delete app with no iCloud and no export
- **WHEN** the user deletes the app and has never enabled iCloud for the app and has no export
- **THEN** previously stored on-device data is gone on next install
