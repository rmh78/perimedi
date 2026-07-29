import { useState } from 'react'
import { Outlet } from 'react-router-dom'
import { MoreSheet } from './MoreSheet'

export function Layout() {
  const [moreOpen, setMoreOpen] = useState(false)

  return (
    <div className="min-h-screen text-ink">
      <header className="relative overflow-hidden">
        <div className="pointer-events-none absolute inset-0 bg-gradient-to-br from-blush-200/70 via-white/40 to-lilac-100/80" />
        <div className="pointer-events-none absolute -right-16 -top-20 h-56 w-56 rounded-full bg-blush-300/30 blur-3xl" />
        <div className="pointer-events-none absolute -left-10 bottom-0 h-40 w-40 rounded-full bg-lilac-200/40 blur-3xl" />

        <div className="relative mx-auto max-w-3xl px-4 pb-4 pt-8 sm:px-6">
          <div className="flex items-start justify-between gap-4">
            <div className="min-w-0">
              <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-blush-700">
                Perimenopause support
              </p>
              <h1 className="font-display mt-1 text-4xl font-semibold tracking-tight text-blush-900 sm:text-5xl">
                PeriMedi
              </h1>
              <p className="mt-2 max-w-md text-sm leading-relaxed text-ink-soft">
                Medications, cycles, and symptoms for perimenopause — all on this
                page. Data stays only in this browser.
              </p>
            </div>

            <button
              type="button"
              onClick={() => setMoreOpen(true)}
              className="btn-ghost shrink-0 !px-3.5 !py-2 text-xs shadow-sm"
            >
              ⋯ More
            </button>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-3xl px-4 pb-20 pt-2 sm:px-6">
        <Outlet />
      </main>

      <MoreSheet open={moreOpen} onClose={() => setMoreOpen(false)} />
    </div>
  )
}
