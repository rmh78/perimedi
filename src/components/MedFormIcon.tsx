import type { MedForm } from '../types'

const sizeMap = {
  sm: 14,
  md: 18,
  lg: 22,
} as const

export function MedFormIcon({
  form,
  size = 'md',
  className = '',
  title,
}: {
  form: MedForm
  size?: keyof typeof sizeMap
  className?: string
  title?: string
}) {
  const s = sizeMap[size]

  return (
    <svg
      width={s}
      height={s}
      viewBox="0 0 24 24"
      fill="none"
      className={className}
      role={title ? 'img' : undefined}
      aria-hidden={title ? undefined : true}
    >
      {title ? <title>{title}</title> : null}
      <MedFormGlyph form={form} />
    </svg>
  )
}

/** Glyph at 24x24, currentColor — usable inside other SVGs via <g>. */
export function MedFormGlyph({ form }: { form: MedForm }) {
  switch (form) {
    case 'PILL':
      return (
        <>
          <rect x="4" y="9" width="16" height="6" rx="3" fill="currentColor" opacity="0.2" />
          <path
            d="M7 12a3 3 0 0 1 3-3h4a3 3 0 1 1 0 6h-4a3 3 0 0 1-3-3Z"
            stroke="currentColor"
            strokeWidth="1.6"
          />
          <path d="M12 9v6" stroke="currentColor" strokeWidth="1.4" />
        </>
      )
    case 'CREAM':
      return (
        <>
          <path
            d="M9 3h6v3H9V3Z"
            stroke="currentColor"
            strokeWidth="1.5"
            fill="currentColor"
            opacity="0.15"
          />
          <path
            d="M8 6h8l1.5 14a1 1 0 0 1-1 1.2H7.5a1 1 0 0 1-1-1.2L8 6Z"
            stroke="currentColor"
            strokeWidth="1.5"
            fill="currentColor"
            opacity="0.12"
          />
          <path d="M10 11h4" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
        </>
      )
    case 'DROPS':
      return (
        <>
          <path
            d="M12 3c0 0 5 6.2 5 10a5 5 0 1 1-10 0c0-3.8 5-10 5-10Z"
            fill="currentColor"
            opacity="0.18"
            stroke="currentColor"
            strokeWidth="1.5"
            strokeLinejoin="round"
          />
          <path
            d="M10 14c.4 1.4 1.4 2 2.5 2"
            stroke="currentColor"
            strokeWidth="1.3"
            strokeLinecap="round"
          />
        </>
      )
    case 'INJECTION':
      return (
        <>
          <path
            d="M14.5 3.5 20 9l-2 2-1.2-1.2-7.3 7.3a2 2 0 0 1-1.2.6H5v-3.3a2 2 0 0 1 .6-1.2l7.3-7.3L10.5 5.5l2-2Z"
            stroke="currentColor"
            strokeWidth="1.4"
            fill="currentColor"
            opacity="0.12"
            strokeLinejoin="round"
          />
          <path d="M4 20l3-3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
        </>
      )
    default:
      return (
        <>
          <circle
            cx="12"
            cy="12"
            r="8"
            stroke="currentColor"
            strokeWidth="1.5"
            fill="currentColor"
            opacity="0.12"
          />
          <path
            d="M12 8v8M8 12h8"
            stroke="currentColor"
            strokeWidth="1.6"
            strokeLinecap="round"
          />
        </>
      )
  }
}

export const MED_FORM_ICON_COLOR: Record<MedForm, string> = {
  PILL: '#d43d6c',
  CREAM: '#9b6fc9',
  DROPS: '#5b8fd9',
  INJECTION: '#c97b3a',
  OTHER: '#8a6b78',
}
