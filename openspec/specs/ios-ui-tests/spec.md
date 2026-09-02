# ios-ui-tests Specification

## Purpose

Prove that a person can actually perform PeriMedi’s empty-to-tracking journey on iOS by driving the real controls from an empty store and asserting UI elements and resulting state. Screenshots are failure evidence, not the pass/fail oracle.

## Requirements

### Requirement: Primary controls have stable identifiers
Primary Cycle, Month, More, sheet, lane, and dose-status controls SHALL expose a language-independent accessibility identifier so automation can find them without relying on English or German chrome. VoiceOver labels SHALL remain the localized (or user-entered) text.

#### Scenario: Tabs and Cycle actions are findable in English
- **WHEN** the app is launched with English chrome and a cleared store
- **THEN** Cycle, Month, and More destinations, the day pager (previous, next, Today, current-day label), and the Cycle actions to add a medication, open cycle settings, and add a symptom are each uniquely identifiable without reading the visible title string

#### Scenario: Identifiers stay stable in German
- **WHEN** the active language is German
- **THEN** the same identifier values still resolve to those controls and the visible chrome is German

#### Scenario: Lanes and dose status after a medication is saved
- **WHEN** the user saves a medication named Estrogen
- **THEN** Cycle exposes a lane control for that medication and a taken/not-taken status for the selected day that automation can read without parsing pixels

### Requirement: Test launch can pin language, empty store, and today
When launched for verification, the app SHALL honor a pinned English chrome flag, a clear-store flag, and a pinned calendar date for “today.” With a pinned date, the default selected day and every “today” calculation SHALL use that date instead of the device clock.

#### Scenario: Empty English launch on a pinned day
- **WHEN** the app is launched with English pinned, the store cleared, and today pinned to a calendar date
- **THEN** Cycle opens with no medications and no periods, chrome is English, and the selected day is that pinned date

#### Scenario: Pinned today survives a period relative to today
- **WHEN** today is pinned and the user logs a period that starts eight days before today
- **THEN** that start date is eight calendar days before the pinned date, not eight days before the device clock

### Requirement: Empty-to-tracking journey is machine-verifiable
An instrumented UI suite SHALL consist of a single first-use journey that drives the real controls (not by writing the resulting records into the store) and SHALL fail if a step’s UI elements or resulting state are wrong. The suite SHALL start from a cleared store and a pinned today. The journey SHALL follow a first-session path: empty home, log a recent period, add everyday and cyclic medications, mark today’s dose taken, page back through the week and return to today, log a symptom, then confirm Month agrees.

#### Scenario: Empty Cycle
- **WHEN** the suite launches onto Cycle with no data
- **THEN** a requirements card names the missing period and missing medication, the PeriMedi intro card is shown, no medication lanes are present, and the add-medication, cycle-settings, and add-symptom actions are available

#### Scenario: Add a period through the UI
- **WHEN** the suite opens cycle settings, adds a period from eight days before the pinned today through four days before it, and saves
- **THEN** Cycle shows the day strip with that span marked as period, the requirements card names the missing medication, and the PeriMedi intro card is gone

#### Scenario: Requirements card goes away after period and medication
- **WHEN** both a period and a medication exist
- **THEN** the requirements card is gone

#### Scenario: Add mixed medications through the UI
- **WHEN** the suite adds an everyday pill named Estrogen and a cyclic cream named Progesterone through the medication sheet
- **THEN** Cycle shows two lanes, one for each name

#### Scenario: Mark taken through the UI
- **WHEN** the suite marks Estrogen taken on the pinned today
- **THEN** that lane’s status reads taken

#### Scenario: Look back at the week then return to today
- **WHEN** the suite pages backward to a logged period day and then activates Today
- **THEN** a period chip is shown on that earlier day, and after Today the pager is back on the pinned date with Estrogen still taken

#### Scenario: Symptom then Month
- **WHEN** the suite adds a symptom whose description is hot flush on the pinned today and then opens Month
- **THEN** Month shows the pinned today selected and reflects the logged period span, the taken mark, and the symptom, and after returning to Cycle both medication lanes remain and Estrogen still reads taken

#### Scenario: Seeded journey launch is not this proof
- **WHEN** the instrumented suite runs
- **THEN** it does not pre-load the journey’s medications, periods, doses, or remarks; those records exist only because the suite created them through the UI

### Requirement: Screenshots are evidence, not the gate
A failed instrumented step SHALL retain a screenshot (or equivalent visual attachment) for a human. Passing SHALL be determined by UI-element and state assertions, not by pixel comparison against a reference image.

#### Scenario: Failure keeps a picture
- **WHEN** an instrumented step fails because an expected control or value is missing
- **THEN** a screenshot of the Simulator at that step is available in the test result and the failure message names the missing control or value

#### Scenario: Visual drift does not fail the suite
- **WHEN** type size, spacing, or system chrome differs from a previously captured PNG but the same controls and values are present
- **THEN** the instrumented suite still passes
