# symptoms Specification

## Purpose

Let the user log structured symptom scores for a date (easy today, analyzable later) and show those scores on Cycle and Month. Optional free-text is a one-line day note only.

## Requirements

### Requirement: Structured log for a date
The system SHALL present one symptom log screen for the selected date with eleven rows in three visible groups and no extra taps to reach a group: Body (Hot flushes, Heart, Sleep, Joints), Mood (Low mood, Irritability, Anxiety, Exhaustion), Urogenital (Sexual, Bladder, Dryness). German group labels SHALL be Körper, Stimmung, Urogenital. Each row SHALL use a 0–4 scale in the same direction (higher is worse: 0 = none, 4 = very strong). The system SHALL NOT paste official MRS questionnaire wording; labels SHALL be the short product names above.

#### Scenario: Open log from day card
- **WHEN** the user activates + Symptom for the selected date
- **THEN** the log screen shows the eleven rows grouped Body / Mood / Urogenital (or Körper / Stimmung / Urogenital in German) and none of the rows is pre-filled with 0

### Requirement: Missing is not zero
The system SHALL treat a row the user does not touch as missing, not as severity 0. The user SHALL NOT be required to fill all eleven rows. Saving SHALL store only the rows that have a chosen 0–4 value. A new save for an id on that calendar day SHALL replace that id’s score for the day. At most one scored record exists per id per calendar day.

#### Scenario: Partial day
- **WHEN** the user sets today Hot flushes to 3, Sleep to 2, and Joints to 1, leaves the other eight rows untouched, and saves
- **THEN** those three scores are stored for today and the eight untouched ids are absent (not stored as 0)

#### Scenario: Replace same id same day
- **WHEN** the user later sets today’s Hot flushes to 4 and saves
- **THEN** today’s Hot flushes score is 4 and no second Hot flushes record exists for that date

### Requirement: Optional hot-flush count
On the Hot flushes row only, the system SHALL offer an optional episode count for that day as a stepper from 0 through 99. Other rows SHALL NOT have a count. Count SHALL be omitted from storage when the user does not set it.

#### Scenario: Count with hot flushes
- **WHEN** the user sets Hot flushes to 3 and the episode count to 8 and saves
- **THEN** the stored Hot flushes record includes severity 3 and count 8

### Requirement: Optional one-line day note
The system SHALL offer one optional one-line note for the day. The note SHALL never be required to save scores.

#### Scenario: Scores without a note
- **WHEN** the user saves scores and leaves the note empty
- **THEN** the scores are stored and no note is required

### Requirement: Stable ids and higher-is-worse
Each scored record SHALL use a stable id that is never translated: `hot_flash`, `heart`, `sleep`, `joints`, `mood`, `irritability`, `anxiety`, `exhaustion`, `sexual`, `bladder`, `vaginal_dryness`. Every id SHALL be `higher_is_worse`. Each record SHALL include the calendar date, severity 0–4, optional count (Hot flushes only), optional note, and `loggedAt` with time.

#### Scenario: Export a partial day
- **WHEN** the user exports after logging today Hot flushes 3 with count 8, Sleep 2, and Joints 1
- **THEN** the JSON includes those records with id, severity, date, and loggedAt, Hot flushes includes count 8, Sleep and Joints omit count, and untouched ids are absent

### Requirement: Display scores on Cycle and Month
The system SHALL show logged scores on Cycle and Month in a compact way (short label plus value, dots, or compact digits). Symptom marks SHALL appear on the cycle strip and month cells for dates that have scores or a day note. Activating a Cycle score chip SHALL open the log screen for that date. The selected-day summary SHALL NOT delete a score.

#### Scenario: Selected day has scores
- **WHEN** the selected date has Hot flushes 3, Sleep 2, and Joints 1
- **THEN** Cycle shows those compact scores and Month marks that day as having symptoms

#### Scenario: Open log from a score chip
- **WHEN** the user activates a selected-day score chip
- **THEN** the log screen opens for that date with the saved values filled and untouched rows still empty

### Requirement: Edit and delete like the log screen
The system SHALL let the user change or clear a day’s scores from the same log screen. Choosing a selected 0–4 value again SHALL clear that row (missing, not a stored 0). Saving SHALL persist the rows that still have a value.

#### Scenario: Clear a row
- **WHEN** the user opens a day that has Sleep 2, clears Sleep, and saves
- **THEN** Sleep is absent for that date and other scores for that date remain

### Requirement: Averages use scores only
Later analysis SHALL compute means from scored records only. Missing ids and free-text notes SHALL NOT enter those means as zeros or as scores.

#### Scenario: Notes do not change averages
- **WHEN** a date has a free-text note and no Hot flushes score
- **THEN** that date is omitted from a Hot flushes mean (it is not treated as 0)

### Requirement: Backup stays compatible
The system SHALL keep version-1 JSON export and import working. Older backups that have remarks and no symptom score list SHALL import. New exports SHALL include the symptom score list. The system SHALL NOT require a PeriMedi server to store scores.

#### Scenario: Import older backup
- **WHEN** the user imports a valid version-1 backup that has remarks and no symptom scores
- **THEN** medications, periods, remarks, and other payload fields restore and symptom scores are empty
