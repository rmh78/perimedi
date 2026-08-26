# responsive-layout Specification

## Purpose

Keep PeriMedi’s multi-screen shell and sheets usable from a narrow iPhone through larger iPhones and iPad, with shared touch-friendly controls and intentional overflow only where designed (cycle plot).

## Requirements

### Requirement: Fluid layout across iPhone and iPad
The system SHALL present Cycle, Month, and More in one app layout that adapts from a narrow iPhone (SE-class) through larger iPhones to iPad, without a separate site or size-specific app.

#### Scenario: Narrow phone
- **WHEN** the user opens the app on a narrow iPhone
- **THEN** the active primary screen and bottom navigation remain usable and no primary content is permanently clipped without a way to reach it

#### Scenario: Larger iPhone and iPad
- **WHEN** the user opens the app on a larger iPhone or iPad
- **THEN** the same screens appear with spacing that uses the wider viewport without page-level horizontal scroll for the shell

### Requirement: Comfortable primary touch targets
The system SHALL size primary interactive controls (bottom nav items, day selection, month day cells, primary/ghost/destructive capsule buttons, medication taken toggles, sheet close) so they are easy to activate with a finger under normal use. Dialog capsule buttons SHALL be at least 36 points tall.

#### Scenario: Primary buttons on phone
- **WHEN** the user views primary actions on a phone
- **THEN** those actions are large enough to tap without relying on adjacent empty space alone

### Requirement: No horizontal page pan for the app shell
The system SHALL avoid requiring the user to pan the whole page horizontally to use the header, primary screens, or sheets; horizontal scrolling, when used, SHALL be limited to regions that intentionally overflow (for example the cycle plot).

#### Scenario: Open sheet on phone
- **WHEN** the user opens a sheet on a phone
- **THEN** the sheet content is usable within the viewport width without panning the page behind it

### Requirement: Sheets remain closable on narrow viewports
The system SHALL keep modal sheets closable on narrow phone viewports: the dedicated close control SHALL remain reachable without scrolling the sheet body, and backdrop dismiss SHALL work when provided. Long sheet content SHALL scroll inside the panel.

#### Scenario: Close sheet on iPhone SE-class width
- **WHEN** the user opens a sheet on a narrow phone viewport
- **THEN** they can close it via the close control without the control being permanently off-screen or untappable

#### Scenario: Long sheet content
- **WHEN** sheet body content is taller than the available panel height on a phone
- **THEN** the body scrolls within the panel and the close control in the sheet header remains reachable

### Requirement: Sheets sit above the software keyboard
When the software keyboard is visible, the system SHALL lift the open dialog so the panel sits above the keyboard. The dialog body SHALL shrink and scroll if needed so the close control remains reachable.

#### Scenario: Type in a dialog field
- **WHEN** the user focuses a text field in a medication, period, or symptom dialog
- **THEN** the dialog moves up with the keyboard and is not covered by it

### Requirement: Sheets have horizontal inset
The system SHALL present modal sheets with visible left and right inset from the viewport edges (including safe-area insets) so the panel is not flush edge-to-edge on small phones.

#### Scenario: Sheet open on phone
- **WHEN** a sheet is open on a phone
- **THEN** the panel leaves space on the left and right of the viewport

### Requirement: Medication color palette fits narrow sheets
When the user edits or adds a medication, the system SHALL present the color palette as a single row so all swatches are visible without horizontal scrolling on a narrow phone.

#### Scenario: Color picker on SE-class width
- **WHEN** the user opens add/edit medication on a narrow phone
- **THEN** every palette color is reachable on one row without scrolling the palette sideways
