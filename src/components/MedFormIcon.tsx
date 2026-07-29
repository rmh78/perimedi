import type { MedForm } from '../types'

const sizeMap = {
  sm: 28,
  md: 36,
  lg: 48,
  xl: 48,
} as const

const FORM_ICON_SRC: Record<MedForm, string> = {
  PILL: '/med-icons/pill.jpg',
  CREAM: '/med-icons/cream.jpg',
  DROPS: '/med-icons/drops.jpg',
  INJECTION: '/med-icons/injection.jpg',
  OTHER: '/med-icons/other.jpg',
}

const FORM_ALT: Record<MedForm, string> = {
  PILL: 'Pill',
  CREAM: 'Cream',
  DROPS: 'Drops',
  INJECTION: 'Injection',
  OTHER: 'Medication',
}

export function MedFormIcon({
  form,
  size = 'md',
  className = '',
  title,
  /** When true, image fills parent (use on a sized rounded container) */
  fill = false,
}: {
  form: MedForm
  size?: keyof typeof sizeMap
  className?: string
  title?: string
  fill?: boolean
}) {
  const s = sizeMap[size]
  const src = FORM_ICON_SRC[form]
  const alt = title ?? FORM_ALT[form]

  if (fill) {
    return (
      <img
        src={src}
        alt={alt}
        className={`h-full w-full object-cover ${className}`}
        draggable={false}
      />
    )
  }

  return (
    <img
      src={src}
      alt={alt}
      width={s}
      height={s}
      className={`rounded-full object-cover ${className}`}
      style={{ width: s, height: s }}
      draggable={false}
    />
  )
}

export { MED_FORM_ICON_COLOR } from '../lib/medColors'
