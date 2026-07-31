# symptoms Specification

## Purpose

Allow the user to log symptoms and notes for a date and surface them on the cycle strip, day context, and month calendar.

## Requirements

### Requirement: Log symptom for a date
The system SHALL allow the user to log a symptom or note for a chosen date via a sheet, including a kind such as cycle, side effect, note, or other, and a text body.

#### Scenario: Add symptom from day card
- **WHEN** the user activates + Symptom for the selected date and saves a note
- **THEN** the symptom is stored for that date and appears in day context and cycle/calendar markers

### Requirement: Display symptoms in context
The system SHALL show logged symptoms on the cycle day strip symptom row, in the selected-day summary, and as indicators on the month calendar.

#### Scenario: Selected day has symptoms
- **WHEN** the selected date has one or more symptoms
- **THEN** the day card lists those symptoms with kind and body

#### Scenario: No symptoms
- **WHEN** the selected date has no symptoms
- **THEN** the day card indicates that no symptoms are logged
