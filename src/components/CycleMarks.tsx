/** Shared cycle / period / symptom glyphs for chart + month calendar. */

export function BloodDropIcon({
  predicted = false,
  title,
  size = 'sm',
}: {
  predicted?: boolean
  title?: string
  size?: 'sm' | 'md'
}) {
  const w = size === 'md' ? 12 : 10
  const h = size === 'md' ? 14 : 12
  return (
    <svg
      width={w}
      height={h}
      viewBox="0 0 12 14"
      className={`shrink-0 ${predicted ? 'opacity-45' : 'opacity-95'}`}
      aria-hidden={title ? undefined : true}
      role={title ? 'img' : undefined}
    >
      {title ? <title>{title}</title> : null}
      <path
        d="M6 1C6 1 1.5 6.2 1.5 9.2a4.5 4.5 0 0 0 9 0C10.5 6.2 6 1 6 1Z"
        fill={predicted ? '#f43f5e' : '#e11d48'}
        stroke={predicted ? '#fb7185' : '#be123c'}
        strokeWidth="0.6"
        strokeLinejoin="round"
      />
    </svg>
  )
}

export function SymptomMarkIcon({
  kind = 'cycle',
  title,
}: {
  kind?: string
  title?: string
}) {
  const fill =
    kind === 'side_effect'
      ? '#8b5cf6'
      : kind === 'note'
        ? '#a78bfa'
        : '#7c3aed'
  const stroke =
    kind === 'side_effect'
      ? '#6d28d9'
      : kind === 'note'
        ? '#7c3aed'
        : '#5b21b6'

  return (
    <svg
      width="10"
      height="10"
      viewBox="0 0 12 12"
      className="shrink-0"
      aria-hidden={title ? undefined : true}
      role={title ? 'img' : undefined}
    >
      {title ? <title>{title}</title> : null}
      <path
        d="M6 1.2 6.95 4.4 10.4 4.7 7.85 6.95 8.7 10.4 6 8.55 3.3 10.4 4.15 6.95 1.6 4.7 5.05 4.4Z"
        fill={fill}
        stroke={stroke}
        strokeWidth="0.55"
        strokeLinejoin="round"
      />
    </svg>
  )
}
