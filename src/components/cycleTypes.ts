import type { DayCycleInfo, Remark } from '../types'

export type DayColumn = {
  cycleDay: number
  dateKey: string | null
  info: DayCycleInfo | null
  isToday: boolean
  isSelected: boolean
  /** Logged or predicted period */
  isPeriod: boolean
  isLoggedPeriod: boolean
  symptoms: Remark[]
}

/** Binary adherence for the selected day: taken or not. */
export type TakenState = 'taken' | 'open' | null
