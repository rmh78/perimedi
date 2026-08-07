## ADDED Requirements

### Requirement: Compact day columns with horizontal scroll
The system SHALL size day columns in the medication bands and cycle day strip so a narrow phone can show several days without forcing the full cycle into the viewport; when the plot is wider than the available area, the system SHALL allow horizontal scrolling of med tracks and cycle strip together.

#### Scenario: Narrow phone with full cycle length
- **WHEN** the visible cycle window has many days and the plot is narrower than (day count × day column minimum)
- **THEN** the user can scroll horizontally to reach every day column rather than compressing columns to zero width

### Requirement: Sticky medication lane labels while scrolling
While the cycle plot scrolls horizontally, the system SHALL keep each medication’s lane label (name / taken control) visible in a fixed leading column.

#### Scenario: Scroll mid-cycle
- **WHEN** the user scrolls the cycle plot horizontally
- **THEN** medication labels remain visible on the leading edge of the chart

### Requirement: Selection overlay stays aligned while scrolling
The system SHALL keep the selected-day highlight aligned with the selected day’s column in the scrolled plot.

#### Scenario: Select then scroll
- **WHEN** the user selects a day and then scrolls the plot
- **THEN** the selection indicator remains on that day’s column relative to the plot content

### Requirement: Header day paging and selected-day context
The system SHALL show the selected cycle day and calendar date in the Cycle card header with previous/next controls to page through days in the current cycle window, and SHALL show period/symptom status and day actions (add medication, cycle settings, add symptom) in that header region—not as a separate floating badge over the plot.

#### Scenario: Page to next day
- **WHEN** the user activates next day and a later day with a date exists in the cycle window
- **THEN** that day becomes selected and the plot scrolls so the day column is reachable

#### Scenario: No floating day chip on the plot
- **WHEN** a day is selected
- **THEN** the selected day text is not shown as a separate floating chip over the selection column (header carries the day text)

### Requirement: Today scrolls the selected day into view
When the user activates **Today** on the Cycle screen, the system SHALL select today’s date and SHALL horizontally scroll the cycle plot so today’s day column is visible when the plot overflows.

#### Scenario: Today while scrolled away
- **WHEN** the cycle plot is scrolled so today is off-screen and the user activates Today
- **THEN** today’s date becomes selected and the plot scrolls so today’s day-cell is visible

### Requirement: Compact cycle-days strip
The system SHALL keep the cycle-days strip shorter in height than a full med lane so more of the chart fits on a small viewport while still showing day numbers and period/symptom marks.

#### Scenario: Cycle strip density
- **WHEN** the user views the cycle chart on a narrow phone
- **THEN** the cycle-days row is visually shorter than a medication band row
