# dose-reminders Specification

## Purpose

Remind the user at each planned medication take time using on-device iOS notifications, without a PeriMedi server or Clock-app alarms.

## Requirements

### Requirement: Reminder at pending take times
The system SHALL schedule an on-device reminder for each future pending planned dose whose medication has reminders enabled and whose device master reminders switch is on. The system SHALL NOT schedule reminders for taken or skipped slots, inactive schedules, dates outside the schedule start/end range, or cyclic pause days. The system SHALL NOT send dose reminders through a PeriMedi server.

#### Scenario: Everyday take time
- **WHEN** a medication is scheduled every day at 08:00, reminders are on, and that slot is still pending
- **THEN** a reminder is scheduled for 08:00 on each upcoming applicable day

#### Scenario: Already taken
- **WHEN** the user has marked a planned slot taken
- **THEN** no reminder remains scheduled for that slot

#### Scenario: Cyclic pause
- **WHEN** a cyclic plan is in a pause day
- **THEN** no reminder is scheduled for that day

#### Scenario: Reminders off for one medication
- **WHEN** the user turns reminders off for a medication and leaves the master switch on
- **THEN** that medication’s slots are not scheduled and other medications still are

#### Scenario: Master switch off
- **WHEN** the user turns the device reminders switch off
- **THEN** pending dose reminders are cleared

### Requirement: Notification content and actions
The system SHALL present a reminder whose title is a dose prompt, whose subtitle is the medication name, and whose body names the dose label and planned take time and tells the user to choose Taken after taking it. English title SHALL be “Time for your dose”; German title SHALL be “Zeit für deine Dosis”. English body SHALL be “Take {dose} · planned {time}. Tap Taken when you’ve taken it.”; German body SHALL be “Nimm {dose} · geplant {time}. Tippe auf Genommen, wenn erledigt.” The in-app reminder banner SHALL use the same title, medication name, and body. The reminder SHALL offer Taken (first) and Snooze actions. Taken SHALL record that planned slot as taken. Snooze SHALL schedule one follow-up reminder about ten minutes later for the same slot. Activating the reminder (not an action) SHALL open Cycle on that slot’s date.

#### Scenario: Taken from the banner
- **WHEN** a reminder fires and the user chooses Taken
- **THEN** that planned slot is recorded as taken and Cycle shows it as taken

#### Scenario: Snooze
- **WHEN** a reminder fires and the user chooses Snooze
- **THEN** another reminder for the same slot is scheduled about ten minutes later

#### Scenario: Open the day
- **WHEN** the user activates the reminder banner
- **THEN** Cycle is shown for that slot’s date

#### Scenario: Notification copy
- **WHEN** a reminder fires for a medication named Estreva with dose 0.5 mg at 08:00 and the app language is English
- **THEN** the reminder title is “Time for your dose”, the subtitle is Estreva, and the body is “Take 0.5 mg · planned 08:00. Tap Taken when you’ve taken it.”

### Requirement: Reminder sound
The system SHALL let the user choose the reminder sound in More from a small list: the system default notification sound, or one of the short tones bundled with the app. The chosen sound SHALL be used for later reminders on this device. The system SHALL allow the user to preview a bundled tone before it is due.

#### Scenario: Choose a bundled tone
- **WHEN** the user selects a bundled reminder sound in More
- **THEN** subsequent dose reminders on this device play that sound

#### Scenario: Preview
- **WHEN** the user previews a reminder sound
- **THEN** that tone plays immediately without logging a dose

### Requirement: Permission
The system SHALL ask for notification permission on first launch when the master reminders switch is on (the default) and permission has not yet been decided, and again when the user turns reminders on (master switch or saving a medication with reminders enabled) if permission is still undecided. The system SHALL NOT repeatedly prompt after the user denies. When permission is denied and the master switch is on, More SHALL explain that reminders need notification access in iOS Settings. Instrumented UI tests SHALL NOT present the system permission dialog. They MAY fire the next pending reminder through a test launch flag and mark it Taken on a reminder card without asserting the system banner.

#### Scenario: Fresh install
- **WHEN** the user launches the app for the first time with reminders on and the system has not yet asked
- **THEN** the system permission prompt is shown

#### Scenario: First enable
- **WHEN** the user turns reminders on and the system has not yet asked
- **THEN** the system permission prompt is shown

#### Scenario: Denied
- **WHEN** notification permission is denied and reminders are on
- **THEN** More shows a short explanation pointing to iOS Settings and does not prompt again on launch
