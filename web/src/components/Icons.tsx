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
        x="3.2"
        y="6.6"
        width="13.6"
        height="6.8"
        rx="3.4"
        transform="rotate(-32 10 10)"
      />
    </svg>
  )
}

export function IconDrop({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 20" className={className} aria-hidden>
      <path
        {...stroke}
        d="M10 2.2C10 2.2 4.8 8.4 4.8 12.2a5.2 5.2 0 0 0 10.4 0C15.2 8.4 10 2.2 10 2.2Z"
      />
    </svg>
  )
}

export function IconSparkPlus({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 20" className={className} aria-hidden>
      <path {...stroke} d="M11.2 2.2 5.4 10.4h4.2L7.6 17.8 15.4 8.8h-4.1L11.2 2.2Z" />
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
