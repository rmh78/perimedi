# periods Specification

## Purpose

Track menstrual periods so cycle day numbering, predictions, and period markers stay consistent across the app.

## Requirements

### Requirement: Period defines cycle day one
The system SHALL treat the first day of a logged period as cycle day 1 for subsequent cycle-day calculations until a later period start supersedes it.

#### Scenario: Day one of bleed
- **WHEN** a period’s start date is selected or displayed
- **THEN** that date is cycle day 1 for that cycle

### Requirement: No mid-bleed cycle starts
The system SHALL NOT place a cycle start marker on a day that falls inside another period’s bleed except when that day is that period’s own start.

#### Scenario: No second start during blood days
- **WHEN** a day is within a logged period’s bleed but is not that period’s start date
- **THEN** the day is not marked as a cycle start

### Requirement: Period settings and history
The system SHALL allow the user to turn period tracking on or off. When tracking is on, the system SHALL allow the user to view and edit average cycle length and average period length, and to add, edit, and delete period history entries (start, end, flow). Average lengths SHALL be shown only when period tracking is on, SHALL be chosen from a day-count list (not free text), and SHALL persist when the settings sheet closes. Start and end dates for a new or edited period SHALL appear on one row. Period history SHALL sit at the bottom of the sheet under the Add control, and SHALL list each entry as a compact row (short date range, length and flow) so a long history remains scannable. The date range SHALL be underlined. Activating it SHALL open one card on top titled Edit period (German: Periode bearbeiten). The Add control SHALL open that same card empty, titled New period (German: Neue Periode). The card SHALL place Cancel on the left and Save (German: Speichern) on the right. When editing, the card SHALL also offer Delete (German: Löschen). Delete SHALL replace that card’s contents with a question that names the period’s date range. The settings sheet SHALL NOT require a separate save-settings action or a notes field.

#### Scenario: Compact history rows
- **WHEN** several periods are logged and the user opens cycle settings
- **THEN** history is below the Add control at the bottom of the sheet, and each entry occupies one short row with its underlined range, not a tall card with stacked buttons

#### Scenario: Save averages
- **WHEN** tracking is on and the user changes average cycle or period length and closes the sheet
- **THEN** cycle window sizing and predictions use the updated values

#### Scenario: Turn tracking off
- **WHEN** the user turns period tracking off
- **THEN** cycle and period length fields and period history are hidden, and Cycle does not use period history for the day row, cycle-day numbers, or predicted period marks

#### Scenario: Edit period
- **WHEN** tracking is on and the user edits a period’s start or end date and saves
- **THEN** cycle day numbering and period markers update accordingly

#### Scenario: Open cycle settings
- **WHEN** the user activates Cycle settings from the day card
- **THEN** the period settings sheet opens with a control to track periods or not
