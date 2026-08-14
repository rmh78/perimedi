export type AppTab = 'cycle' | 'month' | 'more'

export const APP_TABS: readonly AppTab[] = ['cycle', 'month', 'more'] as const

/** Path prefix for each tab (no trailing slash except root). */
export const TAB_PATH: Record<AppTab, string> = {
  cycle: '/',
  month: '/month',
  more: '/more',
}

/**
 * Map a location pathname to the active bottom-nav tab.
 * Unknown paths fall back to cycle (app home).
 */
export function pathToTab(pathname: string): AppTab {
  const p = pathname.replace(/\/+$/, '') || '/'
  if (p === '/' || p === '/cycle' || p === '/today') return 'cycle'
  if (p === '/month') return 'month'
  if (p === '/more') return 'more'
  return 'cycle'
}

export function tabToPath(tab: AppTab): string {
  return TAB_PATH[tab]
}
