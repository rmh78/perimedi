## MODIFIED Requirements

### Requirement: Client-only data storage
The system SHALL store application domain data on the user’s device and SHALL NOT require a PeriMedi backend account, API, or server-side database. The system MAY use the user’s Apple iCloud account to sync that on-device data across the user’s devices. The system SHALL NOT send tracking data to any non-Apple service operated by PeriMedi.

#### Scenario: Offline use
- **WHEN** the user uses the app after initial load with data already local
- **THEN** core tracking features work without a PeriMedi network account or API key

#### Scenario: No PeriMedi server
- **WHEN** the user saves a medication, dose, period, or note
- **THEN** that record is stored on the device (and, when iCloud is enabled, through Apple iCloud) and is not submitted to a PeriMedi backend

### Requirement: No required environment configuration
The system SHALL run and build without required environment variables or secrets checked into the project or supplied by the developer for normal Simulator use.

#### Scenario: Local development
- **WHEN** a developer opens the iOS project and runs it on the Simulator with no `.env` file
- **THEN** the application starts successfully

#### Scenario: Web reference app
- **WHEN** a developer runs install and dev for the web companion with no `.env` file
- **THEN** the web application starts successfully

## REMOVED Requirements

### Requirement: Data loss on site data clear
**Reason**: The iOS product does not use browser origin storage. Clearing Safari site data is not a meaningful data-loss path. Uninstall, explicit clear-data, and iCloud/export restore are specified under backup-and-sample and ios-persistence.
**Migration**: Users back up with JSON export or rely on iCloud when enabled. Developers no longer document “clear site data” as the iOS wipe path.
