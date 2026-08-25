import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react'
import { createPortal } from 'react-dom'
import { useT } from '../i18n'

export type ConfirmOptions = {
  title?: string
  message: string
  confirmLabel?: string
  danger?: boolean
}

type ConfirmFn = (options: ConfirmOptions) => Promise<boolean>

const ConfirmContext = createContext<ConfirmFn | null>(null)

export function ConfirmProvider({ children }: { children: ReactNode }) {
  const t = useT()
  const [open, setOpen] = useState(false)
  const [opts, setOpts] = useState<ConfirmOptions | null>(null)
  const resolver = useRef<((value: boolean) => void) | null>(null)

  const close = useCallback((value: boolean) => {
    resolver.current?.(value)
    resolver.current = null
    setOpen(false)
  }, [])

  const confirm = useCallback<ConfirmFn>((options) => {
    resolver.current?.(false)
    setOpts(options)
    setOpen(true)
    return new Promise<boolean>((resolve) => {
      resolver.current = resolve
    })
  }, [])

  const value = useMemo(() => confirm, [confirm])

  return (
    <ConfirmContext.Provider value={value}>
      {children}
      {open &&
        opts &&
        createPortal(
          <div className="fixed inset-0 z-[120] flex items-end justify-center px-3 pb-3 pt-6 sm:items-center sm:p-6">
            <button
              type="button"
              className="absolute inset-0 z-0 bg-ink/30 backdrop-blur-[2px]"
              aria-label={t('common.cancel')}
              onClick={() => close(false)}
            />
            <div
              role="alertdialog"
              aria-modal="true"
              aria-labelledby="confirm-title"
              aria-describedby="confirm-message"
              className="relative z-10 w-full max-w-sm rounded-3xl bg-cream p-4 shadow-2xl ring-1 ring-blush-100 sm:p-5"
            >
              <h2
                id="confirm-title"
                className="font-display text-xl font-semibold text-ink"
              >
                {opts.title ?? t('confirm.title')}
              </h2>
              <p id="confirm-message" className="mt-2 text-sm text-ink-soft">
                {opts.message}
              </p>
              <div className="mt-4 flex flex-wrap justify-end gap-2">
                <button
                  type="button"
                  className="btn-ghost"
                  onClick={() => close(false)}
                >
                  {t('common.cancel')}
                </button>
                <button
                  type="button"
                  className={opts.danger ? 'btn-soft' : 'btn-primary'}
                  onClick={() => close(true)}
                >
                  {opts.confirmLabel ?? t('common.delete')}
                </button>
              </div>
            </div>
          </div>,
          document.body,
        )}
    </ConfirmContext.Provider>
  )
}

export function useConfirm(): ConfirmFn {
  const ctx = useContext(ConfirmContext)
  if (!ctx) {
    throw new Error('useConfirm must be used within ConfirmProvider')
  }
  return ctx
}
