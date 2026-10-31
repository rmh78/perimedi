# Dose reminder

```mermaid
---
title: "One dose reminder"
---
stateDiagram-v2
  direction LR
  state "Legend" as legend {
    lg0: Still waiting
    lg1: Quiet
    lg2: Breaks TakenNotPending or WidgetHidesTaken
    lg3: Path to the TakenNotPending or WidgetHidesTaken bug
  }
  class lg0 pink
  class lg1 teal
  class lg2 breaks
  class lg3 bugPath
  state "At the same time" as all {
    state "Notification" as r0 {
      s0: No reminder
      s1: A change is queued
      s2: Reminder is waiting
      s3: Taken, and the reminder is still waiting
      [*] --> s0
      s0 --> s1: you tap Taken on the card or you tap Taken on the notification or you tap Take on the widget [when App is Not taken and Widget is one of Blank, Shows the dose]
      s1 --> s0: the queued cancel lands
      s0 --> s1: the app writes the reminder list
      s1 --> s2: the queued add lands [when App is Not taken and Widget is one of Blank, Shows the dose]
      s1 --> s3: the queued add lands [when App is Taken and Widget is not Shows the dose]
      s2 --> s3: you tap Taken on the card or you tap Taken on the notification or you tap Take on the widget or you tap the dose
      s3 --> s1: the reminder fires or the queued cancel lands
      s3 --> s0: the queued cancel lands or the reminder fires
      s3 --> s2: you tap the dose
      s2 --> s1: the queued cancel lands
      s2 --> s0: the queued cancel lands
    }
    --
    state "App" as r1 {
      s4: Not taken
      s5: Taken
      [*] --> s4
      s4 --> s5: you tap Taken on the card or you tap Taken on the notification or you tap Take on the widget or you tap the dose
      s5 --> s4: you tap the dose
    }
    --
    state "Widget" as r2 {
      s6: Blank
      s7: Shows the dose
      s8: Taken, and the widget has not reloaded
      s9: Taken, and the reloaded file still lists it
      [*] --> s6
      s6 --> s7: the widget reloads [when Notification is not Taken, and the reminder is still waiting and App is Not taken]
      s6 --> s9: the widget reloads [when Notification is not Reminder is waiting and App is Taken]
      s7 --> s8: you tap Taken on the card or you tap Taken on the notification or you tap Take on the widget or you tap the dose
      s7 --> s9: you tap Taken on the card or you tap Taken on the notification or you tap Take on the widget or you tap the dose
      s8 --> s6: the widget reloads
      s8 --> s7: you tap the dose
      s9 --> s8: the app writes the widget file
      s9 --> s7: you tap the dose
      s7 --> s6: the widget reloads
    }
  }
  classDef breaks fill:#ffecee,stroke:#e72e3b,stroke-width:2.5px,color:#cd2834
  class s0 bugPath
  class s1 bugPath
  class s2 teal
  class s2 bugPath
  class s3 pink
  class s3 breaks
  class s3 bugPath
  class s4 teal
  class s4 bugPath
  class s5 bugPath
  class s6 bugPath
  class s7 teal
  class s8 breaks
  class s9 breaks
  class s9 bugPath
```

`WidgetHidesTaken` breaks. A taken dose is not on the widget. The shortest path has 3 steps: the app writes the widget file, you tap Taken on the card, and the widget reloads onto a file that still lists the dose.

`TakenNotPending` breaks. A taken dose leaves no reminder that can still fire. The shortest path has 4 steps: the app reads the pending reminders, the app writes the reminder list, the queued add lands, and you tap Taken on the card while that reminder is still waiting.

`WritersAgree` holds. TLC found none. The dose log stays pending or taken.

The chart hides a take that starts from a dose already taken, a fire while the dose is not taken, and a step that stays on the same labels. It keeps the label on the pending-reminder read and on the widget-file write, because those steps sit on a bug path even when the labels do not change.

The model uses one `live` bit, so it cannot show a follow-up or a snooze beside the dose id, and it cannot show snooze leaving the dose id in place. It leaves out the master switch, a denied authorization, a second `reschedule`, a second dose log, tomorrow's frozen `nextMeds`, and the follow-up schedule in `ReminderLogic.followUpPlan`. The queue keeps the last two ops.

Regenerate with `/statechart` on `ios/formal/dose-reminder/DoseReminder.tla`, using `ios/formal/dose-reminder/DoseReminder.cfg` and `ios/formal/dose-reminder/view.mjs`, into an empty directory. `ios/scripts/check-statecharts.py` checks the fence.
