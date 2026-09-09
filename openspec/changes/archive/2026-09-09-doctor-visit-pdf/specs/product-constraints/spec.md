## ADDED Requirements

### Requirement: Visit PDF is not a medical record
The visit PDF SHALL state that it is not a medical record and not medical advice. The system SHALL NOT present the PDF as clinical documentation or treatment guidance.

#### Scenario: Disclaimer on the PDF
- **WHEN** the user generates a visit PDF
- **THEN** the PDF includes visible copy that it is not a medical record and not medical advice
