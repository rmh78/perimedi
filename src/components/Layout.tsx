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
        <header className="sticky top-0 z-40 overflow-hidden border-b border-blush-100/70 bg-cream pt-[env(safe-area-inset-top,0px)]">
          <div className="relative mx-auto h-[4.5rem] max-w-3xl sm:h-[5.75rem]">
            <img
              src="/brand/header.jpg?v=2"
              alt=""
              className="pointer-events-none absolute inset-0 h-full w-full object-cover object-center"
            />
            <h1 className="sr-only">PeriMedi</h1>
            <p className="sr-only">{t('layout.tagline')}</p>
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
