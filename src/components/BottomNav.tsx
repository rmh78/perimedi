import { Link, useLocation } from 'react-router-dom'
import { useT } from '../i18n'
import { APP_TABS, pathToTab, tabToPath, type AppTab } from '../lib/nav'
import type { MessageKey } from '../i18n'

const TAB_LABEL: Record<AppTab, MessageKey> = {
  cycle: 'nav.cycle',
  month: 'nav.month',
  more: 'nav.more',
}

const TAB_ICON: Record<AppTab, string> = {
  cycle: '▦',
  month: '▤',
  more: '⋯',
}

export function BottomNav() {
  const t = useT()
  const { pathname } = useLocation()
  const active = pathToTab(pathname)

  return (
    <nav
      className="fixed inset-x-0 bottom-0 z-50 border-t border-blush-100 bg-cream/95 backdrop-blur-md"
      style={{ paddingBottom: 'env(safe-area-inset-bottom, 0px)' }}
      aria-label={t('nav.aria')}
    >
      <div className="mx-auto flex max-w-3xl items-stretch justify-around px-1 pt-1">
        {APP_TABS.map((tab) => {
          const isActive = active === tab
          return (
            <Link
              key={tab}
              to={tabToPath(tab)}
              aria-current={isActive ? 'page' : undefined}
              className={`flex min-h-12 min-w-0 flex-1 flex-col items-center justify-center gap-0.5 rounded-xl px-1 py-1.5 text-[10px] font-semibold transition ${
                isActive
                  ? 'bg-blush-100 text-blush-800'
                  : 'text-ink-muted hover:bg-blush-50 hover:text-blush-700'
              }`}
            >
              <span className="text-base leading-none" aria-hidden>
                {TAB_ICON[tab]}
              </span>
              <span className="truncate">{t(TAB_LABEL[tab])}</span>
            </Link>
          )
        })}
      </div>
    </nav>
  )
}
