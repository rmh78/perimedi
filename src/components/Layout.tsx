import { Outlet } from 'react-router-dom'
import { useT } from '../i18n'
import { BottomNav } from './BottomNav'
import { SelectedDateProvider } from '../context/SelectedDateContext'

export function Layout() {
  const t = useT()

  return (
    <SelectedDateProvider>
      <div className="min-h-dvh min-h-screen text-ink">
        <header className="relative overflow-hidden">
          <div className="pointer-events-none absolute inset-0 bg-gradient-to-br from-blush-200/70 via-white/40 to-lilac-100/80" />
          <div className="relative mx-auto max-w-3xl px-3 pb-2 pt-[max(0.75rem,env(safe-area-inset-top))] sm:px-6 sm:pb-3 sm:pt-6">
            <p className="text-[10px] font-semibold uppercase tracking-[0.22em] text-blush-700">
              {t('layout.tagline')}
            </p>
            <h1 className="font-display mt-0.5 text-[1.65rem] font-semibold leading-tight tracking-tight text-blush-900 sm:text-4xl">
              PeriMedi
            </h1>
          </div>
        </header>

        <main className="mx-auto max-w-3xl overflow-x-clip px-3 pb-[calc(4.5rem+env(safe-area-inset-bottom,0px))] pt-1 sm:px-6 sm:pt-2">
          <Outlet />
        </main>

        <BottomNav />
      </div>
    </SelectedDateProvider>
  )
}
