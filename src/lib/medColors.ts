import type { MedForm, Medication } from '../types'

/** Default color by medication form (when no custom color is set) */
export const MED_FORM_ICON_COLOR: Record<MedForm, string> = {
  PILL: '#d43d6c',
  CREAM: '#9b6fc9',
  DROPS: '#5b8fd9',
  INJECTION: '#c97b3a',
  OTHER: '#8a6b78',
}

/** Curated palette for medication color picker */
export const MED_COLOR_PALETTE = [
  '#d43d6c', // blush rose
  '#e85a84', // pink
  '#c0265a', // deep rose
  '#9b6fc9', // lilac
  '#7c3aed', // violet
  '#5b8fd9', // blue
  '#0d9488', // teal
  '#059669', // emerald
  '#c97b3a', // amber
  '#ea580c', // orange
  '#64748b', // slate
  '#8a6b78', // mauve
] as const

export function resolveMedColor(
  medication: Pick<Medication, 'form' | 'color'> | { form: MedForm; color?: string },
): string {
  if (medication.color && /^#[0-9a-fA-F]{6}$/.test(medication.color)) {
    return medication.color
  }
  return MED_FORM_ICON_COLOR[medication.form] ?? MED_FORM_ICON_COLOR.OTHER
}

/** Soft fill for taken day cells using the med color */
export function takenFillFromColor(hex: string, alpha = 0.45): string {
  const r = parseInt(hex.slice(1, 3), 16)
  const g = parseInt(hex.slice(3, 5), 16)
  const b = parseInt(hex.slice(5, 7), 16)
  if (Number.isNaN(r) || Number.isNaN(g) || Number.isNaN(b)) {
    return `rgba(16, 185, 129, ${alpha})`
  }
  return `rgba(${r}, ${g}, ${b}, ${alpha})`
}

/** Light tint for icon circle background */
export function iconBgFromColor(hex: string, alpha = 0.18): string {
  return takenFillFromColor(hex, alpha)
}
