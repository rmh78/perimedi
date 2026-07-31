# month-calendar Specification

## Purpose

Provide a month grid that shows cycle context, period and symptoms, and dose status so the user can navigate and select days across the month.

## Requirements

### Requirement: Month navigation and selection
The system SHALL display a month grid for a navigable month and SHALL update the shared selected date when the user activates a day cell.

#### Scenario: Select day
- **WHEN** the user activates a day in the month grid
- **THEN** that date becomes the selected date used by the cycle chart and day context

#### Scenario: Navigate months
- **WHEN** the user moves to the previous or next month
- **THEN** the grid shows days for that month

### Requirement: Cycle boundary markers
The system SHALL mark cycle start and end days on the month grid using quiet edge indicators (not heavy labels), based on period starts and predicted period starts without placing a cycle start mid-bleed of another period.

#### Scenario: Cycle start day
- **WHEN** a day is a cycle start (first period day of a cycle)
- **THEN** the cell shows a cycle-start edge mark

#### Scenario: Cycle end day
- **WHEN** a day is a cycle end (day before next cycle start, or natural cycle length end when no next start)
- **THEN** the cell shows a cycle-end edge mark

### Requirement: Cycle day badges
The system SHALL show a cycle-day badge (for example D12) on days where a cycle day can be derived.

#### Scenario: Badge present
- **WHEN** a day has a known cycle day number
- **THEN** the cell displays a compact cycle-day badge with that number

### Requirement: Period, symptom, and dose markers
The system SHALL show period with blood-drop icons (solid logged, lighter predicted), symptom indicators, and dose status dots on applicable days.

#### Scenario: Period drop
- **WHEN** a day is a logged or predicted period day
- **THEN** a blood-drop icon appears instead of a Period text chip

#### Scenario: Dose dots
- **WHEN** a day has planned doses
- **THEN** status dots indicate taken versus not taken for those doses
