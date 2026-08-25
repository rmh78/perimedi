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
        <header className="sticky top-0 z-20 bg-[#ffe4d6]">
          <div className="relative mx-auto aspect-[7/3] max-w-3xl">
            <img
              src="/brand/header.jpg?v=7"
              alt=""
              className="pointer-events-none absolute inset-0 h-full w-full object-contain object-center"
            />
            <div
              className="pointer-events-none absolute inset-0 bg-gradient-to-b from-transparent from-[74%] via-[#fff9f6]/75 via-[92%] to-[#fff9f6]"
              aria-hidden
            />
            <h1 className="sr-only">PeriMedi</h1>
            <p className="sr-only">{t('layout.tagline')}</p>
          </div>
        </header>

        <main className="relative z-30 mx-auto -mt-8 max-w-3xl overflow-x-clip px-3 pb-[calc(4.5rem+env(safe-area-inset-bottom,0px))] pt-2 sm:-mt-10 sm:px-6 sm:pt-3">
          <Outlet />
        </main>

        <BottomNav />
        </div>
      </ConfirmProvider>
    </SelectedDateProvider>
  )
}
