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
- **THEN** the cell shows a cycle-start edge mark along the top and leading edges

#### Scenario: Cycle end day
- **WHEN** a day is a cycle end (day before next cycle start, or natural cycle length end when no next start)
- **THEN** the cell shows a cycle-end edge mark along the bottom and trailing edges

### Requirement: Cycle day badges
The system SHALL show a cycle-day badge (for example D12) on days where a cycle day can be derived.

#### Scenario: Badge present
- **WHEN** a day has a known cycle day number
- **THEN** the cell displays a compact cycle-day badge with that number

### Requirement: Period, symptom, and dose markers
The system SHALL show period with blood-drop icons (solid logged, lighter predicted), symptom indicators with compact score values when logged, and dose status dots on applicable days.

#### Scenario: Period drop
- **WHEN** a day is a logged or predicted period day
- **THEN** a blood-drop icon appears instead of a Period text chip

#### Scenario: Dose dots
- **WHEN** a day has planned doses
- **THEN** status dots indicate taken versus not taken for those doses

### Requirement: Touch-friendly month day cells
The system SHALL size month-grid day cells so they remain easy to tap on a narrow phone while preserving a seven-column week grid.

#### Scenario: Select day on narrow phone
- **WHEN** the user taps a day in the month grid on a narrow phone viewport
- **THEN** the intended day becomes selected without requiring a precision pointer

### Requirement: Month grid stays within page width
The system SHALL lay out the month grid within the content width so the calendar does not force page-level horizontal scrolling.

#### Scenario: Month on phone
- **WHEN** the user views the month section on a phone
- **THEN** all seven weekday columns are visible within the content width without panning the page

### Requirement: Period marks fully visible in cells
The system SHALL render period blood-drop marks fully inside their day cell (not clipped by the cell’s right or top edge or by a neighboring cell).

#### Scenario: Period day on the right of a row
- **WHEN** a day with a period mark is shown in the month grid
- **THEN** the full blood-drop glyph is visible within that cell

### Requirement: Month chrome without redundant title
The system SHALL identify the visible month on one header row in this order: Today, previous, next, then the month/year label, without a separate page title that only repeats the nav label “Month”. The header row SHALL be separated from the calendar body by a divider matching the Cycle screen.

#### Scenario: Month card header
- **WHEN** the user opens Month
- **THEN** the header row shows Today, previous/next paging, and the calendar month and year, with a divider below it

### Requirement: Cycle tab keeps the selected month day
The system SHALL NOT present a dedicated control on Month whose only purpose is to open Cycle. The shared selected date SHALL remain in effect when the user switches to Cycle via the bottom navigation.

#### Scenario: Open Cycle from Month via nav
- **WHEN** the user selects a day on Month and then activates Cycle in the bottom navigation
- **THEN** the Cycle screen is shown with that date still selected
