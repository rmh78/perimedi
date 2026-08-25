export function HistoryIconButton({
  kind,
  label,
  onClick,
}: {
  kind: 'edit' | 'delete'
  label: string
  onClick: () => void
}) {
  const edit = kind === 'edit'
  return (
    <button
      type="button"
      className={`flex h-9 w-9 items-center justify-center rounded-full bg-blush-50 text-sm font-semibold ${
        edit ? 'text-blush-700' : 'text-blush-800'
      }`}
      aria-label={label}
      onClick={onClick}
    >
      {edit ? (
        <svg viewBox="0 0 20 20" className="h-4 w-4 fill-current" aria-hidden>
          <path d="M13.6 2.3a1 1 0 0 1 1.4 0l2.7 2.7a1 1 0 0 1 0 1.4L8.4 15.7 4 17l1.3-4.4L13.6 2.3zM12 4.8 5.9 10.9l-.5 1.7 1.7-.5L13.2 6 12 4.8z" />
        </svg>
      ) : (
        <svg viewBox="0 0 20 20" className="h-4 w-4 fill-current" aria-hidden>
          <path d="M7 2h6l.8 1H17v2H3V3h3.2L7 2zm1 5h2v8H8V7zm4 0h2v8h-2V7zM5 5h10l-.7 12.1A2 2 0 0 1 12.3 19H7.7a2 2 0 0 1-2-1.9L5 5z" />
        </svg>
      )}
    </button>
  )
}
