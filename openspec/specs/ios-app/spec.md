# ios-app Specification

## Purpose

Deliver PeriMedi as a native iOS application with the same Cycle, Month, and More tracking features as the current companion, runnable on the iOS Simulator without a custom backend.

## Requirements

### Requirement: iOS application is the product
The system SHALL present PeriMedi as a native iOS application that the user launches from the home screen (or Simulator) and SHALL NOT require a web browser or hosted origin to use core tracking features.

#### Scenario: Launch on Simulator
- **WHEN** a developer runs the iOS app on the iOS Simulator
- **THEN** the Cycle screen appears with the bottom navigation band and the app is usable without opening a browser

### Requirement: Same primary destinations
The system SHALL present Cycle, Month, and More as the only primary destinations, with Cycle as the default screen after launch.

#### Scenario: First launch destinations
- **WHEN** the user opens the iOS app
- **THEN** Cycle is shown and Month and More are available from the bottom navigation

#### Scenario: Switch among destinations
- **WHEN** the user activates Month or More
- **THEN** that primary screen is shown without requiring a modal as the only way to reach it

### Requirement: Feature parity for tracking
The system SHALL allow the user to add and edit medications and schedules, log doses as taken or not taken, log periods and cycle settings, add symptoms and notes, and load sample data, using sheets rather than extra full-screen pages for those edits.

#### Scenario: Add medication on iOS
- **WHEN** the user saves a new medication with a valid name, default dose, and at least one take time
- **THEN** the medication and its primary schedule are persisted and appear on Cycle and Month

#### Scenario: Toggle a planned dose
- **WHEN** the user marks a planned dose taken and later marks it not taken
- **THEN** the stored status matches the last choice and both Cycle and Month reflect it

#### Scenario: Log a period and a symptom
- **WHEN** the user logs a period span and a symptom on a date
- **THEN** those marks appear on Cycle and Month for that date

### Requirement: Shared selected date
The system SHALL keep a shared selected calendar date across Cycle and Month so a day chosen on one screen remains selected when the user switches tabs.

#### Scenario: Month pick then Cycle
- **WHEN** the user selects a date on Month and then opens Cycle
- **THEN** the cycle chart and day-context area reflect that selected date

### Requirement: iPhone layout and safe areas
The system SHALL keep Cycle, Month, More, and sheets usable on an iPhone-class Simulator viewport, including the home-indicator and status-bar safe areas, without requiring the user to pan the whole screen horizontally to reach primary controls. The brand header SHALL extend into the status-bar region and the bottom navigation SHALL extend into the home-indicator region so those bands are app chrome, not empty margins. Tappable controls SHALL stay clear of the status-bar island and the home indicator.

#### Scenario: iPhone SE-class Simulator
- **WHEN** the user uses the app on a narrow iPhone Simulator
- **THEN** bottom navigation, header actions, and sheet close controls remain reachable and are not permanently covered by system insets

#### Scenario: Notch and home indicator chrome
- **WHEN** the user opens Cycle on a device with a status-bar island and a home indicator
- **THEN** the header’s background fills the status-bar band without covering the island or status icons, the wordmark and header art sit below the island, and Cycle / Month / More sit on the bottom edge just above the home indicator

### Requirement: English and German chrome
The system SHALL provide English and German product chrome on iOS and SHALL keep user-entered text untranslated.

#### Scenario: German chrome on iOS
- **WHEN** the active language is German
- **THEN** primary actions, navigation labels, and sheet titles are in German and user-entered medication names stay as typed

### Requirement: Visual family matches the web companion
The system SHALL present Cycle, Month, and More in the same visual family as the web companion: a blush/lilac background, a PeriMedi wordmark in the header, rounded card surfaces, and a pill-style bottom navigation. The system SHALL NOT use stock system-gray chrome as the primary look.

#### Scenario: Cycle chrome
- **WHEN** the user opens Cycle
- **THEN** the wordmark, blush/lilac surfaces, rounded cards, and pill-style Cycle / Month / More navigation are visible

### Requirement: Cycle layout matches the web companion
The Cycle screen SHALL use the same regions in the same order as the web companion: wordmark; selected-day pager (previous, day/date, next) with Today and compact medication, period, and symptom actions; a cycle-day strip with period drops and symptom marks; sticky medication labels beside horizontally scrolling multi-day dose bands; and a highlight on the selected day’s column.

#### Scenario: Cycle regions with sample data
- **WHEN** the user views Cycle with medications and a logged cycle
- **THEN** the day pager, action controls, cycle-day strip, sticky med labels, and multi-day dose bands are all present and the selected day is highlighted as a column

### Requirement: Month layout matches the web companion
The Month screen SHALL use the same regions as the web companion: month title with previous / Today / next; a legend for cycle start, cycle end, cycle day, period, predicted period, symptom, taken, and not taken; a seven-column calendar with cycle-day badges, period-day tint, period drops, symptom marks, and taken marks; and a clear outline on the selected day.

#### Scenario: Month regions with sample data
- **WHEN** the user views Month with sample or imported data
- **THEN** the pager, legend, seven-column grid, cycle-day badges, and period/symptom/taken marks are visible and the selected day is outlined

### Requirement: More layout matches the web companion
The More screen SHALL present a Language block (English and German as selectable pills) and a Backup block whose rows (sample, export, import, clear) each have a trailing action, matching the web companion’s section order.

#### Scenario: More sections
- **WHEN** the user opens More
- **THEN** language pills appear above backup rows, and each backup action sits on the trailing side of its row

### Requirement: Dialog layout matches the web companion
The medication, period-settings, and symptom editors SHALL use the same visual pattern as the current web companion: an inset rounded panel over the current screen (not a full-bleed gray system form as the primary look), a header with title and a dedicated close control, and the same field groups in the same order. The medication color palette SHALL show every swatch without horizontal scrolling.

#### Scenario: Add medication dialog
- **WHEN** the user opens add medication
- **THEN** the panel shows a close control, name/form/dose/color, exclusive schedule modes (every day, specific days, cyclic), take times, and start/end dates

#### Scenario: Period and symptom dialogs
- **WHEN** the user opens period settings or the symptom editor
- **THEN** each is an inset closable panel with the same section order as the current web companion (settings and history for period; logged list plus add fields for symptoms)

### Requirement: Screenshot comparison against the web companion
Comparisons SHALL use screenshots taken from the **current** web companion at approximately 375-point phone width (not older stored files) and iOS Simulator screenshots of the same screen. Cycle, Month, More, and the three dialogs SHALL show the same major regions in the same order. Small differences in type size, spacing, or system chrome are allowed. Missing a major region (dose tracks, month legend, wordmark, pill navigation, dialog header/close, color palette, or schedule modes) is not.

#### Scenario: Compare Cycle shots
- **WHEN** a reviewer compares a freshly captured web 375 Cycle screenshot with an iOS Simulator Cycle screenshot of comparable data
- **THEN** both show wordmark, day pager and actions, cycle strip, med labels, and dose tracks in that hierarchy

#### Scenario: Compare Month and More shots
- **WHEN** a reviewer compares freshly captured web 375 Month and More screenshots with iOS Simulator shots of those screens
- **THEN** Month includes the legend and marked calendar grid, and More includes language pills above backup rows with trailing actions

#### Scenario: Compare dialog shots
- **WHEN** a reviewer compares freshly captured web 375 shots of add medication, period settings, and symptoms with iOS Simulator shots of those dialogs
- **THEN** each pair shows header plus close, the same field groups in the same order, and (for medication) a fully visible color palette and exclusive schedule modes

### Requirement: Empty-to-tracking journey matches the web companion
The iOS app SHALL support the same empty-to-tracking journey as the current web companion. A reviewer SHALL capture a fresh web 375 screenshot and an iOS Simulator screenshot at each listed step; both sides SHALL show the same outcome and the same major regions.

#### Scenario: Empty start
- **WHEN** the user opens Cycle with no medications and no periods
- **THEN** the empty medications card and the intro card are shown and no dose tracks appear

#### Scenario: Add a period
- **WHEN** the user logs a period from Cycle
- **THEN** that span is marked as period on Cycle and Month

#### Scenario: Add mixed medications
- **WHEN** the user adds at least two medications with different forms and different schedule styles (for example every day versus cyclic or a dated range)
- **THEN** each appears as its own lane and dose track on Cycle

#### Scenario: Edit and delete a medication
- **WHEN** the user edits one medication’s name or dose and deletes another
- **THEN** Cycle and Month show the edited fields and no longer show the deleted medication

#### Scenario: Pager previous and next
- **WHEN** the user activates previous day and then next day on Cycle
- **THEN** the selected day, pager label, and highlighted column move backward and then forward

#### Scenario: Mark taken
- **WHEN** the user marks a planned dose taken on the selected day
- **THEN** the lane status shows taken and remains taken after leaving Cycle and returning

#### Scenario: Journey screenshot pairs
- **WHEN** a reviewer compares each freshly captured web 375 journey shot with the matching iOS Simulator shot
- **THEN** that step’s outcome matches and no major region present on the web step is missing on iOS
