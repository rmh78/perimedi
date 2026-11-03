# ios-ui-tests Specification

## Purpose

Prove that a person can perform PeriMedi’s real-world jobs on iOS by driving the real controls from a cleared store and asserting UI elements and resulting state. The instrumented proof is one English user flow. A pull request and a full verification both run that flow. A full verification also runs the screen catalog. The flow is one launch on the device’s current day: empty home, one medication typed by name, one period saved as the new card opens, one symptom, Month, Trends, More, the visit preview, and one Take on the medium Home Screen widget. Screenshots are failure evidence and a committed English UX catalog, plus German pictures of the New symptom control and of More, not the pass/fail oracle. German product chrome is covered by the string-table check rather than a second Simulator pass.

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
When launched for verification, the app SHALL honor a pinned English chrome flag, a clear-store flag, and a pinned calendar date for “today.” With a pinned date, the default selected day and every “today” calculation SHALL use that date instead of the device clock. The user flow SHALL pin today to the device’s current calendar day so Home Screen rows match that day.

#### Scenario: Empty English launch on a pinned day
- **WHEN** the app is launched with English pinned, the store cleared, and today pinned to a calendar date
- **THEN** Cycle opens with no medications and no periods, chrome is English, and the selected day is that pinned date

#### Scenario: Pinned today survives a period relative to today
- **WHEN** today is pinned and the user logs a period that starts eight days before today
- **THEN** that start date is eight calendar days before the pinned date, not eight days before the device clock

### Requirement: One English user flow
An instrumented UI suite SHALL include one English flow that drives the real controls and SHALL fail if a step’s UI elements or resulting state are wrong. A pull request and a full verification SHALL both run that flow. A full verification SHALL also run the catalog capture. The flow SHALL start from a cleared store, pin today to the device’s current calendar day, and use one app launch. It SHALL type one everyday medication, leave the sheet on the form, type, time, and color it already shows, save one period from the new card as it opens, log one hot-flush score, open Month, Trends, and More, open the visit preview, and take the still-pending dose once from a medium Home Screen widget. Returning to the app SHALL show that dose taken. The flow SHALL NOT load sample data, switch language, snooze, page Month, change the widget size, or launch the app a second time. A pull-request run SHALL NOT rewrite the catalog or capture store frames. German product chrome SHALL be checked by requiring every English product string to have a non-empty German value and every German product string to have an English value. That check SHALL NOT launch a Simulator.

#### Scenario: Empty Cycle
- **WHEN** the flow launches onto Cycle with no data
- **THEN** the home names the missing medication

#### Scenario: One medication typed by name
- **WHEN** the flow saves an everyday medication named Estrogen at 1 mg by typing the name and the dose
- **THEN** Cycle shows one lane for that name

#### Scenario: One period and one symptom
- **WHEN** the flow saves the new period card as it opens and logs one hot-flush score
- **THEN** the period starts on the selected day with the card’s flow, the end stays empty, and the hot-flush chip is on Cycle

#### Scenario: Month, Trends, and the visit preview
- **WHEN** the flow opens Month, then Trends, then More
- **THEN** today’s month cell is identifiable, Trends is identifiable, the visit preview opens from More, and the flow does not activate Share or load sample

#### Scenario: One widget Take
- **WHEN** the flow turns the app icon into a medium widget and taps Take once
- **THEN** the widget is for the device’s current day, and the lane reads taken after the flow returns to the app

#### Scenario: Seeded launch is not this proof
- **WHEN** the flow runs
- **THEN** it does not pre-load medications, periods, doses, or remarks

#### Scenario: A pull request runs the same flow
- **WHEN** a pull-request verification starts from a cleared store
- **THEN** it runs this flow and does not switch language or rewrite the catalog

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
A dedicated catalog capture SHALL write a small committed catalog of English Simulator pictures of the main destinations: Cycle empty, Cycle with data, Trends empty, Trends with data, Month, and More, plus the medication, period, and symptom sheets. German catalog pictures SHALL be the New symptom control reading Neues Symptom and More in German. The capture SHALL navigate the English destinations in a small number of English launches (tabs and Cycle sheet actions) rather than launching once per picture. It MAY switch to German only long enough to write those two pictures, then return to English, and SHALL NOT switch language for any other catalog picture. The largest-text More picture SHALL be an expected catalog file written by that same capture. Sample data and Trends fixtures MAY seed catalog pictures; they SHALL NOT be the first-use proof. Verification SHALL fail if an expected catalog picture is missing from the committed files, including those German pictures, the largest-text More picture, and the two medium-widget pictures taken around Take. Verification SHALL NOT fail because pixels differ from a previous capture. Visual review SHALL use those committed pictures (the pull-request file diff), not a gallery of images pasted into pull-request comments. A pull-request run SHALL NOT rewrite the catalog pictures. A full verification, including the nightly run, SHALL rewrite the catalog pictures unless catalog capture is turned off. The two medium-widget pictures stay committed files. The user flow does not rewrite them. Verification SHALL still fail when a committed catalog file is missing.

#### Scenario: Missing catalog picture fails
- **WHEN** an expected catalog picture is not present in the committed catalog
- **THEN** verification fails

#### Scenario: Pixel drift does not fail the catalog
- **WHEN** a catalog picture differs in pixels from an earlier capture but the file is present
- **THEN** verification still passes

#### Scenario: Catalog capture is one English empty session
- **WHEN** the catalog capture writes English pictures of empty Cycle, empty Trends, and the add sheets
- **THEN** those pictures come from navigating one empty-store English session, not from a separate app launch for each file. The same capture also writes More in German and the largest-text More picture. The German catalog pictures are the New symptom control reading Neues Symptom and More

### Requirement: Visit share control is identifiable
The More visit PDF action SHALL expose a language-independent accessibility identifier. The user flow SHALL wait for that control. Catalog pictures of More SHALL include the visit entry. Verification SHALL NOT paste screenshot galleries into pull-request comments.

#### Scenario: User flow finds the visit action
- **WHEN** the user flow opens More
- **THEN** the visit PDF action is uniquely identifiable without reading the visible title string

#### Scenario: User flow opens preview without the share sheet
- **WHEN** the user flow activates the visit PDF action and continues from the range picker
- **THEN** the in-app preview and its Share control are uniquely identifiable, and the flow does not activate Share

#### Scenario: More catalog includes the visit entry
- **WHEN** the committed English More catalog picture is written
- **THEN** the visit PDF entry is on that picture

#### Scenario: Catalog includes the range picker and in-app preview
- **WHEN** the committed screen catalog is written
- **THEN** it includes English pictures of the cycle picker and the in-app visit PDF preview from sample data
