import { Outlet } from 'react-router-dom'
import { useT } from '../i18n'
import { BottomNav } from './BottomNav'
import { SelectedDateProvider } from '../context/SelectedDateContext'

export function Layout() {
  const t = useT()

  return (
    <SelectedDateProvider>
      <div className="min-h-dvh min-h-screen text-ink">
        <header className="sticky top-0 z-40 overflow-hidden border-b border-blush-100/70 bg-cream/90 backdrop-blur-md">
          <div className="pointer-events-none absolute inset-0 bg-gradient-to-br from-blush-200/50 via-white/30 to-lilac-100/50" />
          <div className="relative mx-auto max-w-3xl px-3 pb-2 pt-[max(0.75rem,env(safe-area-inset-top))] sm:px-6 sm:pb-3 sm:pt-4">
            <p className="text-[10px] font-semibold uppercase tracking-[0.22em] text-blush-700">
              {t('layout.tagline')}
            </p>
            <h1 className="font-display mt-0.5 text-[1.65rem] font-semibold leading-tight tracking-tight text-blush-900 sm:text-4xl">
              PeriMedi
            </h1>
          </div>
        </header>

        <main className="mx-auto max-w-3xl overflow-x-clip px-3 pb-[calc(4.5rem+env(safe-area-inset-bottom,0px))] pt-2 sm:px-6 sm:pt-3">
          <Outlet />
        </main>

        <BottomNav />
      </div>
    </SelectedDateProvider>
  )
}
