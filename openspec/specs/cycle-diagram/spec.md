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
- **THEN** the medications card shows a no-data message and a separate card below introduces PeriMedi and describes the three actions in this order: period settings, add medication, add symptom, and explains that tapping a medication icon marks a dose taken or not taken

### Requirement: Shared day selection
The system SHALL maintain a selected date that can be changed from the cycle day strip or medication band day columns and SHALL highlight the selected day with a semi-transparent column overlay spanning the chart plot. When no period is logged, the visible window SHALL still include days before and after the selected date so previous and next day change the selection.

#### Scenario: Select from cycle strip
- **WHEN** the user activates a day on the cycle day strip
- **THEN** that date becomes the selected date and the overlay moves to that column

#### Scenario: Change day with no logged period
- **WHEN** no period is logged and the user activates previous day or next day
- **THEN** the selected date changes and the highlight moves with it

#### Scenario: Select a future day with no logged period
- **WHEN** no period is logged and the user selects a date after today on the cycle strip
- **THEN** that date remains the selected date and the plot does not snap the highlight back to today

#### Scenario: Select from med band
- **WHEN** the user activates a day column on a medication lane
- **THEN** that date becomes the selected date

### Requirement: Cycle window follows selected date
The system SHALL anchor the visible cycle window to the period that defines cycle day for the selected date when period tracking is on and a period start on or before that date exists, not only the latest period start, and SHALL extend the window when needed so the selected day remains visible (within a reasonable upper bound). When period tracking is off, or no such period start exists, the window SHALL be the calendar month of the selected date, starting on the first of that month.

#### Scenario: Calendar pick in prior cycle
- **WHEN** period tracking is on and the user selects a date that falls under an earlier period start than the latest period
- **THEN** the cycle chart shows the window for that earlier period and selects the corresponding cycle day

#### Scenario: No period tracking
- **WHEN** period tracking is off
- **THEN** the day row starts on the first day of the selected date’s month and spans that month

#### Scenario: Tracking on but no period logged
- **WHEN** period tracking is on and no period start on or before the selected date exists
- **THEN** the day row starts on the first day of the selected date’s month

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

#### Scenario: Symptom mark when the day is not a period day
- **WHEN** a cycle day has a symptom and is not a period day
- **THEN** the symptom mark sits in the top mark row of that column

### Requirement: Compact day columns with horizontal scroll
The system SHALL size day columns in the medication bands and cycle day strip so a narrow phone can show several days without forcing the full cycle into the viewport; when the plot is wider than the available area, the system SHALL allow horizontal scrolling of med tracks and cycle strip together.

#### Scenario: Narrow phone with full cycle length
- **WHEN** the visible cycle window has many days and the plot is narrower than (day count × day column minimum)
- **THEN** the user can scroll horizontally to reach every day column rather than compressing columns to zero width

### Requirement: Day columns rest on full cells
When the cycle plot is at rest, every visible day column SHALL be fully visible. Horizontal scrolling SHALL snap to a day-column boundary so a clipped day cell is not a resting scroll position. Column width SHALL be chosen so an integer number of columns fills the plot viewport.

#### Scenario: Scroll then rest
- **WHEN** the user scrolls the cycle plot horizontally and lifts their finger
- **THEN** the plot settles so the leading edge aligns with a day column and no day cell is clipped by the plot viewport

#### Scenario: Viewport leftover width
- **WHEN** the remaining plot width is not an exact multiple of the minimum day-column width
- **THEN** day columns widen just enough that an integer number of full columns fills the viewport

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
The system SHALL show the selected calendar date in the Cycle card header on one row in this order: Today, previous, next, then the date text. When a logged period defines a cycle day for that date, the header SHALL include that cycle day as well. When no period defines a cycle day, the header SHALL show only the calendar date and SHALL NOT invent a day number from the window index. The header SHALL also show period/symptom status. Day actions (add medication, cycle settings, add symptom) SHALL appear on the medications-and-doses title row, aligned to the trailing edge—not as a separate floating badge over the plot.

#### Scenario: Page to next day
- **WHEN** the user activates next day and a later day with a date exists in the cycle window
- **THEN** that day becomes selected and the plot scrolls so the day column is reachable

#### Scenario: Selected day with a logged period
- **WHEN** a period start on or before the selected date exists
- **THEN** the header names that cycle day and the calendar date

#### Scenario: Selected day with no logged period
- **WHEN** no period is logged
- **THEN** the header shows the calendar date and does not show a cycle-day number

#### Scenario: No floating day chip on the plot
- **WHEN** a day is selected
- **THEN** the selected day text is not shown as a separate floating chip over the selection column (header carries the day text)

### Requirement: Calendar day numbers on the cycle strip
The system SHALL label each cycle-strip column with that date’s calendar day of month. The strip SHALL NOT use cycle day or window index as the visible number. The sticky heading for the strip SHALL name the columns as days, not as cycle days.

#### Scenario: Strip across a month boundary
- **WHEN** the visible window includes the last day of one month and the first day of the next
- **THEN** those columns show the calendar day of month (for example 31 then 1)

#### Scenario: Strip with no logged period
- **WHEN** no period is logged
- **THEN** each column still shows that date’s calendar day of month

### Requirement: Today mark on the cycle strip
The system SHALL mark today’s calendar-day number on the cycle strip the same way the month grid marks today: a filled blush circle with a white day number.

#### Scenario: Today is visible in the strip
- **WHEN** today falls inside the visible cycle window
- **THEN** that date’s calendar day of month appears in a filled blush circle with white type

### Requirement: Today scrolls the selected day into view
When the user activates **Today** on the Cycle screen, the system SHALL select today’s date and SHALL horizontally scroll the cycle plot so today’s day column is visible when the plot overflows. On first open of Cycle with a plot, and again when the app returns from the background, the system SHALL select today and SHALL scroll so today’s column is fully visible without the user activating Today.

#### Scenario: Today while scrolled away
- **WHEN** the cycle plot is scrolled so today is off-screen and the user activates Today
- **THEN** today’s date becomes selected and the plot scrolls so today’s day-cell is visible

#### Scenario: App opens on today
- **WHEN** the user opens Cycle and a cycle plot is shown
- **THEN** today is the selected day and the plot is scrolled so today’s column is fully visible

#### Scenario: Pick a day other than today
- **WHEN** the user selects a day that is not today
- **THEN** the plot does not snap back to today

#### Scenario: Return from Home
- **WHEN** the app was in the background and the user opens it again
- **THEN** today is the selected day and the plot is scrolled so today’s column is fully visible

### Requirement: Compact cycle-days strip
The system SHALL keep the cycle-days strip shorter in height than a full med lane so more of the chart fits on a small viewport while still showing day numbers and period/symptom marks.

#### Scenario: Cycle strip density
- **WHEN** the user views the cycle chart on a narrow phone
- **THEN** the cycle-days row is visually shorter than a medication band row
