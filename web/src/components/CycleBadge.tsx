import type { DayCycleInfo } from '../types'

export function cycleDayClass(info: DayCycleInfo): string {
  if (info.isLoggedPeriod) return 'bg-blush-100 ring-blush-200'
  if (info.isPredictedPeriod) return 'bg-blush-50 ring-blush-100'
  return 'bg-white/70 ring-blush-100/80'
}
