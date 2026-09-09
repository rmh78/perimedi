## ADDED Requirements

### Requirement: Visit share control is identifiable
The More visit PDF action SHALL expose a language-independent accessibility identifier. The instrumented More journey SHALL wait for that control. Catalog pictures of More SHALL include the visit entry. Verification SHALL NOT paste screenshot galleries into pull-request comments.

#### Scenario: More journey finds the visit action
- **WHEN** the instrumented More journey opens More
- **THEN** the visit PDF action is uniquely identifiable without reading the visible title string

#### Scenario: More catalog includes the visit entry
- **WHEN** the committed More catalog pictures are written
- **THEN** the visit PDF entry is on those pictures
