# schedules Specification

## Purpose

Define when a medication should be taken using exclusive scheduling modes and one or more clock times, without per-schedule dose override in the UI.

## Requirements

### Requirement: Exclusive schedule modes
The system SHALL support exactly one schedule mode at a time for the primary schedule: every day, specific weekdays, or cyclic (apply N / pause M days or week slots). Weekday selection and cyclic mode SHALL NOT be active together.

#### Scenario: Every day
- **WHEN** the user selects every day and saves
- **THEN** the schedule applies on all calendar days (no weekday filter) and is not cyclic

#### Scenario: Specific days
- **WHEN** the user selects specific weekdays and saves
- **THEN** the schedule applies only on those weekdays and is not cyclic

#### Scenario: Cyclic
- **WHEN** the user selects cyclic mode with apply and pause settings and saves
- **THEN** the schedule uses the cyclic plan and does not use a weekday filter

### Requirement: Take times
The system SHALL allow the user to set one or more clock times for doses and SHALL use the medication’s default dose label for planned doses (no per-schedule dose override field in the medication dialog).

#### Scenario: Single time
- **WHEN** the user sets one take time and saves
- **THEN** planned doses use that time with the medication default dose

#### Scenario: Multiple times
- **WHEN** the user adds multiple take times and saves
- **THEN** each time produces a planned dose slot for applicable days

### Requirement: Schedule duration
The system SHALL allow optional schedule start and end dates so dosing can be bounded in time.

#### Scenario: Open-ended schedule
- **WHEN** the user sets a start date and leaves end empty
- **THEN** the schedule remains active from the start date onward until deactivated or ended
