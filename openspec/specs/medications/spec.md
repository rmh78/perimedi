# medications Specification

## Purpose

Let the user define medications with form, default dose, and color so they can be scheduled, shown on the cycle chart, and distinguished visually.

## Requirements

### Requirement: Unified medication dialog
The system SHALL allow the user to add and edit a medication including form, default dose, color, and primary schedule in a single dialog without requiring a separate primary-schedule-only flow.

#### Scenario: Add medication with schedule
- **WHEN** the user saves a new medication with a valid name, default dose, and at least one take time
- **THEN** the medication and its primary schedule are persisted and the dialog closes

#### Scenario: Edit existing medication
- **WHEN** the user opens an existing medication and saves changes
- **THEN** the medication fields and primary schedule are updated

### Requirement: Medication forms and icons
The system SHALL support medication forms pill, cream, drops, injection, and other, each with an icon that fills the medication avatar circle.

#### Scenario: Form selection
- **WHEN** the user selects a form type for a medication
- **THEN** the avatar icon matches that form and fills the circle

### Requirement: Medication color
The system SHALL allow the user to choose a color from a single-row palette (including light pink and rose tones) and SHALL apply that color to the medication icon ring, dose bands, and taken-day fills.

#### Scenario: Color choice
- **WHEN** the user selects a palette color and saves the medication
- **THEN** the cycle chart uses that color for the med’s icon ring, dose bands, and taken marks

#### Scenario: Default color by form
- **WHEN** a medication has no custom color stored
- **THEN** a form-based default color is used for display
