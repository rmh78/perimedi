# cycle-diagram Specification

## Purpose

Show medications across cycle days with period and symptom marks, and keep a shared selected day aligned across the chart for planning and logging.

## Requirements

### Requirement: Medication lanes and dose segments
The system SHALL show one lane per medication with dose segments across the visible cycle days when planned doses exist for that window.

#### Scenario: Meds with schedules in window
- **WHEN** medications have planned doses in the current cycle window
- **THEN** each such medication appears as a lane with dose segments on applicable days

#### Scenario: Empty med list
- **WHEN** no medications have planned doses in the window
- **THEN** an empty state invites the user to add a medication

### Requirement: Shared day selection
The system SHALL maintain a selected date that can be changed from the cycle day strip or medication band day columns and SHALL highlight the selected day with a semi-transparent column overlay spanning the chart plot.

#### Scenario: Select from cycle strip
- **WHEN** the user activates a day on the cycle day strip
- **THEN** that date becomes the selected date and the overlay moves to that column

#### Scenario: Select from med band
- **WHEN** the user activates a day column on a medication lane
- **THEN** that date becomes the selected date

### Requirement: Cycle window follows selected date
The system SHALL anchor the visible cycle window to the period that defines cycle day for the selected date, not only the latest period start, and SHALL extend the window when needed so the selected day remains visible (within a reasonable upper bound).

#### Scenario: Calendar pick in prior cycle
- **WHEN** the user selects a date that falls under an earlier period start than the latest period
- **THEN** the cycle chart shows the window for that earlier period and selects the corresponding cycle day

### Requirement: Period and symptom marks on cycle strip
The system SHALL show blood-drop icons for period days on one row of the cycle strip (solid for logged period, lighter for predicted) and symptom marks on a separate row below.

#### Scenario: Logged period day
- **WHEN** a cycle day is a logged period day
- **THEN** a solid blood-drop icon appears on the period row for that day

#### Scenario: Predicted period day
- **WHEN** a cycle day is predicted period only
- **THEN** a lighter blood-drop icon appears on the period row for that day

#### Scenario: Symptoms
- **WHEN** a cycle day has logged symptoms
- **THEN** symptom marks appear on the symptom row for that day
