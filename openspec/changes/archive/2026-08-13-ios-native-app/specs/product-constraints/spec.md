## MODIFIED Requirements

### Requirement: Production build
The iOS app SHALL compile and launch on the iOS Simulator from the project’s standard Xcode build. While the web companion remains in the repository, it SHALL still pass TypeScript checking and production bundling via its standard build command.

#### Scenario: iOS Simulator build
- **WHEN** a developer builds and runs the iOS app for the iOS Simulator
- **THEN** the build succeeds and the app launches to the Cycle screen

#### Scenario: Web companion build
- **WHEN** a developer runs `npm run build` in the web companion
- **THEN** the build completes successfully

## ADDED Requirements

### Requirement: Modal presentation on iOS
The system SHALL present medication, period, and symptom editors as sheets above the current screen so they are not clipped by the chart or calendar and remain closable via a dedicated close control (and a backdrop or swipe dismiss when provided).

#### Scenario: Open sheet over chart on iOS
- **WHEN** the user opens a sheet while the cycle chart is visible on iOS
- **THEN** the sheet content is fully visible and can be closed
