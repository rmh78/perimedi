# symptoms Specification

## Purpose

Allow the user to log symptoms and notes for a date and surface them on the cycle strip, day context, and month calendar.

## Requirements

### Requirement: Log symptom for a date
The system SHALL allow the user to log a symptom or note for a chosen date via a sheet using a text body. The sheet SHALL NOT ask the user to pick a symptom kind.

#### Scenario: Add symptom from day card
- **WHEN** the user activates + Symptom for the selected date and saves a note
- **THEN** the symptom is stored for that date and appears in day context and cycle/calendar markers

### Requirement: Display symptoms in context
The system SHALL show logged symptoms on the cycle day strip symptom row, in the selected-day summary, and as indicators on the month calendar.

#### Scenario: Selected day has symptoms
- **WHEN** the selected date has one or more symptoms
- **THEN** the Cycle header lists those symptoms as gold chips with a lightning mark and without a delete control

#### Scenario: Open sheet from a symptom chip
- **WHEN** the user activates a selected-day symptom chip
- **THEN** the symptom sheet opens for that date

#### Scenario: No symptoms
- **WHEN** the selected date has no symptoms
- **THEN** the day card indicates that no symptoms are logged

### Requirement: Delete symptom for a date
The system SHALL allow the user to delete a logged symptom for a date from the symptom sheet. The selected-day summary SHALL NOT delete a symptom.

#### Scenario: Delete from symptom sheet
- **WHEN** the user opens the symptom sheet for a date that has logged symptoms and deletes one
- **THEN** that symptom is removed and no longer appears in day context or cycle/calendar markers

#### Scenario: Logged list matches period history chrome
- **WHEN** the user opens the symptom sheet for a date with logged symptoms
- **THEN** add fields appear first, the logged list is at the bottom, and each symptom is a compact row with the text body and the same circular edit and delete icons as period history

### Requirement: Edit symptom for a date
The system SHALL allow the user to change the body of a logged symptom for a date from the symptom sheet.

#### Scenario: Save edited symptom
- **WHEN** the user edits a logged symptom and saves
- **THEN** the updated body appears in day context and the sheet list
