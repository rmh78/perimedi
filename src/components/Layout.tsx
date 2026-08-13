import { Outlet } from 'react-router-dom'
import { useT } from '../i18n'
import { BottomNav } from './BottomNav'
import { SelectedDateProvider } from '../context/SelectedDateContext'
import { ConfirmProvider } from '../context/ConfirmContext'

export function Layout() {
  const t = useT()

  return (
    <SelectedDateProvider>
      <ConfirmProvider>
        <div className="min-h-dvh min-h-screen text-ink">
        <header className="sticky top-0 z-40 overflow-hidden border-b border-blush-100/70 bg-cream/90 backdrop-blur-md">
          <div className="pointer-events-none absolute inset-0 bg-gradient-to-br from-blush-200/50 via-white/30 to-lilac-100/50" />
          <div className="relative mx-auto max-w-3xl px-3 pb-1.5 pt-[max(0.5rem,env(safe-area-inset-top))] sm:px-6 sm:pb-2.5 sm:pt-3">
            <p className="hidden text-[10px] font-semibold uppercase tracking-[0.22em] text-blush-700 sm:block">
              {t('layout.tagline')}
            </p>
            <h1 className="font-display text-[1.35rem] font-semibold leading-tight tracking-tight text-blush-900 sm:mt-0.5 sm:text-3xl">
              PeriMedi
            </h1>
          </div>
        </header>

        <main className="mx-auto max-w-3xl overflow-x-clip px-3 pb-[calc(4.5rem+env(safe-area-inset-bottom,0px))] pt-2 sm:px-6 sm:pt-3">
          <Outlet />
        </main>

        <BottomNav />
        </div>
      </ConfirmProvider>
    </SelectedDateProvider>
  )
}
