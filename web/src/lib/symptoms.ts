export const SYMPTOM_IDS = [
  'hot_flash',
  'heart',
  'sleep',
  'joints',
  'mood',
  'irritability',
  'anxiety',
  'exhaustion',
  'sexual',
  'bladder',
  'vaginal_dryness',
] as const

export type SymptomId = (typeof SYMPTOM_IDS)[number]

export type SymptomGroupId = 'body' | 'mood' | 'urogenital'

export const SYMPTOM_GROUPS: { id: SymptomGroupId; ids: SymptomId[] }[] = [
  { id: 'body', ids: ['hot_flash', 'heart', 'sleep', 'joints'] },
  { id: 'mood', ids: ['mood', 'irritability', 'anxiety', 'exhaustion'] },
  {
    id: 'urogenital',
    ids: ['sexual', 'bladder', 'vaginal_dryness'],
  },
]

export function allowsCount(id: SymptomId): boolean {
  return id === 'hot_flash'
}
