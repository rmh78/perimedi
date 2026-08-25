import { useEffect, useLayoutEffect, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { useT } from '../i18n'

const VIEWPORT_BASE =
  'width=device-width, initial-scale=1, viewport-fit=cover'
/** While a sheet is open, block iOS focus-zoom so padding stays and scale resets on close. */
const VIEWPORT_SHEET_OPEN =
  'width=device-width, initial-scale=1, maximum-scale=1, viewport-fit=cover'

function getViewportMeta(): HTMLMetaElement | null {
  return document.querySelector('meta[name="viewport"]')
}

export function Sheet({
  open,
  title,
  icon,
  iconAccent,
  onClose,
  children,
  wide,
}: {
  open: boolean
  title: string
  icon?: string
  iconAccent?: string
  onClose: () => void
  children: ReactNode
  wide?: boolean
}) {
  const t = useT()

  // Before paint: lock scale so autoFocus / field focus cannot zoom the page.
  useLayoutEffect(() => {
    if (!open) return
    const meta = getViewportMeta()
    if (!meta) return
    const previous = meta.getAttribute('content') ?? VIEWPORT_BASE
    meta.setAttribute('content', VIEWPORT_SHEET_OPEN)
    return () => {
      meta.setAttribute('content', previous)
      // Nudge iOS to re-apply the restored scale after focus is gone.
      const active = document.activeElement
      if (active instanceof HTMLElement) active.blur()
      // Re-assert base viewport next frame (some iOS versions keep zoom otherwise).
      requestAnimationFrame(() => {
        const m = getViewportMeta()
        if (m && m.getAttribute('content') === previous) {
          m.setAttribute('content', VIEWPORT_BASE)
        }
      })
    }
  }, [open])

  // Lock body scroll while open so the page doesn't shift under the modal
  useEffect(() => {
    if (!open) return
    const prevOverflow = document.body.style.overflow
    const prevTouch = document.body.style.touchAction
    document.body.style.overflow = 'hidden'
    document.body.style.touchAction = 'none'
    return () => {
      document.body.style.overflow = prevOverflow
      document.body.style.touchAction = prevTouch
      const active = document.activeElement
      if (active instanceof HTMLElement) active.blur()
    }
  }, [open])

  // Close on Escape
  useEffect(() => {
    if (!open) return
    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, onClose])

  if (!open) return null

  // Portal to body so parents with overflow/transform (e.g. glass cards)
  // cannot clip or trap the dialog.
  return createPortal(
    <div
      className="fixed inset-0 z-[100] flex items-end justify-center px-3 pb-3 pt-6 sm:items-center sm:p-6"
      style={{
        paddingBottom: 'max(0.75rem, env(safe-area-inset-bottom, 0px))',
        paddingLeft: 'max(0.75rem, env(safe-area-inset-left, 0px))',
        paddingRight: 'max(0.75rem, env(safe-area-inset-right, 0px))',
      }}
    >
      <button
        type="button"
        className="absolute inset-0 z-0 bg-ink/30 backdrop-blur-[2px]"
        aria-label={t('common.close')}
        onClick={onClose}
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className={`relative z-10 flex w-full max-h-[min(92dvh,92vh)] flex-col rounded-3xl bg-cream shadow-2xl ring-1 ring-blush-100 sm:max-h-[min(90dvh,90vh)] ${
          wide ? 'sm:max-w-xl' : 'sm:max-w-md'
        }`}
      >
        <div className="flex shrink-0 items-center justify-between gap-3 border-b border-blush-100 px-4 py-3 sm:px-5">
          <h2 className="font-display flex min-w-0 items-center gap-2.5 text-xl font-semibold text-ink">
            {icon ? (
              <span
                className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full p-[3px]"
                style={{ background: iconAccent || '#fff1f4' }}
              >
                <img
                  src={icon}
                  alt=""
                  className="h-full w-full rounded-full object-cover"
                  draggable={false}
                />
              </span>
            ) : null}
            <span className="min-w-0 truncate">{title}</span>
          </h2>
          <button
            type="button"
            onClick={onClose}
            className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-blush-50 text-xl leading-none text-blush-800 hover:bg-blush-100"
            aria-label={t('common.close')}
          >
            ×
          </button>
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto overscroll-contain px-4 py-3 sm:px-5 sm:py-4">
          {children}
        </div>
      </div>
    </div>,
    document.body,
  )
}
