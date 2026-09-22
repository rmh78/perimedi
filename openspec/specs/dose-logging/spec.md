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

### Requirement: Home Screen widget shows today's untaken medications
The system SHALL show only medications that still have a pending planned slot on the device's current calendar day. The system SHALL NOT show another day's medications as the visible list. When more medications remain than the widget can list as rows, the system SHALL keep the PeriMedi title visible and SHALL mark the overflow with a remaining count. The widget SHALL NOT grow to fit extra rows.

#### Scenario: Today only
- **WHEN** a medication is pending tomorrow and nothing is pending today
- **THEN** the Home Screen widget shows today's empty chrome, not tomorrow's medication

#### Scenario: Remaining count
- **WHEN** more medications still have a pending planned slot today than the widget lists as rows
- **THEN** the PeriMedi title stays visible and a remaining count marks the medications that are not listed as rows

#### Scenario: Medication icon and Taken control
- **WHEN** a medication is listed on the Home Screen widget
- **THEN** that row shows the medication's form icon inside a circle of the medication color, and Taken is a white label on a control filled with that same medication color

### Requirement: Taken from the Home Screen widget
The system SHALL allow the user to record a medication as taken from a Home Screen widget using the same grain as Cycle for today: every remaining pending planned slot for that medication on the current calendar day, each written through the same dose-log path as Cycle. The system SHALL NOT mark other medications taken. The system SHALL NOT mark slots on another day. A second activation after those slots are taken SHALL leave them taken. Un-take SHALL NOT be available on the widget; un-taking on Cycle for today SHALL make that medication eligible for the widget again.

#### Scenario: Taken from the Home Screen widget
- **WHEN** a medication with pending planned slots today is shown on the Home Screen widget and the user chooses Taken
- **THEN** every remaining pending planned slot for that medication on today is recorded as taken the same way as activating that medication's Cycle lane for today, and Cycle and Month reflect expansion

#### Scenario: Widget Taken is Cycle grain for today
- **WHEN** a medication has two planned times still pending today and the user chooses Taken on the widget for that medication
- **THEN** both times are taken; other medications' slots stay pending

#### Scenario: Widget Taken is idempotent
- **WHEN** the user chooses Taken on the widget for a medication whose planned slots today are already taken
- **THEN** those slots stay taken and no second log is created

#### Scenario: Un-take on Cycle returns the medication
- **WHEN** the user marks a medication taken from the widget and later un-takes it on Cycle for today
- **THEN** that medication is eligible for the widget's visible list again

### Requirement: Taken visual uses medication color
The system SHALL reflect taken status on the cycle chart using the medication’s color for taken-day fills and taken indicator styling.

#### Scenario: Taken day fill
- **WHEN** a planned dose day is marked taken for a medication
- **THEN** the corresponding day cell on that med’s lane uses a tint derived from the medication color, inset slightly from the lane edges
