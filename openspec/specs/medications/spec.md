# medications Specification

## Purpose

Let the user define medications with form, default dose, and color so they can be scheduled, shown on the cycle chart, and distinguished visually.

## Requirements

### Requirement: Unified medication dialog
The system SHALL allow the user to add and edit a medication including form, default dose, color, primary schedule, and whether reminders fire at take times, in a single dialog without requiring a separate primary-schedule-only flow.

#### Scenario: Add medication with schedule
- **WHEN** the user saves a new medication with a valid name, default dose, and at least one take time
- **THEN** the medication and its primary schedule are persisted and the dialog closes

#### Scenario: Edit existing medication
- **WHEN** the user opens an existing medication and saves changes
- **THEN** the medication fields and primary schedule are updated

#### Scenario: Remind at take times
- **WHEN** the user saves a medication with reminders on
- **THEN** pending take times for that medication are eligible for dose reminders

#### Scenario: Remind off
- **WHEN** the user saves a medication with reminders off
- **THEN** that medication does not produce dose reminders until reminders are turned on again

### Requirement: Reminder switch and outside blocks
The per-medication reminder switch SHALL be labeled "Remind me" (German: "Erinnere mich"). It SHALL sit after take times and before the Type picker. A new medication SHALL start with that switch on. Under the switch, not in the footer, and only while that switch is on, the dialog SHALL show one muted line and one action for each outside block that is stopping reminders. It SHALL show nothing under the switch when that switch is off. It SHALL show nothing new when that switch is on, app reminders are on, and iOS has not denied notifications. When that switch is on and app reminders are off, the muted line SHALL read "App reminders are off." (German: "Erinnerungen in der App sind aus.") and the action SHALL read "Turn on" (German: "Einschalten"). Turn on SHALL turn app reminders on through the same path as the More Reminders switch, including the permission request, and SHALL leave the dialog open with the typed fields unchanged. If app reminders end up on and iOS has not denied notifications, the app line SHALL be gone. If iOS denies notifications, or had already denied them, the dialog SHALL show the iOS line instead. Cancel SHALL NOT turn app reminders back off. When that switch is on and iOS has denied notifications, the muted line SHALL read "Notifications are off in iOS." (German: "Mitteilungen sind in iOS aus.") and the action SHALL read "Open Settings" (German: "Einstellungen öffnen"). Open Settings SHALL open the page for this app in iOS Settings and SHALL NOT ask for permission again. When both blocks apply and the switch is on, the dialog SHALL show the app line first and the iOS line second.

#### Scenario: App reminders off
- **WHEN** the user opens Add or Edit medication with the reminder switch on while app reminders are off
- **THEN** the dialog shows "App reminders are off." (German: "Erinnerungen in der App sind aus.") and "Turn on" (German: "Einschalten") under the reminder switch

#### Scenario: Medication switch off
- **WHEN** the reminder switch is off
- **THEN** the dialog shows no line under it, even if app reminders are off or iOS has denied notifications

#### Scenario: Turn on keeps the dialog
- **WHEN** the user chooses Turn on on that line
- **THEN** the dialog stays open, the typed fields are unchanged, app reminders are on, and the app line is gone

#### Scenario: Turn on when iOS has denied notifications
- **WHEN** the user chooses Turn on and iOS has denied notifications
- **THEN** the dialog stays open and shows "Notifications are off in iOS." with "Open Settings"

#### Scenario: Cancel leaves app reminders on
- **WHEN** the user chooses Cancel after Turn on
- **THEN** app reminders stay on

#### Scenario: iOS denied
- **WHEN** the reminder switch is on, iOS has denied notifications, and the user opens Add or Edit medication
- **THEN** the dialog shows "Notifications are off in iOS." (German: "Mitteilungen sind in iOS aus.") and "Open Settings" (German: "Einstellungen öffnen"), and choosing Open Settings opens the page for this app in iOS Settings without asking for permission again

#### Scenario: Both gates
- **WHEN** the reminder switch is on, app reminders are off, and iOS has denied notifications
- **THEN** the dialog shows the app line first, then the iOS line

#### Scenario: Nothing to explain
- **WHEN** the reminder switch is on, app reminders are on, and iOS has not denied notifications
- **THEN** the dialog shows the reminder switch and no extra line under it

### Requirement: Medication forms and icons
The system SHALL support medication forms pill, cream, drops, injection, and other, each with an icon that fills the medication avatar circle.

#### Scenario: Form selection
- **WHEN** the user selects a form type for a medication
- **THEN** the avatar icon matches that form and fills the circle

### Requirement: Medication color
The system SHALL allow the user to choose a color from a single-row palette of mid and deep tones (not powder-light swatches) and SHALL apply that color to the medication icon ring, dose bands, and taken-day fills. Each swatch SHALL keep its color. The chosen swatch SHALL have a dark ring. Every other swatch SHALL have a visible blush edge. While the dialog is open, picking a swatch SHALL tint only the circle around the medication icon, not the icon artwork.

#### Scenario: Color choice
- **WHEN** the user selects a palette color and saves the medication
- **THEN** the cycle chart uses that color for the med’s icon ring, dose bands, and taken marks

#### Scenario: Dialog icon ring follows the palette
- **WHEN** the user picks a palette color while the medication dialog is open
- **THEN** the colored circle around the medication icon updates to that color and the icon artwork itself is unchanged

#### Scenario: Unselected swatches keep a blush edge
- **WHEN** the medication dialog shows the color palette
- **THEN** the chosen swatch has a dark ring and every other swatch keeps its fill with a visible blush edge

#### Scenario: Default color by form
- **WHEN** a medication has no custom color stored
- **THEN** a form-based default color is used for display

### Requirement: Effective date when dose or schedule changes
When the user is saving a medication whose default dose or primary schedule actually changed, the system SHALL allow choosing an effective date for that change. That control SHALL sit next to the dose field and SHALL say when this dose starts, not a vague “since” after the schedule. If the user does not choose another date, the effective date SHALL be the save day. The control SHALL remain available whenever a dose or schedule change would be recorded, including a new medication with a dose.

#### Scenario: Default effective date
- **WHEN** the user changes the default dose and saves without picking another date
- **THEN** the stored change is effective on the save day

#### Scenario: Chosen effective date
- **WHEN** the user changes the default dose, picks an earlier date as since-when, and saves
- **THEN** the stored change is effective on that chosen date

#### Scenario: Dose-from sits next to the dose
- **WHEN** the user types a dose on add medication
- **THEN** a dose-from date appears next to the dose field, not after the schedule block
