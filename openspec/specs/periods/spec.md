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
The system SHALL allow the user to turn period tracking on or off. When tracking is on, the system SHALL allow the user to view and edit average cycle length and average period length, and to add, edit, and delete period history entries (start, end, flow). Average lengths SHALL be shown only when period tracking is on, SHALL be chosen from a day-count list (not free text), and SHALL persist when the settings sheet closes. Start and end dates for a new or edited period SHALL appear on one row. Period history SHALL sit at the bottom of the sheet under the Add control, and SHALL list each entry as a compact row (short date range, length and flow) so a long history remains scannable. The date range SHALL be underlined. The length and the flow SHALL sit on the same line as that range. Activating it SHALL open one card on top titled Edit period (German: Periode bearbeiten). The Add control SHALL open that same card empty, titled New period (German: Neue Periode). The card SHALL place Cancel on the left and Save (German: Speichern) on the right. When editing, Cancel, Delete (German: Löschen), and Save SHALL share that one row, with Delete between them. Delete SHALL replace that card’s contents with a question that names the period’s date range. A filled date field SHALL show the stored calendar key (yyyy-MM-dd) when the language is English. When the language is German, a filled date field SHALL show that date as dd.MM.yyyy and an empty date field SHALL show TT.MM.JJJJ. A same-month German range SHALL name the days with ordinal dots and an en dash, then the full month name and year. The settings sheet SHALL NOT require a separate save-settings action or a notes field.

#### Scenario: Compact history rows
- **WHEN** several periods are logged and the user opens cycle settings
- **THEN** history is below the Add control at the bottom of the sheet, and each entry occupies one short row whose underlined range, length, and flow share that line

#### Scenario: Save averages
- **WHEN** tracking is on and the user changes average cycle or period length and closes the sheet
- **THEN** cycle window sizing and predictions use the updated values

#### Scenario: Turn tracking off
- **WHEN** the user turns period tracking off
- **THEN** cycle and period length fields and period history are hidden, and Cycle does not use period history for the day row, cycle-day numbers, or predicted period marks

#### Scenario: Edit period
- **WHEN** tracking is on and the user edits a period’s start or end date and saves
- **THEN** cycle day numbering and period markers update accordingly

#### Scenario: German filled dates
- **WHEN** the language is German and the user edits a period that runs from 7 March 2026 through 11 March 2026
- **THEN** the start field shows 07.03.2026 and the end field shows 11.03.2026

#### Scenario: German empty date
- **WHEN** the language is German and the user opens a new period card with no end date
- **THEN** the empty field shows TT.MM.JJJJ

#### Scenario: German delete question
- **WHEN** the language is German and the user deletes a period that runs from 7 March 2026 through 11 March 2026
- **THEN** the question names 7.–11. März 2026

#### Scenario: English date field
- **WHEN** the language is English and a filled date field holds 7 March 2026
- **THEN** that field shows the calendar key 2026-03-07

#### Scenario: Open cycle settings
- **WHEN** the user activates Cycle settings from the day card
- **THEN** the period settings sheet opens with a control to track periods or not
