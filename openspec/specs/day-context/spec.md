# day-context Specification

## Purpose

Summarize the selected day (period and symptoms) and expose primary Home actions for adding a medication, opening cycle settings, and logging a symptom.

## Requirements

### Requirement: Selected day summary card
The system SHALL show a card for the selected day with the cycle day number, calendar date, period status (logged, predicted, or none), and symptom summary.

#### Scenario: Selected day with period
- **WHEN** the selected day is a logged period day
- **THEN** the card indicates period for that day

#### Scenario: Selected day without period
- **WHEN** the selected day is not period or predicted period
- **THEN** the card indicates no period

### Requirement: Day card primary actions
The system SHALL provide + Med, Cycle settings, and + Symptom actions on the selected-day card when the corresponding capabilities are available.

#### Scenario: Action row
- **WHEN** the user views the selected-day card
- **THEN** + Med, Cycle settings, and + Symptom are available as actions on that card

#### Scenario: Add med from card
- **WHEN** the user activates + Med
- **THEN** the add medication dialog opens

#### Scenario: Add symptom from card
- **WHEN** the user activates + Symptom for a selected date
- **THEN** the symptom sheet opens for that date
