const queued = (q) => q[1] !== undefined;

const notification = (v) => {
  if (v.status === "taken" && v.live === "pending") return "Taken, and the reminder is still waiting";
  if (v.live === "pending") return "Reminder is waiting";
  if (queued(v.q)) return "A change is queued";
  return "No reminder";
};

const widget = (v) => {
  if (v.status === "taken" && v.glass && v.suite) return "Taken, and the reloaded file still lists it";
  if (v.status === "taken" && v.glass) return "Taken, and the widget has not reloaded";
  if (v.glass) return "Widget shows the dose";
  return "Widget is blank";
};

export const title = "One dose reminder";

export const state = (v) => ({
  Notification: notification(v),
  App: v.status === "taken" ? "Taken" : "Not taken",
  Widget: widget(v),
});

export const step = (action, from) => {
  if (action === "Done") return null;
  if (action === "Apply") {
    return from.q[1] === "A" ? "the queued add lands" : "the queued cancel lands";
  }
  if (action === "ReadSnap") return "the app reads the pending reminders";
  if (action === "CommitPlan") return "the app writes the reminder list";
  if (action === "NoteTake") return "you tap Taken on the notification";
  if (action === "CardTake") return "you tap Taken on the card";
  if (action === "FreshTap") return "you tap the dose";
  if (action === "WidgetTake") return "you tap Take on the widget";
  if (action === "Publish") return "the app writes the widget file";
  if (action === "Reload") return "the widget reloads";
  if (action === "Fire") return "the reminder fires";
  return null;
};

export const group = (v) => {
  if (v.status === "taken" && v.live === "pending") return "Still waiting";
  if (v.status === "taken" && v.glass) return "Stale widget";
  return "Quiet";
};

export const colors = {
  "Still waiting": "pink",
  "Stale widget": "orange",
  Quiet: "teal",
};
