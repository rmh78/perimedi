import { IconChevronLeft, IconChevronRight } from './Icons'

type Props = {
  label: string
  todayLabel: string
  prevLabel: string
  nextLabel: string
  onToday: () => void
  onPrev: () => void
  onNext: () => void
  canPrev?: boolean
  canNext?: boolean
}

export function PagerRow({
  label,
  todayLabel,
  prevLabel,
  nextLabel,
  onToday,
  onPrev,
  onNext,
  canPrev = true,
  canNext = true,
}: Props) {
  return (
    <div className="flex min-w-0 items-center gap-0.5">
      <button
        type="button"
        className="btn-ghost !min-h-9 shrink-0 !px-2.5 !py-1.5 text-xs"
        onClick={onToday}
      >
        {todayLabel}
      </button>
      <button
        type="button"
        className="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-blush-700 transition hover:bg-blush-100 disabled:pointer-events-none disabled:opacity-35"
        aria-label={prevLabel}
        title={prevLabel}
        disabled={!canPrev}
        onClick={onPrev}
      >
        <IconChevronLeft />
      </button>
      <button
        type="button"
        className="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-blush-700 transition hover:bg-blush-100 disabled:pointer-events-none disabled:opacity-35"
        aria-label={nextLabel}
        title={nextLabel}
        disabled={!canNext}
        onClick={onNext}
      >
        <IconChevronRight />
      </button>
      <p className="min-w-0 flex-1 truncate text-sm font-semibold text-ink">
        {label}
      </p>
    </div>
  )
}
