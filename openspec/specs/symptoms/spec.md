# symptoms Specification

## Purpose

Let the user log structured symptom scores for a date (easy today, analyzable later) and show those scores on Cycle and Month.

## Requirements

### Requirement: Structured log for a date
The system SHALL present one symptom log screen for the selected date with eleven rows in three visible groups and no extra taps to reach a group: Body (Hot flushes, Heart, Sleep, Joints), Mood (Low mood, Irritability, Anxiety, Exhaustion), Intimacy (Sexual, Bladder, Dryness). German group labels SHALL be Körper, Stimmung, Intim, Heart SHALL be labeled Herzstolpern in German, Low mood SHALL be labeled Stimmung, Sexual SHALL be labeled Lust auf Sex, and Bladder SHALL be labeled Harndrang. Each row SHALL use a 1–4 scale in the same direction (higher is worse). Leaving a row blank SHALL mean none for that symptom. The four steps SHALL use short words that fit that symptom (for example Sleep uses restless / poor / bad / very bad, not strong). The system SHALL NOT paste official MRS questionnaire wording; symptom names SHALL be the short product names above. The log screen SHALL NOT include a free-text field.

#### Scenario: Open log from day card
- **WHEN** the user activates + Symptom for the selected date
- **THEN** the log screen shows the eleven rows grouped Body / Mood / Intimacy (or Körper / Stimmung / Intim in German), each with four unlabeled-as-none steps 1–4, no free-text field, and no row is pre-filled

### Requirement: Missing is not zero
The system SHALL treat a row the user does not touch as none and SHALL NOT store it (missing, not a stored 0). The user SHALL NOT be required to fill all eleven rows. Choosing a 1–4 value SHALL store that row immediately. A new choice for an id on that calendar day SHALL replace that id’s score for the day. At most one scored record exists per id per calendar day. There SHALL NOT be a 0 control. The sheet SHALL NOT have Save or Cancel; the header close control dismisses it.

#### Scenario: Partial day
- **WHEN** the user sets today Hot flushes to 3, Sleep to 2, and Joints to 1 and leaves the other eight rows untouched
- **THEN** those three scores are stored for today and the eight untouched ids are absent (not stored as 0)

#### Scenario: Replace same id same day
- **WHEN** the user later sets today’s Hot flushes to 4
- **THEN** today’s Hot flushes score is 4 and no second Hot flushes record exists for that date

### Requirement: Stable ids and higher-is-worse
Each scored record SHALL use a stable id that is never translated: `hot_flash`, `heart`, `sleep`, `joints`, `mood`, `irritability`, `anxiety`, `exhaustion`, `sexual`, `bladder`, `vaginal_dryness`. Every id SHALL be `higher_is_worse`. Each record SHALL include the calendar date, severity 1–4, and `loggedAt` with time. New saves SHALL omit episode count and SHALL omit a free-text note. Older backups MAY still carry an optional note field; the log screen SHALL NOT edit it.

#### Scenario: Export a partial day
- **WHEN** the user exports after logging today Hot flushes 3, Sleep 2, and Joints 1
- **THEN** the JSON includes those records with id, severity, date, and loggedAt, and untouched ids are absent

### Requirement: Display scores on Cycle and Month
The system SHALL show logged scores on Cycle and Month in a compact way (short label plus value, dots, or compact digits). Symptom marks SHALL appear on the cycle strip and month cells for dates that have scores. Activating a Cycle score chip SHALL open the log screen for that date. The selected-day summary SHALL NOT delete a score.

#### Scenario: Selected day has scores
- **WHEN** the selected date has Hot flushes 3, Sleep 2, and Joints 1
- **THEN** Cycle shows those compact scores and Month marks that day as having symptoms

#### Scenario: Open log from a score chip
- **WHEN** the user activates a selected-day score chip
- **THEN** the log screen opens for that date with the saved values filled and untouched rows still empty

### Requirement: Edit and delete like the log screen
The system SHALL let the user change or clear a day’s scores from the same log screen. Choosing a selected 1–4 value again SHALL clear that row immediately (missing, not a stored 0).

#### Scenario: Clear a row
- **WHEN** the user opens a day that has Sleep 2 and clears Sleep
- **THEN** Sleep is absent for that date and other scores for that date remain

### Requirement: Averages use scores only
Later analysis SHALL compute means from scored records only. Missing ids SHALL NOT enter those means as zeros or as scores.

#### Scenario: Missing ids do not change averages
- **WHEN** a date has no Hot flushes score
- **THEN** that date is omitted from a Hot flushes mean (it is not treated as 0)

### Requirement: Backup stays compatible
The system SHALL keep version-1 JSON export and import working. Older backups that have remarks and no symptom score list SHALL import. New exports SHALL include the symptom score list. The system SHALL NOT require a PeriMedi server to store scores.

#### Scenario: Import older backup
- **WHEN** the user imports a valid version-1 backup that has remarks and no symptom scores
- **THEN** medications, periods, remarks, and other payload fields restore and symptom scores are empty
