# effect-summary Specification

## Purpose

Give the user a cycle-to-cycle payoff sentence on Cycle, using logged symptom scores and stored dose or schedule changes as context only, never as medical advice.

## Requirements

### Requirement: Cycle-aligned comparison windows
The system SHALL compare **this cycle so far** with the **same cycle days of the previous cycle**. A cycle SHALL be the first day of a logged period through the day before the next logged period start. The current window SHALL be cycle days 1 through the cycle day of today (or the last day of the current cycle if today is after that cycle). The previous window SHALL be the same cycle-day numbers in the immediately previous logged cycle. The system SHALL NOT use a rolling calendar-day window (for example the last 7 days) for this comparison. Predicted period starts SHALL NOT define comparison cycles.

#### Scenario: Same cycle days
- **WHEN** today is cycle day 11 of the current logged cycle and a previous logged cycle exists
- **THEN** the comparison uses days 1–11 of this cycle against days 1–11 of the previous cycle

#### Scenario: No rolling week
- **WHEN** the user has scores in the last seven calendar days that fall on unmatched cycle days
- **THEN** those unmatched days are not treated as the comparison windows

### Requirement: Effect sentence on Cycle
The system SHALL show one Effect sentence on the Cycle screen. The sentence SHALL use only catalog symptom ids that have at least one score in both comparison windows. Missing ids and missing days SHALL NOT be treated as 0. Higher severity SHALL mean worse. Copy SHALL be English and German according to the active language. The sentence SHALL NOT recommend changing a dose or otherwise give medical advice.

#### Scenario: Two cycles of dummy scores
- **WHEN** two consecutive logged cycles exist and overlapping ids have scores aligned by cycle day
- **THEN** Cycle shows one sentence that names those symptoms and whether each is better or worse than last cycle

#### Scenario: Only one cycle logged
- **WHEN** only one logged cycle exists (no previous cycle start)
- **THEN** Cycle shows a line equivalent to “No previous cycle to compare yet.”

#### Scenario: Too few overlapping scores
- **WHEN** a previous cycle exists but no catalog id has a score in both windows
- **THEN** Cycle shows a line equivalent to “Not enough days for a comparison yet.”

#### Scenario: Similar scores
- **WHEN** overlapping ids exist but none differ enough to call better or worse
- **THEN** Cycle shows a line equivalent to “Symptoms similar to last cycle.”

#### Scenario: Period tracking off
- **WHEN** period tracking is off
- **THEN** Cycle does not show an Effect sentence

### Requirement: Stored change is context only
When a stored dose or schedule change has an effective date in the current comparison cycle or the previous comparison cycle, the system SHALL add context that includes the medication name and the new value. That context SHALL NOT claim the change caused the symptom difference and SHALL NOT advise a treatment change.

#### Scenario: Dose change in this cycle
- **WHEN** a stored dose change for a named medication is effective in this cycle or the previous cycle and a comparison sentence exists
- **THEN** the Effect line includes that medication name and new dose as context and does not claim the dose caused the change in symptoms

#### Scenario: Change outside the two cycles
- **WHEN** the only stored change is effective before the previous comparison cycle
- **THEN** the Effect line does not mention that change

### Requirement: Record dose and schedule changes
When the user saves a medication and the default dose label or the primary schedule actually changed, the system SHALL append one on-device change event per changed field. Starting a new medication SHALL count as a change with an empty previous value. Saving without a dose or schedule difference SHALL NOT write an event. The system SHALL NOT invent events from sample load except as part of that sample payload. Each event SHALL record medication id, name snapshot, field (`dose` or `schedule`), previous value, new value, effective date, and logged-at time. The effective date SHALL be the save day unless the user chose another date on that save. Changing a value and later changing it back SHALL write two events.

#### Scenario: Change dose then change it back
- **WHEN** the user saves a medication with a new default dose and later saves the previous dose again
- **THEN** two dose change events exist, each with the values from that save

#### Scenario: Unchanged save
- **WHEN** the user opens a medication and saves without changing default dose or primary schedule
- **THEN** no new change event is stored

#### Scenario: New medication
- **WHEN** the user saves a new medication with a default dose
- **THEN** a dose change event is stored with an empty previous value and the new dose
