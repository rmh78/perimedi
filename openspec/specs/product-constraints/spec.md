# product-constraints Specification

## Purpose

Capture cross-cutting product constraints: demo/not-medical-advice stance, modal reliability, build quality, and UX clarity.

## Requirements

### Requirement: Not medical advice
The system SHALL present the product as a personal demo companion and SHALL NOT present sample data or UI as clinical medical advice.

#### Scenario: Demo stance
- **WHEN** the user uses sample data or standard UI copy
- **THEN** the product does not claim to provide medical advice

### Requirement: Modal presentation
The system SHALL render modal sheets above page content so they are not clipped by overflow containers and remain closable (including Escape and backdrop where provided).

#### Scenario: Open sheet over chart
- **WHEN** the user opens a sheet while the cycle chart is visible
- **THEN** the sheet content is fully visible and can be closed

### Requirement: Production build
The iOS app SHALL compile and launch on the iOS Simulator from the project’s standard Xcode build. While the web companion remains in the repository, it SHALL still pass TypeScript checking and production bundling via its standard build command.

#### Scenario: iOS Simulator build
- **WHEN** a developer builds and runs the iOS app for the iOS Simulator
- **THEN** the build succeeds and the app launches to the Cycle screen

#### Scenario: Web companion build
- **WHEN** a developer runs `npm run build` in the web companion
- **THEN** the build completes successfully

### Requirement: Clear, non-duplicative primary actions
The system SHALL prefer compact UI copy and SHALL avoid duplicate primary actions for the same job when a clear single place exists (for example period and symptom actions on the Cycle header rather than also as a second hero row).

#### Scenario: Cycle header is the action hub
- **WHEN** the user views the Cycle screen
- **THEN** add-medication, cycle-settings, and add-symptom are not duplicated as a second primary row elsewhere on that screen

### Requirement: Modal presentation on iOS
The system SHALL present medication, period, and symptom editors as sheets above the current screen so they are not clipped by the chart or calendar and remain closable via a dedicated close control (and a backdrop or swipe dismiss when provided).

#### Scenario: Open sheet over chart on iOS
- **WHEN** the user opens a sheet while the cycle chart is visible on iOS
- **THEN** the sheet content is fully visible and can be closed

### Requirement: Localized clear UI copy
The system SHALL provide clear, compact product chrome in each supported language and SHALL keep the not-medical-advice stance in the active language’s copy where such messaging appears.

#### Scenario: German compact actions
- **WHEN** the active language is German
- **THEN** primary actions use short German labels equivalent in role to the English actions (for example add medication, cycle settings, add symptom)

#### Scenario: Demo stance in active language
- **WHEN** the user views product messaging about the demo or medical advice stance
- **THEN** that messaging is shown in the active language and does not claim clinical medical advice
