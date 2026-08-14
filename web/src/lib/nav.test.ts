import { describe, expect, it } from 'vitest'
import { pathToTab, tabToPath, APP_TABS } from './nav'

describe('pathToTab', () => {
  it('maps root, /cycle, and legacy /today to cycle', () => {
    expect(pathToTab('/')).toBe('cycle')
    expect(pathToTab('/cycle')).toBe('cycle')
    expect(pathToTab('/cycle/')).toBe('cycle')
    expect(pathToTab('/today')).toBe('cycle')
  })

  it('maps month and more paths', () => {
    expect(pathToTab('/month')).toBe('month')
    expect(pathToTab('/more')).toBe('more')
  })

  it('falls back unknown paths to cycle', () => {
    expect(pathToTab('/unknown')).toBe('cycle')
    expect(pathToTab('/foo/bar')).toBe('cycle')
  })
})

describe('tabToPath', () => {
  it('round-trips every tab through pathToTab', () => {
    for (const tab of APP_TABS) {
      expect(pathToTab(tabToPath(tab))).toBe(tab)
    }
  })

  it('uses / for cycle so bottom-nav active state matches index route', () => {
    expect(tabToPath('cycle')).toBe('/')
    expect(APP_TABS).not.toContain('today' as never)
  })
})
