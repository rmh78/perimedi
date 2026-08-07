## ADDED Requirements

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
The system SHALL identify the visible month with a month/year label and Prev / Today / Next controls, without a separate page title that only repeats the nav label “Month”.

#### Scenario: Month card header
- **WHEN** the user opens Month
- **THEN** the header shows the calendar month and year plus navigation controls
