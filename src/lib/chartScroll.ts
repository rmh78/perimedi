/**
 * Compute horizontal scrollLeft to center a cycle day in the visible plot
 * (viewport minus sticky label column). Pure — used by CycleDiagram and tests.
 *
 * @returns scrollLeft, or null when layout is not ready for a reliable scroll
 */
export function computeDayScrollLeft(args: {
  cycleDay: number
  cycleLen: number
  labelColPx: number
  dayMinPx: number
  clientWidth: number
  /** Measured scroll/content width */
  contentWidth: number
  /** Designed min width of the full chart row (labels + days) */
  chartMinWidth: number
}): number | null {
  const {
    cycleDay,
    cycleLen,
    labelColPx,
    dayMinPx,
    clientWidth,
    contentWidth,
    chartMinWidth,
  } = args

  if (cycleLen <= 0 || clientWidth <= 0 || cycleDay < 1 || cycleDay > cycleLen) {
    return null
  }

  // Expected overflow but content still not expanded → not ready (Firefox first paint)
  if (chartMinWidth > clientWidth + 1 && contentWidth <= clientWidth + 1) {
    return null
  }

  const totalWidth = Math.max(contentWidth, chartMinWidth)
  const plotWidth = Math.max(totalWidth - labelColPx, cycleLen * dayMinPx)
  const colWidth = plotWidth / cycleLen
  const dayCenterX = labelColPx + (cycleDay - 0.5) * colWidth
  const visiblePlotCenterX =
    labelColPx + Math.max(clientWidth - labelColPx, 0) / 2
  const maxScroll = Math.max(0, totalWidth - clientWidth)
  return Math.max(0, Math.min(dayCenterX - visiblePlotCenterX, maxScroll))
}
