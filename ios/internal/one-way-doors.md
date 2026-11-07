# One-way doors

These are the four content rules. The checker is `ios/scripts/check-one-way-door.py`. A match prints a notice and exits 0. It does not fail `ids`. A git or Python failure prints a `::warning::` line and still exits 0. The rules match text in the diff. They are not a list of paths. The checker skips this file, `ios/scripts/check-one-way-door.py`, and `ios/scripts/test_check_one_way_door.py` before it applies the rules. Those files quote the needles.

## SwiftData

This rule applies to any `.swift` file. An added or removed line that contains the token `@Model` is a door. An added or removed stored `var` line is also a door when the file text contains `@Model`. A stored `var` line is a `var` name after access modifiers and attributes, and the line has no `{`. `let` is not this door. A computed `var` whose line contains `{` is not this door.

## Backup v1

This rule applies when the diff text contains any of these names as a whole word: `ExportPayload`, `BackupCodec`, `Medication`, `Schedule`, `DoseLog`, `Remark`, `CycleSettings`, `Period`, `SymptomScore`, `MedicationChange`, `CustomSymptom`. A changed `version` literal is a door. `schemaVersion` is not that literal. A wire name that is present on the old side and absent on the new side is a door. A new wire name is a door unless its added declaration line shows `?` or `Optional<`. When the checker cannot tell, the reason contains `unknown`.

Every new ExportPayload key gets an import test for a v1 file that omits that key. Follow `testOldBackupWithoutCustomSymptomsDecodesEmpty`. A version-1 backup that omits the key decodes as empty. This list does not add that test.

## Widget snapshot

This rule applies when the diff text contains `DoseWidgetSnapshot`, `DoseWidgetChrome`, `DoseWidgetAck`, `next-dose.json`, or `appGroupId`. A changed `schemaVersion` is a door. An added, removed, or renamed `let` or `var` in those type bodies is a door, including a new optional. An added or removed line that contains `appGroupId` or `next-dose.json` is a door.

## Entitlements, privacy manifest, release and signing

An added or removed line in any file is a door when it contains one of these strings:

- `com.apple.developer`
- `com.apple.security.application-groups`
- `NSPrivacy`
- `CODE_SIGN`
- `DEVELOPMENT_TEAM`
- `PROVISIONING_PROFILE`
- `PRODUCT_BUNDLE_IDENTIFIER`
- `group.app.perimedi.ios`
- `iCloud.app.perimedi.ios`

`CODE_SIGN` also matches `CODE_SIGNING_ALLOWED`, because that name contains `CODE_SIGN`. Context lines do not count.
