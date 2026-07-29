import type { ReactNode } from 'react'

export function Sheet({
  open,
  title,
  onClose,
  children,
  wide,
}: {
  open: boolean
  title: string
  onClose: () => void
  children: ReactNode
  wide?: boolean
}) {
  if (!open) return null

  return (
    <div className="fixed inset-0 z-[80] flex items-end justify-center sm:items-center sm:p-4">
      <button
        type="button"
        className="absolute inset-0 bg-ink/30 backdrop-blur-[2px]"
        aria-label="Close"
        onClick={onClose}
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className={`relative z-10 flex max-h-[92vh] w-full flex-col rounded-t-3xl bg-cream shadow-2xl ring-1 ring-blush-100 sm:rounded-3xl ${
          wide ? 'sm:max-w-xl' : 'sm:max-w-md'
        }`}
      >
        <div className="flex shrink-0 items-center justify-between border-b border-blush-100 px-4 py-3">
          <h2 className="font-display text-xl font-semibold text-ink">{title}</h2>
          <button
            type="button"
            onClick={onClose}
            className="flex h-9 w-9 items-center justify-center rounded-full bg-blush-50 text-lg text-blush-800 hover:bg-blush-100"
            aria-label="Close"
          >
            ×
          </button>
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto px-4 py-4">{children}</div>
      </div>
    </div>
  )
}
