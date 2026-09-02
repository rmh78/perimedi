## ADDED Requirements

### Requirement: Effective date when dose or schedule changes
When the user is saving a medication whose default dose or primary schedule actually changed, the system SHALL allow choosing an effective date for that change. If the user does not choose another date, the effective date SHALL be the save day.

#### Scenario: Default effective date
- **WHEN** the user changes the default dose and saves without picking another date
- **THEN** the stored change is effective on the save day

#### Scenario: Chosen effective date
- **WHEN** the user changes the default dose, picks an earlier date as since-when, and saves
- **THEN** the stored change is effective on that chosen date
