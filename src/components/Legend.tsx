export function CalendarLegend() {
  return (
    <div className="flex flex-wrap gap-x-4 gap-y-2 text-xs text-ink-soft">
      <span className="inline-flex items-center gap-1.5">
        <span className="h-2.5 w-2.5 rounded-full bg-rose-500" /> Period
      </span>
      <span className="inline-flex items-center gap-1.5">
        <span className="h-2.5 w-2.5 rounded-full bg-rose-300" /> Predicted
      </span>
      <span className="inline-flex items-center gap-1.5">
        <span className="h-2.5 w-2.5 rounded-full bg-violet-400" /> Symptom
      </span>
      <span className="inline-flex items-center gap-1.5">
        <span className="h-2.5 w-2.5 rounded-full bg-[var(--color-taken)]" /> Taken
      </span>
      <span className="inline-flex items-center gap-1.5">
        <span className="h-2.5 w-2.5 rounded-full bg-[var(--color-pending)]" /> Not taken
      </span>
    </div>
  )
}
