## MODIFIED Requirements

### Requirement: More layout
The More screen SHALL present a Language block (English and German as selectable pills), a Reminders block with a master switch for dose reminders and a sound picker, a Doctor visit block with one action that generates a visit PDF and opens the share sheet, a Backup block whose rows (sample, export, import, clear) each have a trailing action, and a Privacy Policy control that opens the published privacy policy in the system browser.

#### Scenario: More sections
- **WHEN** the user opens More
- **THEN** language pills appear first, then the reminders switch, then the visit PDF action, then backup rows, then a Privacy Policy control, and each backup action sits on the trailing side of its row
