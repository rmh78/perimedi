## MODIFIED Requirements

### Requirement: Empty-to-tracking journey matches the web companion
The iOS app SHALL support a first-use empty-to-tracking journey: start empty, log a recent period, add mixed medications, mark a dose taken, look back through the week and return to today, add a symptom, and confirm Month agrees. Instrumented UI-element verification from a cleared store SHALL be the proof that a user can perform those steps. A reviewer MAY still compare fresh web 375 screenshots with iOS Simulator screenshots for visual-family checks; screenshot pairs SHALL NOT be the only proof that the journey works.

#### Scenario: Empty start
- **WHEN** the user opens Cycle with no medications and no periods
- **THEN** the empty medications card and the intro card are shown and no dose tracks appear

#### Scenario: Add a period
- **WHEN** the user logs a period from Cycle
- **THEN** that span is marked as period on Cycle and Month

#### Scenario: Add mixed medications
- **WHEN** the user adds at least two medications with different forms and different schedule styles (for example every day versus cyclic or a dated range)
- **THEN** each appears as its own lane and dose track on Cycle

#### Scenario: Pager previous and next
- **WHEN** the user activates previous day on Cycle and then Today
- **THEN** the selected day and pager label move backward and then return to today

#### Scenario: Mark taken
- **WHEN** the user marks a planned dose taken on the selected day
- **THEN** the lane status shows taken and remains taken after leaving Cycle and returning

#### Scenario: Instrumented journey from empty
- **WHEN** an instrumented suite starts from a cleared store and drives the journey through the real controls
- **THEN** each step’s outcome is present as UI elements and values, including Month after the last Cycle step

#### Scenario: Journey screenshot pairs
- **WHEN** a reviewer compares each freshly captured web 375 journey shot with the matching iOS Simulator shot
- **THEN** that step’s outcome matches and no major region present on the web step is missing on iOS
