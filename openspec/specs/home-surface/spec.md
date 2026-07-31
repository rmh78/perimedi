# home-surface Specification

## Purpose

Provide a single Home surface where the user sees today’s cycle context, dose progress, the cycle chart, and the month calendar without navigating to separate care pages.

## Requirements

### Requirement: Home is the primary surface
The system SHALL present cycle overview, medications, day context, and month calendar on a single Home route so the user can work without a separate care section.

#### Scenario: Open the app
- **WHEN** the user opens the application
- **THEN** the Home surface is shown with hero context, meds/cycle area, and month calendar

### Requirement: Hero shows today’s cycle and dose progress
The system SHALL display today’s date, a cycle-day heading when a cycle day is known, an estimated next period when available, and today’s taken versus planned dose counts.

#### Scenario: Cycle day known
- **WHEN** a cycle day can be derived for today from period data
- **THEN** the hero heading includes that cycle day number without a duplicate small day chip under it

#### Scenario: Dose progress
- **WHEN** planned doses exist for today
- **THEN** the hero shows taken/total progress for today’s doses

### Requirement: Hero omits duplicate primary period and symptom actions
The system SHALL NOT place Start period, End period, or + Symptom action buttons on the hero when those actions are available elsewhere on Home.

#### Scenario: Hero actions
- **WHEN** the user views the hero card
- **THEN** Start period, End period, and + Symptom are not present as hero buttons
