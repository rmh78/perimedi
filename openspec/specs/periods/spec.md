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
The system SHALL allow the user to view and edit average cycle length and average period length, and to add, edit, and delete period history entries (start, end, flow, notes).

#### Scenario: Save averages
- **WHEN** the user saves new average cycle and period lengths
- **THEN** cycle window sizing and predictions use the updated values

#### Scenario: Edit period
- **WHEN** the user edits a period’s start or end date and saves
- **THEN** cycle day numbering and period markers update accordingly

#### Scenario: Open cycle settings
- **WHEN** the user activates Cycle settings from the day card
- **THEN** the period settings sheet opens
