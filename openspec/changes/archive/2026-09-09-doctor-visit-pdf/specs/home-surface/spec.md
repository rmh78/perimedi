## MODIFIED Requirements

### Requirement: Homogeneous primary cards
Primary screens Cycle, Trends, Month, and More SHALL present content in a glass-style card without redundant page titles that only repeat the bottom-nav label (e.g. no standalone “Month”, “Trends”, or “More” heading whose only role is the tab name).

#### Scenario: Trends header
- **WHEN** the user opens Trends
- **THEN** the card shows the chart (or empty copy) and pin control without a separate “Trends” or “Verlauf” title that only repeats the tab

#### Scenario: Month header
- **WHEN** the user opens Month
- **THEN** the card header shows the calendar month/year and navigation controls, not a separate “Month” title alone

#### Scenario: More header
- **WHEN** the user opens More
- **THEN** the card shows Language, Reminders, a visit PDF action, and Backup sections without a redundant “More” page title
