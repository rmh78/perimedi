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

## Review notes (for Apple)

PeriMedi has no login. Reviewers can use More → Load sample to see Cycle, medications, symptoms, and the Effect sentence. Language toggle is More → Deutsch / English. Reminders are local notifications. The app does not diagnose or recommend HRT changes. Declared not a regulated medical device.

Do not rely on iCloud for the review device. Sample data is enough.

## Screenshots (6.9\" iPhone, EN and DE)

1. Cycle with Effect sentence (sample data)
2. Medication sheet / dose reminder
3. Symptom scores
4. Month calendar
5. More (backup + language), no medical claims on captions

Captions must not say the app treats menopause or that HRT is working.

## Support URL

https://github.com/rmh78/perimedi/issues

## Privacy URL

Publish `privacy.md` (GitHub Pages on this repo, or any https URL). Then paste that URL in App Store Connect and link it from More in the app.
