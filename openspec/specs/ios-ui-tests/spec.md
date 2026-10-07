# ios-ui-tests Specification

## Purpose

Prove that a person can perform PeriMedi’s real-world jobs on iOS by driving the real controls from a cleared store and asserting UI elements and resulting state. The required suite is one English app journey and one English widget journey. The app journey is the empty-to-tracking first session, then settings, a due dose reminder, and Trends once several cycles exist. The widget journey changes size in the same process and runs in continuous integration. Screenshots are failure evidence and a committed English UX catalog, not the pass/fail oracle. German product chrome is covered by the string-table check rather than a second Simulator pass.

## Requirements

### Requirement: Primary controls have stable identifiers
Primary Cycle, Trends, Month, More, sheet, lane, and dose-status controls SHALL expose a language-independent accessibility identifier so automation can find them without relying on English or German chrome. VoiceOver labels SHALL remain the localized (or user-entered) text.

#### Scenario: Tabs and Cycle actions are findable in English
- **WHEN** the app is launched with English chrome and a cleared store
- **THEN** Cycle, Trends, Month, and More destinations, the day pager (previous, next, Today, current-day label), and the Cycle actions to add a medication, open cycle settings, and add a symptom are each uniquely identifiable without reading the visible title string

#### Scenario: Identifiers stay stable in German
- **WHEN** the active language is German
- **THEN** the same identifier values still resolve to those controls and the visible chrome is German

#### Scenario: Lanes and dose status after a medication is saved
- **WHEN** the user saves a medication named Estrogen
- **THEN** Cycle exposes a lane control for that medication and a taken/not-taken status for the selected day that automation can read without parsing pixels

### Requirement: Test launch can pin language, empty store, and today
When launched for verification, the app SHALL honor a pinned English chrome flag, a clear-store flag, and a pinned calendar date for “today.” With a pinned date, the default selected day and every “today” calculation SHALL use that date instead of the device clock. The widget journey SHALL pin today to the device’s current calendar day so Home Screen rows match that day.

#### Scenario: Empty English launch on a pinned day
- **WHEN** the app is launched with English pinned, the store cleared, and today pinned to a calendar date
- **THEN** Cycle opens with no medications and no periods, chrome is English, and the selected day is that pinned date

#### Scenario: Pinned today survives a period relative to today
- **WHEN** today is pinned and the user logs a period that starts eight days before today
- **THEN** that start date is eight calendar days before the pinned date, not eight days before the device clock

### Requirement: Empty-to-tracking journey is machine-verifiable
An instrumented UI suite SHALL include one English app journey that drives the real controls (not by writing the resulting records into the store) and SHALL fail if a step’s UI elements or resulting state are wrong. The suite SHALL start that journey from a cleared store and a pinned today. The journey SHALL follow a first-session path: empty home, empty Trends, log a recent period, edit and delete that period, log it again, add everyday and cyclic medications, mark today’s doses taken from the in-app reminder, page back through the week and return to today, log a symptom, confirm Month agrees, page Month, then select a period day on Month and see that day on Cycle.

#### Scenario: Empty Cycle
- **WHEN** the suite launches onto Cycle with no data
- **THEN** a requirements card names the missing period and missing medication, the PeriMedi intro card is shown, no medication lanes are present, and the add-medication, cycle-settings, and add-symptom actions are available

#### Scenario: Empty Trends on first session
- **WHEN** the suite opens Trends before any period is logged
- **THEN** Trends explains that cycles are needed, no series chips are shown, and the suite returns to Cycle to continue tracking

#### Scenario: Edit and delete a period, then log it again
- **WHEN** the suite logs a period, changes its end so the history label is exactly `7–12 Mar 2026`, and confirms `Delete 7–12 Mar 2026?`
- **THEN** that history row is gone, the PeriMedi intro card returns, the requirements card names the missing period, and the suite logs the period again from eight days before the pinned today through four days before it before any medication is saved

#### Scenario: Add a period through the UI
- **WHEN** the suite opens cycle settings, adds a period from eight days before the pinned today through four days before it, and saves
- **THEN** Cycle shows the day strip with that span marked as period, the requirements card names the missing medication, and the PeriMedi intro card is gone

#### Scenario: Requirements card goes away after period and medication
- **WHEN** both a period and a medication exist
- **THEN** the requirements card is gone

#### Scenario: Add mixed medications through the UI
- **WHEN** the suite adds an everyday pill named Estrogen at 1 mg and a cyclic cream named Progesterone at 200 mg through the medication sheet
- **THEN** Cycle shows two lanes, one for each name

#### Scenario: Mark taken through the UI
- **WHEN** the suite marks Estrogen taken on the pinned today
- **THEN** that lane’s status reads taken

#### Scenario: Look back at the week then return to today
- **WHEN** the suite pages backward to a logged period day and then activates Today
- **THEN** a period chip is shown on that earlier day, and after Today the pager is back on the pinned date with Estrogen still taken

#### Scenario: Symptom then Month
- **WHEN** the suite adds a symptom whose description is hot flush on the pinned today and then opens Month
- **THEN** the hot-flush chip contains strong, and Month shows the pinned today selected and reflects the logged period span, the taken mark, and the symptom

#### Scenario: Month pager then a period day on Cycle
- **WHEN** the suite pages Month forward and back, activates Today, then selects the logged period start and opens Cycle
- **THEN** that period day is selected and visible on Cycle, and after activating Today both medication lanes remain and Estrogen still reads taken

#### Scenario: Seeded first-use launch is not this proof
- **WHEN** the English app journey runs its first-use steps
- **THEN** it does not pre-load the journey’s medications, periods, doses, or remarks; those records exist only because the suite created them through the UI

### Requirement: One English app journey and one English widget journey
The instrumented suite SHALL be two English journeys. The app journey SHALL cover More settings (both language controls present, reminders chrome, visit PDF preview, backup confirm-cancel), taking due doses from the in-app reminder card including snooze, and Trends after several scored cycles, in addition to the first-use path. Those steps SHALL drive real controls. Trends history MAY start from a dedicated fixture so the suite does not invent months of scores through the UI. The app journey SHALL NOT load sample data and SHALL NOT switch the app to German. The widget journey SHALL run in English on the device’s current calendar day, SHALL change from a medium widget to a small widget without launching the app again, and SHALL run in continuous integration as well as locally. German product chrome SHALL be checked by requiring every English product string to have a non-empty German value and every German product string to have an English value. That check SHALL NOT launch a Simulator.

#### Scenario: More settings stay in English
- **WHEN** the app journey opens More after both of today’s doses are taken
- **THEN** both language controls, reminders chrome, the visit PDF action through in-app preview, and backup rows are identifiable, the More tab reads More, and the journey does not switch to German, confirm a destructive wipe, or load sample

#### Scenario: Dose reminder including snooze
- **WHEN** a pending dose is due inside the pinned reminder window
- **THEN** the reminder card is shown, Taken marks the lane taken, clearing that take shows the card again, snooze dismisses the card without marking the dose taken, and taking again leaves the lane taken so a later save does not raise another card for that dose

#### Scenario: Progesterone is taken before Month
- **WHEN** the app journey has saved the cyclic Progesterone dose and a reminder card is showing for it
- **THEN** Taken on that card marks the Progesterone lane taken before Month opens

#### Scenario: One English widget journey changes size in process
- **WHEN** verification runs, including continuous integration, against today’s still-untaken medications on the Home Screen
- **THEN** the suite shows a medium widget for the device’s current day (not a historical pinned date), sees the long medication name, Take, and “Still to take today”, sees a check and then that row leave, brings the row back by un-taking on Cycle, takes the other medication from the widget, changes that same widget to small without launching the app again, and after the last take sees a check, then “All taken for today”, and restores the app icon without failing when restore runs again

#### Scenario: Trends with scored cycles
- **WHEN** the app journey opens Trends with several logged cycles that have scores
- **THEN** the chart, series, a tapped dot, and a dose-change tick are identifiable, including a hot-flush dot whose count is 8 and mean is 1 and a later dot whose count is 2 and mean is 4

#### Scenario: Trends with cycles but no scores
- **WHEN** the app journey opens Trends with logged cycles and no scores
- **THEN** Trends explains that there are no scores and shows no series chips

#### Scenario: Custom symptom on the scored Trends launch
- **WHEN** the app journey, still on the scored Trends launch, adds a custom symptom named Brain fog, renames it to Fog, and confirms deleting Fog and all its past scores
- **THEN** the delete question names Fog, the Fog chip is gone, and the hot-flush score stays selected

#### Scenario: German chrome is the string table
- **WHEN** verification checks product strings
- **THEN** each English string has a non-empty German value, each German string has an English value, and verification does not launch a second Simulator pass to read German chrome

### Requirement: Screenshots are evidence, not the gate
A failed instrumented step SHALL retain a screenshot (or equivalent visual attachment) for a human. Passing SHALL be determined by UI-element and state assertions, not by pixel comparison against a reference image.

#### Scenario: Failure keeps a picture
- **WHEN** an instrumented step fails because an expected control or value is missing
- **THEN** a screenshot of the Simulator at that step is available in the test result and the failure message names the missing control or value

#### Scenario: Visual drift does not fail the suite
- **WHEN** type size, spacing, or system chrome differs from a previously captured PNG but the same controls and values are present
- **THEN** the instrumented suite still passes

### Requirement: Committed catalog of main screens
A dedicated catalog capture SHALL write a small committed catalog of English Simulator pictures of the main destinations: Cycle empty, Cycle with data, Trends empty, Trends with data, Month, and More, plus the medication, period, and symptom sheets. The catalog SHALL NOT require German pictures. The capture SHALL navigate those destinations in a small number of English launches (tabs and Cycle sheet actions) rather than launching once per picture, and SHALL NOT switch language. Sample data and Trends fixtures MAY seed catalog pictures; they SHALL NOT be the first-use proof. Verification SHALL fail if an expected English catalog picture is missing from the committed files. Verification SHALL NOT fail because pixels differ from a previous capture. Visual review SHALL use those committed pictures (the pull-request file diff), not a gallery of images pasted into pull-request comments. Continuous integration MAY skip rewriting the pictures; it SHALL still fail when a committed English file is missing, and it SHALL still run the English widget journey.

#### Scenario: Missing catalog picture fails
- **WHEN** an expected English main-screen catalog picture is not present in the committed catalog
- **THEN** verification fails

#### Scenario: Pixel drift does not fail the catalog
- **WHEN** a catalog picture differs in pixels from an earlier capture but the file is present
- **THEN** verification still passes

#### Scenario: Catalog capture is one English empty session
- **WHEN** the catalog capture writes English pictures of empty Cycle, empty Trends, and the add sheets
- **THEN** those pictures come from navigating one empty-store English session, not from a separate app launch for each file and not from a German pass

### Requirement: Visit share control is identifiable
The More visit PDF action SHALL expose a language-independent accessibility identifier. The English app journey SHALL wait for that control. Catalog pictures of More SHALL include the visit entry. Verification SHALL NOT paste screenshot galleries into pull-request comments.

#### Scenario: App journey finds the visit action
- **WHEN** the English app journey opens More
- **THEN** the visit PDF action is uniquely identifiable without reading the visible title string

#### Scenario: App journey opens preview without the share sheet
- **WHEN** the English app journey activates the visit PDF action and continues from the range picker
- **THEN** the in-app preview and its Share control are uniquely identifiable, and the journey does not activate Share

#### Scenario: More catalog includes the visit entry
- **WHEN** the committed English More catalog picture is written
- **THEN** the visit PDF entry is on that picture

#### Scenario: Catalog includes the range picker and in-app preview
- **WHEN** the committed screen catalog is written
- **THEN** it includes English pictures of the cycle picker and the in-app visit PDF preview from sample data
