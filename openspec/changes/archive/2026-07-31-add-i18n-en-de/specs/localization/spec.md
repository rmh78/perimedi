## Purpose

Provide English and German product UI, language choice and persistence, sensible defaults, and locale-aware dates so users can use PeriMedi in their preferred language without a server.

## ADDED Requirements

### Requirement: Supported languages
The system SHALL support product UI in English (`en`) and German (`de`) only.

#### Scenario: English UI
- **WHEN** the active language is English
- **THEN** product chrome (labels, buttons, sheet titles, legends, empty states, validation and confirm copy provided by the app) is shown in English

#### Scenario: German UI
- **WHEN** the active language is German
- **THEN** product chrome is shown in German

### Requirement: Language selection
The system SHALL allow the user to switch the active language between English and German from the More surface (or an equally discoverable settings control on Home).

#### Scenario: Switch to German
- **WHEN** the user selects German
- **THEN** the active language becomes German and visible product chrome updates without requiring a full page reload outside normal SPA rendering

#### Scenario: Switch to English
- **WHEN** the user selects English
- **THEN** the active language becomes English and visible product chrome updates accordingly

### Requirement: Persist language preference
The system SHALL persist the user’s language choice on the device so it is restored on later visits in the same browser profile.

#### Scenario: Return visit
- **WHEN** the user previously selected a language and later opens the app in the same browser profile
- **THEN** the previously selected language is active

### Requirement: Default language when unset
When no language preference is stored, the system SHALL choose German if the browser’s preferred languages indicate German, otherwise English.

#### Scenario: German browser, no preference
- **WHEN** no language preference is stored and the browser preferred languages include German
- **THEN** the initial active language is German

#### Scenario: Other browser, no preference
- **WHEN** no language preference is stored and the browser preferred languages do not include German
- **THEN** the initial active language is English

### Requirement: User-entered content stays as typed
The system SHALL NOT retranslate user-entered free text (medication names, dose strings, symptom notes, period notes, and similar user fields) when the language changes.

#### Scenario: Language switch with custom med name
- **WHEN** the user has a medication named with custom text and switches language
- **THEN** that medication name is unchanged

### Requirement: Locale-aware dates and calendar chrome
The system SHALL format dates and calendar weekday/month labels according to the active language’s locale conventions.

#### Scenario: German month labels
- **WHEN** the active language is German and the month calendar is visible
- **THEN** month and weekday labels use German locale conventions

#### Scenario: English month labels
- **WHEN** the active language is English and the month calendar is visible
- **THEN** month and weekday labels use English locale conventions

### Requirement: Document language attribute
The system SHALL reflect the active language on the document language attribute so assistive tech and the browser can treat the page language correctly.

#### Scenario: Active language reflected
- **WHEN** the active language is German
- **THEN** the document language indicates German
