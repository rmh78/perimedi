## ADDED Requirements

### Requirement: Visit PDF stays on device until shared
The system SHALL generate the visit PDF on the device. The system SHALL NOT upload that PDF to a PeriMedi server. Sharing SHALL use the platform share sheet so the user chooses where the copy goes.

#### Scenario: Generate without a network account
- **WHEN** the user generates a visit PDF with no PeriMedi account
- **THEN** the file is created on the device and is not submitted to a PeriMedi backend

#### Scenario: User chooses the destination
- **WHEN** the share sheet is shown for the visit PDF
- **THEN** the user picks the destination (for example Mail, Files, or Print)
