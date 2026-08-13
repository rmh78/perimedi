# day-context Specification

## Purpose

Summarize the selected day (period and symptoms) on the Cycle screen and expose primary actions for adding a medication, opening cycle settings, and logging a symptom.

## Requirements

### Requirement: Selected day summary
The system SHALL show the selected cycle day number, calendar date, period status (logged, predicted, or none), and symptom summary on the Cycle screen header.

#### Scenario: Selected day with period
- **WHEN** the selected day is a logged period day
- **THEN** the Cycle header indicates period for that day

#### Scenario: Selected day without period
- **WHEN** the selected day is not period or predicted period
- **THEN** the Cycle header indicates no period

### Requirement: Day primary actions
The system SHALL provide add-medication, cycle-settings, and add-symptom actions on the Cycle header when the corresponding capabilities are available.

#### Scenario: Action row
- **WHEN** the user views the Cycle header for a selected day
- **THEN** add medication, cycle settings, and add symptom are available

#### Scenario: Add med from header
- **WHEN** the user activates add medication
- **THEN** the add medication dialog opens

#### Scenario: Add symptom from header
- **WHEN** the user activates add symptom for a selected date
- **THEN** the symptom sheet opens for that date
