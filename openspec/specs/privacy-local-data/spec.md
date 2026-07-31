# privacy-local-data Specification

## Purpose

Keep all personal tracking data on the user’s device without requiring accounts, servers, or environment secrets.

## Requirements

### Requirement: Client-only data storage
The system SHALL store application data only in the browser (IndexedDB) on the user’s device and SHALL NOT require a backend account or server-side store for app data.

#### Scenario: Offline use
- **WHEN** the user uses the app after initial load with data already local
- **THEN** core tracking features work without a network account or API key

### Requirement: No required environment configuration
The system SHALL run and build as a static app without required environment variables or secrets.

#### Scenario: Local development
- **WHEN** a developer runs install and dev with no .env file
- **THEN** the application starts successfully

### Requirement: Data loss on site data clear
The system SHALL rely on browser storage such that clearing site data can delete the local database, with export as the supported backup path.

#### Scenario: User clears site data
- **WHEN** the user clears site data for the app origin in the browser
- **THEN** previously stored local app data is no longer available unless restored from export
