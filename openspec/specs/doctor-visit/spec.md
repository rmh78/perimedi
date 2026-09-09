# doctor-visit Specification

## Purpose

Give the user an on-device PDF she can share from More before a gynecologist visit. It is a personal cycle-aligned summary, not a medical record and not medical advice.

## Requirements

### Requirement: Share visit PDF from More
The system SHALL provide one action on the More screen that opens a cycle picker, then an in-app preview of the generated PDF. Share SHALL be a control on that preview that opens the platform share sheet (for example Mail, Files, or Print). The user SHALL stay in the app until they choose Share. The system SHALL NOT add a new primary destination for this action. The system SHALL NOT place this action on Cycle. The PDF SHALL be produced without a PeriMedi account or server.

#### Scenario: Preview from More
- **WHEN** the user activates the visit PDF action on More, chooses a range, and continues
- **THEN** an in-app preview of the PDF is shown and the system share sheet is not shown yet

#### Scenario: Share from the preview
- **WHEN** the user activates Share on the visit PDF preview
- **THEN** the system share sheet is shown

### Requirement: Choose historical cycles
The system SHALL let the user choose which completed cycle (and optionally the completed cycle before it) the PDF covers, including cycles earlier than the latest. When no completed cycle exists, the system SHALL keep the four-week / twelve-week fallback.

#### Scenario: Pick an older completed cycle
- **WHEN** two or more completed cycles exist and the user selects an earlier one
- **THEN** the PDF range is that completed cycle (and the previous completed cycle if the user included it)

#### Scenario: Thin history still has a fallback
- **WHEN** no completed cycle exists and the user continues from the range picker
- **THEN** the PDF uses the four-week or twelve-week fallback

#### Scenario: Not a new tab
- **WHEN** the user views the bottom navigation
- **THEN** the destinations remain Cycle, Month, Trends, and More only

#### Scenario: Not on Cycle
- **WHEN** the user is on Cycle
- **THEN** there is no control whose only purpose is to generate the visit PDF

### Requirement: Cycle-aligned range
The system SHALL choose the PDF date range from logged period starts, not from a rolling seven-day window. A completed cycle SHALL be a logged period start through the day before the next logged period start. Predicted period starts SHALL NOT define the range. When two or more completed cycles exist, the range SHALL be the last two completed cycles. When only one completed cycle exists, the range SHALL be that cycle. When no completed cycle exists and at least one logged period start exists, the range SHALL be the last four weeks ending today. When no logged period start exists, or period tracking is off, the range SHALL be the last twelve weeks ending today.

#### Scenario: Two completed cycles
- **WHEN** logged periods start on 1 January, 1 February, and 1 March and today is 15 March
- **THEN** the PDF range is 1 January through 28 February (the last two completed cycles) and does not include the current March cycle

#### Scenario: One completed cycle
- **WHEN** logged periods start on 1 February and 1 March and today is 15 March
- **THEN** the PDF range is 1 February through 28 February

#### Scenario: Thin history uses four weeks
- **WHEN** the only logged period start is 1 March and today is 15 March
- **THEN** the PDF range is the last four weeks ending 15 March

#### Scenario: No period history uses twelve weeks
- **WHEN** no logged period start exists
- **THEN** the PDF range is the last twelve weeks ending today

#### Scenario: Period tracking off uses twelve weeks
- **WHEN** period tracking is off
- **THEN** the PDF range is the last twelve weeks ending today even if period rows still exist

### Requirement: Visit PDF contents
The PDF SHALL include: the date it was generated; the date range used; medications that had planned doses in that range and how often those planned doses were marked taken; stored dose or schedule changes whose effective date falls in that range, presented as context only; periods that overlap that range; the current Effect sentence when Cycle would show one; and a visible disclaimer that the PDF is not a medical record and not medical advice. Change context SHALL NOT claim a dose or schedule change caused a symptom difference and SHALL NOT advise a treatment change. JSON backup and iCloud behavior SHALL remain unchanged.

#### Scenario: Dummy range with scores, periods, meds, and a dose change
- **WHEN** the chosen range contains dummy symptom scores, a logged period, planned doses with some marked taken, and one stored dose change
- **THEN** the PDF includes each of those, the generated date, and the disclaimer

#### Scenario: Effect sentence when present
- **WHEN** Cycle would show an Effect sentence that does not name a stored change outside the PDF range
- **THEN** that sentence appears on the PDF

#### Scenario: No Effect sentence
- **WHEN** Cycle would not show an Effect sentence
- **THEN** the PDF omits an Effect sentence

#### Scenario: Effect names a change outside the range
- **WHEN** Cycle’s Effect sentence names a stored dose or schedule change whose effective date is outside the PDF range
- **THEN** the PDF omits that Effect sentence

#### Scenario: In-range change is listed
- **WHEN** the PDF includes an Effect sentence that names a stored change
- **THEN** that change is listed under dose and schedule changes as context only, and the PDF does not say there were no changes in the range

#### Scenario: Change is context only
- **WHEN** a stored dose change falls in the range
- **THEN** the PDF names the medication and new value as context and does not claim the change caused symptoms

### Requirement: Symptom table, not a Trends chart
The PDF SHALL list only catalog symptom ids that have at least one score in the range, each with the count of days scored and the mean intensity of those scores (1–4). Missing days and missing ids SHALL NOT be treated as 0. For `hot_flash`, the count SHALL be days scored until a separate episode log exists; the system SHALL NOT invent episode counts from 1–4 scores or from an optional count field. The system SHALL NOT paste the Trends chart into the PDF or draw all catalog symptoms as a graphic. The system SHALL NOT paste official MRS questionnaire wording.

#### Scenario: Scored ids only
- **WHEN** two catalog ids have scores in the range and the others do not
- **THEN** the PDF table includes those two ids with days scored and mean, and omits the unscored ids

#### Scenario: Missing is not zero
- **WHEN** a symptom is scored on three days in a 28-day range and left blank on the other days
- **THEN** days scored is 3 and the mean uses only those three scores

#### Scenario: Hot flush uses days scored
- **WHEN** `hot_flash` rows in the range include an optional episode-count field
- **THEN** the table count for that id is still the number of days scored, not those episode counts

#### Scenario: No Trends chart copy
- **WHEN** the PDF is generated
- **THEN** it does not include the Trends plot or a graphic of all eleven symptoms

### Requirement: English and German visit copy
Visit action labels on More and the PDF chrome (headings, range labels, table headers, disclaimer) SHALL follow the active language (English or German). User-entered medication names and dose strings SHALL stay as stored.

#### Scenario: German PDF
- **WHEN** the active language is German and the user generates the visit PDF
- **THEN** headings and the disclaimer are in German, medication names remain as typed, and a pump unit is shown as Hub
