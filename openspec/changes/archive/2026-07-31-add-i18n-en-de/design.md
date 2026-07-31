## Context

See proposal.md for motivation. UI strings are hardcoded English in React components (`HomePage`, sheets, diagram legend, badges). There is no locale layer, no language preference, and date formatting uses default (English-leaning) `date-fns`/`toLocale*` behavior. Data stays in IndexedDB (`perimedi`); privacy remains local-only.

## Goals / Non-Goals

**Goals:**
- One active language (`en` | `de`) driving all product chrome.
- Persist preference on-device; default from browser when unset.
- Locale-aware calendar/date labels via `date-fns` locales.
- Minimal surface for switching language (More sheet).
- Type-safe message keys so missing German/English strings fail loudly in development.

**Non-Goals:**
- Additional languages beyond en/de.
- Translating user-entered content or auto-detecting language of free text.
- Server-side localization, CDN message loading, or professional TMS.
- Separate translated sample medication catalogs per language.
- Full ICU plural/gender rules beyond simple parameterized strings.
- RTL layout.

## Decisions

### 1. Lightweight custom i18n (no i18next)

**Choice:** Small `LocaleProvider` + `useT()` / `t(key, params?)` with static message maps `en` and `de`, rather than `i18next` / `react-i18next`.

**Rationale:** The app is a single-route SPA with a few hundred strings. A custom dictionary keeps zero new runtime dependency, fits the stack, and is easy to audit. Nested keys (e.g. `med.form.pill`) and simple `{{name}}` interpolation are enough.

**Alternatives considered:**
- `react-i18next`: mature, but heavier for this scope and needs extra config for SPA-only use.
- Inline dual strings per component: hard to keep parity and test.

### 2. Message organization

**Choice:** `src/i18n/messages/en.ts`, `src/i18n/messages/de.ts`, shared `MessageKey` type derived from the English map; German must satisfy the same key set (TypeScript checks completeness).

**Rationale:** English as the canonical key source; compile-time gaps for German.

### 3. Preference storage

**Choice:** `localStorage` key (e.g. `perimedi.locale`) holding `en` | `de`. Not in Dexie export by default (language is a device UI preference). Optionally read on boot before first paint to avoid flash.

**Rationale:** Preference is UI chrome, not domain data; export/import of meds/periods should not clobber device language. Aligns with backup-and-sample “language-independent payload”.

**Alternatives considered:** Dexie settings table — workable but couples UI chrome to DB migrations and backup semantics.

### 4. Defaulting

**Choice:** If stored preference missing, inspect `navigator.languages` / `navigator.language` for a `de` prefix → German; else English.

### 5. Language switcher placement

**Choice:** Control inside **More** sheet (segmented control or two options: English / Deutsch), matching “settings-like” actions already there (backup).

### 6. date-fns locales

**Choice:** Use `date-fns/locale` (`enUS`, `de`) with a helper `formatLocalized(date, pattern)` bound to active locale. Calendar weekday headers and month titles go through this helper (or `Intl` with matching `en`/`de` BCP-47 tags).

### 7. HTML `lang`

**Choice:** Set `document.documentElement.lang` to `en` or `de` whenever the active language changes (and on initial boot).

### 8. Native `confirm` / `alert`

**Choice:** Prefer app-provided strings for confirmations that already use custom UI; where `window.confirm` remains, pass translated message text from `t()`. Browser button labels (“OK”/“Cancel”) stay browser-native—acceptable trade-off.

### 9. Coverage strategy

**Choice:** Replace hardcoded product strings component-by-component; keep domain enums (e.g. form types, remark kinds) mapped through `t()` for display labels only; store enum codes unchanged in IndexedDB.

## Risks / Trade-offs

- **[Missing translation gaps]** → Mitigate with TypeScript key parity and a quick UI pass in both languages before merge.
- **[Flash of wrong language on first paint]** → Read `localStorage` synchronously when creating the locale context initial state.
- **[Sample med names stay English-ish under German UI]** → Acceptable per specs; chrome is German; domain sample text is fixed demo data.
- **[String growth / drift]** → Keep messages colocated under `src/i18n/`; AGENTS note to add both languages when adding UI copy.

## Migration Plan

1. Add i18n core + English messages extracted from current UI (behavior unchanged when defaulting to en).
2. Add German messages and language switcher.
3. Wire date-fns locales and `document.documentElement.lang`.
4. Sweep components; run `npm run build`.
5. Manual check: switch en↔de, reload, calendar labels, sheets, backup confirms.

Rollback: remove i18n module and restore English literals (feature is additive chrome only; domain data unaffected).

## Open Questions

None that block implementation; if natural German phrasing for short actions (“+ Med”) needs product polish, translators can refine message files without design changes.
