# privacy-local-data Specification

## Purpose

Keep all personal tracking data on the user’s device without requiring accounts, servers, or environment secrets.

## Requirements

### Requirement: Client-only data storage
The system SHALL store application domain data on the user’s device and SHALL NOT require a PeriMedi backend account, API, or server-side database. The system MAY use the user’s Apple iCloud account to sync that on-device data across the user’s devices. The system SHALL NOT send tracking data to any non-Apple service operated by PeriMedi.

#### Scenario: Offline use
- **WHEN** the user uses the app after initial load with data already local
- **THEN** core tracking features work without a PeriMedi network account or API key

#### Scenario: No PeriMedi server
- **WHEN** the user saves a medication, dose, period, or note
- **THEN** that record is stored on the device (and, when iCloud is enabled, through Apple iCloud) and is not submitted to a PeriMedi backend

#### Scenario: Dose reminders stay on device
- **WHEN** a planned take time is due and reminders are on
- **THEN** the reminder is delivered by the device and is not sent through a PeriMedi server

### Requirement: No required environment configuration
The system SHALL run and build without required environment variables or secrets checked into the project or supplied by the developer for normal Simulator use.

#### Scenario: Local development
- **WHEN** a developer opens the iOS project and runs it on the Simulator with no `.env` file
- **THEN** the application starts successfully

### Requirement: In-app privacy policy
The system SHALL provide a Privacy Policy control on More that opens the published privacy policy URL in the system browser. The control and its label SHALL be available in English and German. The privacy policy copy SHALL NOT claim diagnosis, treatment, or HRT titration, and SHALL NOT promise second-device iCloud sync as a guaranteed product feature beyond what the published policy states.

#### Scenario: Open privacy policy from More
- **WHEN** the user activates Privacy Policy on More
- **THEN** the published privacy policy page opens in the system browser

#### Scenario: Localized label
- **WHEN** the active language is German
- **THEN** the Privacy Policy control label is in German
