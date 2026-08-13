/**
 * Cycle chart layout constants shared by CycleDiagram and tests.
 * Label column must be wide enough on SE (375) that short sample med names
 * (e.g. “Estradiol gel”) are mostly readable without mid-word ellipsis.
 */
/** Min day-column width; denser than finger-width so more of the cycle fits on SE. */
export const CYCLE_DAY_MIN_PX = 22
export const CYCLE_LABEL_COL_PX = 156
export const CYCLE_LABEL_PAD_LEFT_PX = 6
export const CYCLE_MED_RING_PX = 3

/** Minimum label column for SE readability of common short med names. */
export const CYCLE_LABEL_COL_MIN_SE = 140

/** Sticky dose meta sits just right of the sticky med label column in the scrollport. */
export const CYCLE_DOSE_META_STICKY_LEFT_PX = CYCLE_LABEL_COL_PX + 4

/** Max width for sticky dose/day meta so it does not cover the whole plot. */
export const CYCLE_DOSE_META_MAX_WIDTH_PX = 120

/** Selected-day column left edge as % of plot width only (0–100). */
export function selectedDayPlotLeftPct(
  selectedDay: number,
  cycleLen: number,
): number {
  if (cycleLen <= 0) return 0
  const day = Math.min(Math.max(selectedDay, 1), cycleLen)
  return ((day - 1) / cycleLen) * 100
}

/** Selected-day column center as % of plot width only (0–100). */
export function selectedDayPlotCenterPct(
  selectedDay: number,
  cycleLen: number,
): number {
  if (cycleLen <= 0) return 0
  const day = Math.min(Math.max(selectedDay, 1), cycleLen)
  return ((day - 0.5) / cycleLen) * 100
}

/** Selected-day column width as % of plot width only. */
export function selectedDayPlotWidthPct(cycleLen: number): number {
  if (cycleLen <= 0) return 0
  return (1 / cycleLen) * 100
}
