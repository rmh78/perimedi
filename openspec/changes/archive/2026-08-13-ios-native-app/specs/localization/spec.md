## MODIFIED Requirements

### Requirement: Language selection
The system SHALL allow the user to switch the active language between English and German from the More surface (or an equally discoverable settings control).

#### Scenario: Switch to German
- **WHEN** the user selects German
- **THEN** the active language becomes German and visible product chrome updates without requiring the user to relaunch the app

#### Scenario: Switch to English
- **WHEN** the user selects English
- **THEN** the active language becomes English and visible product chrome updates accordingly

### Requirement: Persist language preference
The system SHALL persist the user’s language choice on the device so it is restored the next time the user opens the app on that same installation.

#### Scenario: Return visit
- **WHEN** the user previously selected a language and later opens the app on the same device or Simulator installation
- **THEN** the previously selected language is active

### Requirement: Default language when unset
When no language preference is stored, the system SHALL choose German if the device’s preferred languages indicate German, otherwise English.

#### Scenario: German device, no preference
- **WHEN** no language preference is stored and the device preferred languages include German
- **THEN** the initial active language is German

#### Scenario: Other device, no preference
- **WHEN** no language preference is stored and the device preferred languages do not include German
- **THEN** the initial active language is English

### Requirement: Document language attribute
The system SHALL expose the active language to the platform so assistive technologies treat the UI language correctly.

#### Scenario: Active language reflected
- **WHEN** the active language is German
- **THEN** the platform accessibility language indicates German
