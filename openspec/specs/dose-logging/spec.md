# dose-logging Specification

## Purpose

Allow the user to record whether planned doses for the selected day were taken, using a simple toggle on each medication in the cycle view.

## Requirements

### Requirement: Toggle dose status via med icon
The system SHALL allow the user to toggle planned doses for the selected day between taken and not taken by activating the medication icon for that lane.

#### Scenario: Mark taken
- **WHEN** the selected day has one or more planned doses for a medication and the user activates that medication’s icon while status is not taken
- **THEN** all planned doses for that medication on the selected day are recorded as taken

#### Scenario: Taken from a dose reminder
- **WHEN** a dose reminder fires for one planned slot and the user chooses Taken on that reminder
- **THEN** that slot is recorded as taken the same way as logging it on Cycle

#### Scenario: Mark not taken
- **WHEN** the selected day has planned doses for a medication recorded as taken and the user activates that medication’s icon
- **THEN** those doses are recorded as not taken (pending)

#### Scenario: No planned dose
- **WHEN** the selected day has no planned doses for a medication
- **THEN** activating the medication icon does not create a taken state for that day

### Requirement: Taken from the Home Screen widget
The system SHALL allow the user to record the next pending planned slot as taken from a Home Screen widget. That write SHALL use the same one-slot taken path as a dose reminder Taken action. The system SHALL NOT mark other planned slots that day taken. A second activation for a slot that is already taken SHALL leave it taken.

#### Scenario: Taken from the Home Screen widget
- **WHEN** the next pending planned slot is shown on the Home Screen widget and the user chooses Taken
- **THEN** that slot is recorded as taken the same way as logging it from a dose reminder, and Cycle and Month reflect expansion

#### Scenario: Widget Taken is one slot
- **WHEN** a medication has two planned times on the same day and the user chooses Taken on the widget for the earlier time
- **THEN** only that time is taken; the later time stays pending

#### Scenario: Widget Taken is idempotent
- **WHEN** the user chooses Taken on the widget for a slot that is already taken
- **THEN** the slot stays taken and no second log is created

### Requirement: Taken visual uses medication color
The system SHALL reflect taken status on the cycle chart using the medication’s color for taken-day fills and taken indicator styling.

#### Scenario: Taken day fill
- **WHEN** a planned dose day is marked taken for a medication
- **THEN** the corresponding day cell on that med’s lane uses a tint derived from the medication color, inset slightly from the lane edges
