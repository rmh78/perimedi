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

/**
 * Clamp a day-badge center X so the full badge stays inside the plot band.
 * Used for first/last visible days where translateX(-50%) would clip the chip.
 */
export function clampBadgeCenterPx(
  dayCenterPx: number,
  plotWidthPx: number,
  badgeWidthPx: number,
  padPx = 4,
): number {
  if (plotWidthPx <= 0) return 0
  const half = Math.max(badgeWidthPx, 0) / 2
  const min = half + padPx
  const max = Math.max(min, plotWidthPx - half - padPx)
  return Math.min(Math.max(dayCenterPx, min), max)
}

/**
 * Day-badge center in plot-local px.
 * While any part of the selection column is still in the visible plot, clamp so
 * the chip stays readable at the edges. Once the selection is fully scrolled
 * away, return the natural day center so the title scrolls out with it.
 */
export function badgeCenterForSelectionVisibility(args: {
  dayCenterPx: number
  dayLeftPx: number
  dayRightPx: number
  /** Left edge of visible plot (plot-local). */
  visLeftPx: number
  /** Right edge of visible plot (plot-local). */
  visRightPx: number
  badgeWidthPx: number
  padPx?: number
}): number {
  const {
    dayCenterPx,
    dayLeftPx,
    dayRightPx,
    visLeftPx,
    visRightPx,
    badgeWidthPx,
    padPx = 4,
  } = args
  const visWidth = visRightPx - visLeftPx
  if (visWidth <= 0) return dayCenterPx

  const selectionVisible = dayRightPx > visLeftPx && dayLeftPx < visRightPx
  if (!selectionVisible) return dayCenterPx

  const centerInVisible = dayCenterPx - visLeftPx
  return (
    visLeftPx + clampBadgeCenterPx(centerInVisible, visWidth, badgeWidthPx, padPx)
  )
}

/**
 * CSS left % for the day badge (with translateX(-50%)), clamped so the chip
 * stays inside the plot. `badgeWidthFrac` is badge width as a fraction of plot
 * width when pixel measure is unavailable (fallback ~0.42 covers long DE labels).
 */
export function selectedDayBadgeStyle(
  selectedDay: number,
  cycleLen: number,
  badgeWidthFrac = 0.42,
): { leftPct: number; transform: string } {
  const center = selectedDayPlotCenterPct(selectedDay, cycleLen)
  const halfPct = (Math.min(Math.max(badgeWidthFrac, 0.1), 0.9) * 100) / 2
  const clamped = Math.min(Math.max(center, halfPct), 100 - halfPct)
  return { leftPct: clamped, transform: 'translateX(-50%)' }
}
