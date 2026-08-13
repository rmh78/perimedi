/** Shared line icons — nav and cycle actions use the same stroke language. */

const stroke = {
  fill: 'none' as const,
  stroke: 'currentColor',
  strokeWidth: 1.75,
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
}

export function IconCycle({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 20" className={className} aria-hidden>
      <path {...stroke} d="M4 10a6 6 0 1 0 1.7-4.2" />
      <path {...stroke} d="M4 4.5v3.2h3.2" />
    </svg>
  )
}

export function IconMonth({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 20" className={className} aria-hidden>
      <rect {...stroke} x="3.5" y="4.5" width="13" height="12" rx="1.5" />
      <path {...stroke} d="M3.5 8h13M7 3.5v3M13 3.5v3" />
    </svg>
  )
}

export function IconMore({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 20" className={className} aria-hidden>
      <circle cx="5.5" cy="10" r="1.15" fill="currentColor" />
      <circle cx="10" cy="10" r="1.15" fill="currentColor" />
      <circle cx="14.5" cy="10" r="1.15" fill="currentColor" />
    </svg>
  )
}

export function IconPlusMed({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 20" className={className} aria-hidden>
      <rect
        {...stroke}
        x="4"
        y="7.2"
        width="10.5"
        height="5.6"
        rx="2.8"
        transform="rotate(-32 9.25 10)"
      />
      <path {...stroke} d="M14.2 3.6v3.6M12.4 5.4h3.6" />
    </svg>
  )
}

export function IconDrop({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 20" className={className} aria-hidden>
      <path
        {...stroke}
        d="M10 3.4C10 3.4 5.6 8.6 5.6 12a4.4 4.4 0 0 0 8.8 0C14.4 8.6 10 3.4 10 3.4Z"
      />
    </svg>
  )
}

export function IconSparkPlus({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 20" className={className} aria-hidden>
      <path
        {...stroke}
        d="M8.6 3.4 9.5 6.8 13 7.6 9.5 8.4 8.6 11.8 7.7 8.4 4.2 7.6 7.7 6.8 8.6 3.4Z"
      />
      <path {...stroke} d="M14.2 11.6v4M12.2 13.6h4" />
    </svg>
  )
}

export function IconChevronLeft({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 20" className={className} aria-hidden>
      <path {...stroke} d="M12.5 4.5 7 10l5.5 5.5" />
    </svg>
  )
}

export function IconChevronRight({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 20" className={className} aria-hidden>
      <path {...stroke} d="M7.5 4.5 13 10l-5.5 5.5" />
    </svg>
  )
}
