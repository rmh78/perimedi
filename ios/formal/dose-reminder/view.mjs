const visible = (v) => {
  const n = Object.keys(v.rows).length;
  return n === 0 ? "pending" : v.rows[n].status;
};

const queued = (q) => q[1] !== undefined;

const notification = (v) => {
  if (visible(v) === "taken" && v.live === "pending") return "Taken, and the reminder is still waiting";
  if (v.live === "pending") return "Reminder is waiting";
  if (queued(v.q)) return "A change is queued";
  return "No reminder";
};

const widget = (v) => {
  if (visible(v) === "taken" && v.glass && v.suite) return "Taken, and the reloaded file still lists it";
  if (visible(v) === "taken" && v.glass) return "Taken, and the widget has not reloaded";
  if (v.glass) return "Shows the dose";
  return "Blank";
};

export const title = "One dose reminder";

const app = (v) => {
  const name = visible(v) === "taken" ? "Taken" : "Not taken";
  return Object.keys(v.rows).length > 1 ? `${name}, and a second log is there` : name;
};

export const state = (v) => ({
  Notification: notification(v),
  App: app(v),
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
  if (action === "Publish") return "the app writes the widget file";
  if (action === "FreshTapRead") return "the dose button keeps the log it showed";
  if (action === "FreshTapWrite") return "you tap the dose";
  if (action === "Fire") {
    if (visible(from) !== "taken") return null;
    return "the reminder fires";
  }
  if (action === "NoteTake" || action === "CardTake" || action === "WidgetTake") {
    if (visible(from) === "taken") return null;
  }
  if (action === "Apply" || action === "Reload") {
    if (sameLabels(from, to)) return null;
  }
  if (action === "Apply") return from.q[1] === "A" ? "the queued add lands" : "the queued cancel lands";
  if (action === "CommitPlan") return "the app writes the reminder list";
  if (action === "NoteTake") return "you tap Taken on the notification";
  if (action === "CardTake") return "you tap Taken on the card";
  if (action === "WidgetTake") return "you tap Take on the widget";
  if (action === "Reload") return "the widget reloads";
  return null;
};

export const group = (v) => {
  if (Object.keys(v.rows).length > 1) return "Two logs";
  if (visible(v) === "taken" && v.live === "pending") return "Still waiting";
  if (visible(v) === "taken" && v.glass) return "Stale widget";
  return "Quiet";
};

export const colors = {
  "Two logs": "purple",
  "Still waiting": "pink",
  "Stale widget": "orange",
  Quiet: "teal",
};
