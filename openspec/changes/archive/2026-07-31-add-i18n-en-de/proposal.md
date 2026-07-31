## Why

PeriMedi’s UI is English-only. Users who prefer German (or switch between both) need the full product chrome—labels, actions, empty states, and confirmations—in their language without losing local-only privacy or the home-first flow.

## What Changes

- Add bilingual UI support for **English** and **German**.
- Let the user choose language and persist that choice on-device.
- Localize all product chrome (sheets, buttons, legends, hero, calendar chrome, validation messages, backup UI).
- Keep user-entered content (med names, notes, custom doses) as the user typed it.
- Format dates and weekday/month labels according to the active locale.
- Default language from the browser when no preference is stored (English fallback if neither en nor de).

## Capabilities

### New Capabilities
- `localization`: Language selection (en/de), persistence, defaulting, and that product UI strings and locale-sensitive dates follow the active language.

### Modified Capabilities
- `product-constraints`: Clarify that clear UI copy applies in each supported language (still not medical advice).
- `backup-and-sample`: Sample-data and backup UI strings follow the active language; imported user data is not re-translated.

## Impact

- New i18n messages modules (or equivalent) and a small locale preference store (localStorage or settings table).
- Touch nearly all React components under `src/components/` and `src/pages/` that hardcode English copy.
- Possible lightweight dependency (e.g. `i18next` / `react-i18next`) or a minimal custom dictionary + hook—design will choose.
- `date-fns` locale modules for `en` and `de`.
- No backend, no accounts, no analytics; remains client-only IndexedDB app.
