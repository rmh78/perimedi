## MODIFIED Requirements

### Requirement: Bottom navigation shell
The system SHALL present a bottom navigation band that switches among **Cycle**, **Month**, and **More** primary screens without requiring a modal as the only way to open those destinations.

#### Scenario: Open the app
- **WHEN** the user opens the application
- **THEN** the Cycle screen is shown and the bottom navigation band is available

#### Scenario: Switch to Month
- **WHEN** the user activates Month in the bottom navigation
- **THEN** the month calendar screen is shown

#### Scenario: Switch to More
- **WHEN** the user activates More in the bottom navigation
- **THEN** language, backup, and related tools are shown as a primary screen

### Requirement: No Today primary screen
The system SHALL NOT present a separate Today primary screen in the bottom navigation.

#### Scenario: Navigation destinations
- **WHEN** the user views the bottom navigation band
- **THEN** the destinations are Cycle, Month, and More only

### Requirement: Shared selected date across screens
The system SHALL keep a shared selected calendar date so choosing a day on Cycle or Month remains the selected date when the user switches tabs.

#### Scenario: Month pick then Cycle
- **WHEN** the user selects a date on Month and then opens Cycle
- **THEN** the cycle chart and day-context area reflect that selected date (unless the user explicitly jumps to today)

### Requirement: Jump to today on Cycle
The system SHALL provide a control on the Cycle screen that sets the shared selected date to today and brings today’s column into view when the cycle plot overflows.

#### Scenario: Activate Today on Cycle
- **WHEN** the user activates the Today control on the Cycle screen
- **THEN** the selected date becomes today and the cycle plot scrolls so today’s day-cell is visible when the plot overflows

## ADDED Requirements

### Requirement: Homogeneous primary cards
Primary screens Cycle, Month, and More SHALL present content in a glass-style card without redundant page titles that only repeat the bottom-nav label (e.g. no standalone “Month” or “More” heading whose only role is the tab name).

#### Scenario: Month header
- **WHEN** the user opens Month
- **THEN** the card header shows the calendar month/year and navigation controls, not a separate “Month” title alone

#### Scenario: More header
- **WHEN** the user opens More
- **THEN** the card shows Language and Backup sections without a redundant “More” page title
