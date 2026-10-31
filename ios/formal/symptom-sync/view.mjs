const on = (row, day) => Boolean(row && row[day]);

const dayGone = (v) =>
  v.view === "live" &&
  v.refreshed &&
  [1, 2].some((day) => {
    const owned = on(v.owned.a, day) || on(v.owned.b, day);
    const shown = on(v.shown.a, day) || on(v.shown.b, day);
    return owned && !shown;
  });

export const title = "Custom symptom sync on one phone";

export const state = (v) => {
  if (v.combined && v.memory !== "ba") return "Import joined two names and forgot the pair";
  if (dayGone(v)) return "A saved day is gone";
  if (v.view === "gap") return "The save failed and the list rolled back";
  if (v.phase === "split") return "The pairs are saved and the store save is still open";
  if (v.memory === "ba" && v.present.a && !v.present.b) return "One symptom remains, and the pair is remembered";
  if (v.present.a && v.present.b && v.nm.a === v.nm.b) return "Two phones added the same name";
  if (v.present.a || v.present.b) return "One custom symptom";
  return "No custom symptoms";
};

const labels = {
  Add: "you add a symptom",
  ArriveCustom: "the other phone adds a symptom",
  Rename: "you rename it",
  Delete: "you delete it",
  Log: "you log a day",
  ArriveEmpty: "a row arrives with no record id",
  SaveKey: "the phone saves the remembered pairs",
  Commit: "the store save lands",
  Rollback: "the store save fails",
  ImportCombined: "you import a backup that joined two names",
  ImportOrphan: "you import a backup that left a mark out",
  Wipe: "you clear this phone",
};

export const step = (action) => labels[action] ?? null;

export const group = (v) => {
  if (v.combined && v.memory !== "ba") return "Forgot";
  if (dayGone(v)) return "Lost";
  if (v.view === "gap" || v.phase === "split") return "Saving";
  return "Settled";
};

export const colors = {
  Forgot: "orange",
  Lost: "pink",
  Saving: "yellow",
  Settled: "teal",
};
