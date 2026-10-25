# App Store listing drafts

Tracked in [#30](https://github.com/rmh78/perimedi/issues/30). This folder holds the listing, `connect.md`, `privacy.md`, `screenshots/`, and `check-listing.py`.

## Before paid membership
- These drafts
- Privacy policy page (this folder)
- Nutrition-label and review-note answers
- Engineering checklist (privacy manifest, notification string, in-app privacy link, paid-team signing)

## After membership is active
- Create the App Store Connect record
- Paid-team signing and TestFlight
- Production iCloud container `iCloud.app.perimedi.ios`
- Screenshots (6.9" iPhone) and submit

Before a listing edit, run `python3 docs/app-store/check-listing.py`. That check also runs in CI (`ids`) and in local `control-perimedi verify`. Redo the 6.9" set with `bash docs/app-store/capture-store-shots.sh`. Do not add the capture script to `control-perimedi`.

## Product rules
- Category: **Health & Fitness**, not Medical
- Regulated medical device (EEA/UK/US): **No**
- Do not promise a second device. Optional iCloud uses the person's Apple ID, and the listing does not say the data appears on another phone.
- Effect stays observational. Never diagnose, treat, or titrate.
- In-app copy stays English and German. This folder is English except `listing-de.md`
