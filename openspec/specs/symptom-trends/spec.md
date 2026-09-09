# symptom-trends Specification

## Purpose

Give the user an in-app Trends chart (German: Verlauf) of symptom scores by cycle so she can see whether a symptom shows up more often and whether those days were worse. This is a picture between Effect’s one sentence and a future doctor PDF. It is not a daily squiggle, not a stats dashboard, and not medical advice.

## Requirements

### Requirement: Own Trends destination
The system SHALL present Trends as a primary bottom-navigation destination, not as a card on Cycle. Bottom destinations SHALL be Cycle, Month, Trends, and More in that order. The Trends label SHALL be “Trends” in English and “Verlauf” in German.

#### Scenario: Open Trends from the bottom bar
- **WHEN** the user activates Trends in the bottom navigation
- **THEN** the Trends chart screen is shown

#### Scenario: Chart is not on Cycle
- **WHEN** the user is on Cycle
- **THEN** the Trends chart is not embedded on that screen

### Requirement: Cycle-aligned chart windows
The system SHALL plot one point per **logged cycle**. A cycle SHALL be the first day of a logged period through the day before the next logged period start (the same windows as Effect). Predicted period starts SHALL NOT define chart cycles. The X-axis SHALL be those cycles, labeled by period-start date. The chart SHALL show the last several logged cycles that have any symptom scores (about six is enough; more if they fit). When those cycles do not fit the chart width, the plot SHALL scroll horizontally and keep the most recent cycles in view first. The current cycle SHALL end on today when no later logged period start exists.

#### Scenario: Same cycle bounds as Effect
- **WHEN** logged periods start on 1 February and 1 March and today is 15 March
- **THEN** the February cycle is 1 February through 28 February and the March cycle is 1 March through 15 March

#### Scenario: Predicted starts are not cycles
- **WHEN** a predicted period start falls between two logged period starts
- **THEN** that predicted start does not split or label a Trends cycle

#### Scenario: Extra cycles scroll
- **WHEN** more scored cycles are visible than fit the chart width
- **THEN** the user can pan the plot horizontally and the latest cycles are in view until they pan back

### Requirement: Count on Y, mean intensity as size
For each selected catalog symptom id, the system SHALL encode **Y as count** of days scored for that id in that cycle and **dot size as the mean intensity** (1–4) of those scores. Mean SHALL be used, not the raw sum of scores. Missing days and missing ids SHALL NOT be treated as 0. If that id has no scores in a cycle, the system SHALL omit the dot (a gap) and SHALL NOT plot a zero. For `hot_flash`, count SHALL be days scored until a separate episode log exists; the system SHALL NOT invent episode counts from 1–4 severity scores. A thin line SHALL connect consecutive dots of the same series and SHALL break across a gap. A single cycle SHALL show one point and no trend line.

#### Scenario: High-count mild versus low-count severe
- **WHEN** one cycle has eight days scored 1 for a symptom and a later cycle has two days scored 4 for the same symptom
- **THEN** the first point is higher on Y and smaller, and the second point is lower on Y and larger

#### Scenario: Gap is not a zero
- **WHEN** a selected symptom has scores in the first and third visible cycles and none in the second
- **THEN** the second cycle has no dot for that series (a gap), not a point at count 0

#### Scenario: Hot flush uses days scored
- **WHEN** `hot_flash` rows in a cycle include an optional episode-count field
- **THEN** the Y value is still the number of days scored that cycle, not those episode counts

#### Scenario: One cycle only
- **WHEN** only one logged cycle has scores for a selected symptom
- **THEN** Trends shows that one point and does not draw a trend line yet

#### Scenario: Axis and size are labeled
- **WHEN** Trends draws a chart
- **THEN** the Y axis is labeled as days scored and a short key says a bigger dot means stronger on those days

### Requirement: Chart first, catalog in a Change sheet
The system SHALL draw at most three symptom series. The default series SHALL be the three catalog ids logged on the most days in the visible span (not the highest mean). When a chart can be drawn, Trends SHALL show one chart card with nothing between the header and the plot: Y labeled as days scored, X as cycle start dates, then a stacked list of the selected names each with a color dot matching that line, a short size key, and a quiet Change control. The default view SHALL NOT show the full catalog, group titles, or copy that symptoms must be selected. Change SHALL open a sheet titled “Show on chart” (German: “Im Diagramm zeigen”) with every catalog symptom grouped the same way as the symptom log. Selecting a fourth SHALL replace the selected series with the fewest scored days so at most three remain. Done SHALL close the sheet and the chart SHALL update. Empty states SHALL hide Change and the catalog.

#### Scenario: Defaults follow day count
- **WHEN** four ids have scores in the visible span and their day counts differ
- **THEN** the three with the most scored days are selected, even if a fourth has a higher mean

#### Scenario: Select replaces one series
- **WHEN** three series are selected and the user selects a catalog id that is not among them in the Change sheet
- **THEN** that id becomes selected, the previously selected series with the fewest scored days becomes not selected, and at most three series remain

#### Scenario: Default chart has no chip cloud
- **WHEN** Trends can draw a chart
- **THEN** the card shows the plot, the three selected names stacked with matching color dots, a size key, and Change, and does not show group titles or a full catalog

#### Scenario: Empty hides selection
- **WHEN** Trends cannot draw a chart
- **THEN** Change and the catalog are not shown

### Requirement: Tap shows cycle numbers
Activating a dot SHALL show that symptom’s name, the cycle’s date range, the day count, and the mean intensity as numbers. The user-facing word for that intensity SHALL be “average” in English and “Mittel” in German. Copy SHALL be English and German according to the active language.

#### Scenario: Tap a point
- **WHEN** the user activates a plotted point
- **THEN** Trends shows which symptom the point belongs to, the cycle start and end dates, the count of days scored, and the mean intensity for that series and cycle

### Requirement: Dose-change ticks are context only
When a stored dose or schedule change has an effective date in a visible cycle, the system SHALL mark that cycle with a small tick on the plot, not a sentence under the chart. Activating the tick SHALL show the medication name snapshot and the new value. That mark SHALL NOT claim the change caused a symptom difference and SHALL NOT advise a treatment change. German copy SHALL use Hub for a pump unit; the medication name may stay as stored.

#### Scenario: Change in a visible cycle
- **WHEN** a stored dose change for a named medication is effective in a visible cycle
- **THEN** that cycle has a tick on the plot, and activating it shows the medication name and new dose without claiming the dose caused a change in symptoms

#### Scenario: Change outside the visible span
- **WHEN** the only stored change is effective before the first visible cycle
- **THEN** Trends does not mark a cycle for that change

### Requirement: Empty states without medical advice
The system SHALL show short English and German copy when Trends cannot draw a useful chart. With no logged period history, copy SHALL say that Trends needs at least two logged cycles. With logged cycles but no scores in the visible span, copy SHALL be equivalent to “No symptom scores in these cycles yet.” (German: “Noch keine Symptomwerte in diesen Zyklen.”) Trends SHALL NOT recommend changing a dose, starting or stopping HRT, or otherwise give medical advice in the chart or its copy. Period tracking off SHALL keep the Trends destination and show the same need-cycles copy.

#### Scenario: No period history
- **WHEN** no logged period start exists
- **THEN** Trends shows short copy that it needs at least two logged cycles, in the same full-width card as the chart, and does not draw axes with zero dots

#### Scenario: No scores in range
- **WHEN** at least one logged cycle exists and none of those cycles have symptom scores
- **THEN** Trends shows copy equivalent to “No symptom scores in these cycles yet.” in the same full-width card as the chart

#### Scenario: No treatment advice
- **WHEN** Trends is shown with or without scores
- **THEN** the chart and copy do not tell the user she should change a dose or start HRT

#### Scenario: Period tracking off
- **WHEN** period tracking is off
- **THEN** the Trends destination remains and shows the need-cycles copy instead of a chart
