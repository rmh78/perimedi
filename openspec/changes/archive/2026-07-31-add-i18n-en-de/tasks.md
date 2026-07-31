## 1. i18n core

- [x] 1.1 Add `src/i18n` module: locale type (`en` | `de`), message maps, `t(key, params?)`, and TypeScript key parity (German satisfies English keys)
- [x] 1.2 Implement `LocaleProvider` + `useLocale` / `useT` with initial locale from `localStorage` or browser default (`de` if preferred languages include German, else `en`)
- [x] 1.3 Persist locale to `localStorage` on change and set `document.documentElement.lang`
- [x] 1.4 Add `formatLocalized` (or equivalent) using `date-fns` locales `enUS` and `de`
- [x] 1.5 Wrap the app root with `LocaleProvider`

## 2. Message catalogs

- [x] 2.1 Extract current English product chrome into `messages/en.ts` (Home, sheets, legend, badges, confirms, validation)
- [x] 2.2 Author complete German `messages/de.ts` for the same keys (short UI style)
- [x] 2.3 Map display labels for form types, remark kinds, schedule modes, and dose status through `t()` without changing stored enum codes

## 3. Language control

- [x] 3.1 Add English / Deutsch language control in More sheet
- [x] 3.2 Verify switch updates chrome immediately and survives reload

## 4. Wire components

- [x] 4.1 Localize `HomePage` hero, day card actions, and related labels
- [x] 4.2 Localize `EditMedicationSheet`, `DayNoteSheet`, `PeriodSettingsSheet`, `MoreSheet`, `Sheet` a11y labels
- [x] 4.3 Localize `CycleDiagram` legend/labels, `CycleBadge`, `Legend`, and calendar chrome (weekday/month via locale helper)
- [x] 4.4 Localize backup/sample/import/export/clear confirms and status messages

## 5. Verify

- [x] 5.1 Manual pass: en and de for Home, med edit, period settings, symptom, More/backup; confirm user-entered text is not rewritten on language switch
- [x] 5.2 Run `npm run build` successfully
- [x] 5.3 Run `openspec validate --specs --strict` for the change when practical; keep AGENTS/README notes only if needed for i18n contributor guidance
