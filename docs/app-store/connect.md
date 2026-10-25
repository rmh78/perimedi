# App Store Connect answers

Use with [#30](https://github.com/rmh78/perimedi/issues/30).

## App Privacy (nutrition labels)

Declare **Health & Fitness** data used for **App Functionality**:

- Other Health Data: symptom scores, periods, medications, dose logs, dose/schedule change history, optional notes

Linked to the user: **Yes** if iCloud is on (Apple ID). Not used for tracking. Not used for third-party advertising. Not used for analytics (we have none).

Do **not** declare Contact Info, Location, Diagnostics, Identifiers, Purchases, Browsing, unless we later add them.

Crash reporting: none today. If we add it later, update labels and this policy.

User export is user-initiated sharing, not collection by us.

## Age rating

- Medical or Treatment Information: **Frequent** (HRT tracker). That requires the regulated-medical-device declaration. Answer **No**, not a device.
- Unrestricted web access: No
- Gambling, alcohol, tobacco, drugs, violence, sexual content, profanity, horror, guns: No

Expected band: 12+ (confirm in the questionnaire; do not fake a 4+).

Connect is already 16+. Do not lower it.

## Review notes (for Apple)

PeriMedi has no login. From More, choose Load sample. That shows Cycle with the comparison sentence, Trends, Month, the symptom sheet (including New symptom), and the visit PDF. Language is More, Deutsch or English. The Home Screen widget is not required for review. Do not rely on iCloud on the review device. The app does not diagnose or recommend a medication change. It is not a regulated medical device.

## Screenshots (6.9" iPhone, EN and DE)

The shots are full-bleed app frames from sample data on iPhone 18 Pro Max, with today pinned to 2026-03-15. Each file is 1320×2868, or 1290×2796. There are no caption strings in the repo. Captions must not say the app treats menopause or that HRT is working.

English files are in `docs/app-store/screenshots/en/`. German files are in `docs/app-store/screenshots/de/`.

1. `01-cycle.png`. Sample Cycle, with the effect sentence visible and no sheet.
2. `02-trends.png`. Sample Trends chart, with one symptom dot selected and its detail line visible.
3. `03-symptoms.png`. Sample symptom sheet, scrolled so New symptom or Neues Symptom is visible.
4. `04-visit.png`. Visit PDF preview, with the share control present. Sample medications show taken counts from the logged history.
5. `05-month.png`. Sample Month.
6. `06-more.png`. More, ending above the tab bar with the privacy link and the full disclaimer visible.

## Support URL

https://github.com/rmh78/perimedi/issues

## Privacy URL

Publish `privacy.md` (GitHub Pages on this repo, or any https URL). Then paste that URL in App Store Connect and link it from More in the app.
