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
  if (v.glass) return "Shows the dose";
  return "Blank";
};

export const title = "One dose reminder";

export const state = (v) => ({
  Notification: notification(v),
  App: v.status === "taken" ? "Taken" : "Not taken",
  Widget: widget(v),
});

const sameLabels = (from, to) => {
  const before = state(from);
  const after = state(to);
  return (
    before.Notification === after.Notification &&
    before.App === after.App &&
    before.Widget === after.Widget
  );
};

export const step = (action, from, to) => {
  if (action === "Done") return null;
  if (action === "ReadSnap") return "the app reads the pending reminders";
  if (action === "Publish") return "the app writes the widget file";
  if (action === "Fire") {
    // A fire while the dose is still pending is not on a bug path.
    if (from.status !== "taken") return null;
    return "the reminder fires";
  }
  if (action === "NoteTake" || action === "CardTake" || action === "WidgetTake") {
    // A second take only queues another cancel. Labeling it drops the regions chart.
    if (from.status === "taken") return null;
  }
  if (action === "CommitPlan" || action === "Apply" || action === "Reload" || action === "FreshTap") {
    if (sameLabels(from, to)) return null;
  }
  if (action === "Apply") return from.q[1] === "A" ? "the queued add lands" : "the queued cancel lands";
  if (action === "CommitPlan") return "the app writes the reminder list";
  if (action === "NoteTake") return "you tap Taken on the notification";
  if (action === "CardTake") return "you tap Taken on the card";
  if (action === "FreshTap") return "you tap the dose";
  if (action === "WidgetTake") return "you tap Take on the widget";
  if (action === "Reload") return "the widget reloads";
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
