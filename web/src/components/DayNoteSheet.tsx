import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { Sheet } from './Sheet'
import { replaceDayScores } from '../db/actions'
import { useRemarks, useSymptomScores } from '../hooks/useAppData'
import { toDateKey } from '../lib/dates'
import { useLocale, type MessageKey } from '../i18n'
import { formatLongDateLocalized } from '../i18n'
import { allowsCount, SYMPTOM_GROUPS, type SymptomId } from '../lib/symptoms'

type Props = {
  open: boolean
  dateKey: string
  onClose: () => void
  onSaved: () => void
}

export function DayNoteSheet({ open, dateKey, onClose, onSaved }: Props) {
  const { t, locale } = useLocale()
  const remarks = useRemarks()
  const scores = useSymptomScores()
  const [severity, setSeverity] = useState<Partial<Record<SymptomId, number>>>({})
  const [hotCount, setHotCount] = useState<number | undefined>(undefined)
  const [note, setNote] = useState('')
  const [noteId, setNoteId] = useState<string | null>(null)

  const dayScores = useMemo(
    () => scores.filter((s) => s.date === dateKey),
    [scores, dateKey],
  )

  useEffect(() => {
    if (!open) return
    const next: Partial<Record<SymptomId, number>> = {}
    let count: number | undefined
    let loadedNote = ''
    for (const row of dayScores) {
      next[row.id as SymptomId] = row.severity
      if (row.id === 'hot_flash') count = row.count
      if (!loadedNote && row.note) loadedNote = row.note
    }
    const remark = remarks.find((r) => toDateKey(r.occurredOn) === dateKey)
    setSeverity(next)
    setHotCount(count)
    setNote(loadedNote || remark?.body || '')
    setNoteId(remark?.id ?? null)
  }, [open, dateKey, dayScores, remarks])

  function setRow(id: SymptomId, value: number) {
    setSeverity((prev) => {
      if (prev[id] === value) {
        const next = { ...prev }
        delete next[id]
        if (id === 'hot_flash') setHotCount(undefined)
        return next
      }
      return { ...prev, [id]: value }
    })
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    const rows = (Object.entries(severity) as [SymptomId, number][]).map(
      ([id, value]) => ({
        id,
        severity: value,
        count: id === 'hot_flash' ? hotCount : undefined,
      }),
    )
    await replaceDayScores({
      date: dateKey,
      scores: rows,
      note,
      noteId,
    })
    onSaved()
    onClose()
  }

  return (
    <Sheet
      open={open}
      title={t('symptom.title')}
      icon="/action-icons/symptom.jpg"
      onClose={onClose}
    >
      <p className="mb-2 text-sm text-ink-soft">
        {t('symptom.date')}{' '}
        <strong>{formatLongDateLocalized(dateKey, locale)}</strong>
      </p>
      <p className="mb-3 text-xs text-ink-muted">{t('symptom.scaleHint')}</p>

      <form onSubmit={onSubmit} className="space-y-4">
        {SYMPTOM_GROUPS.map((group) => (
          <div key={group.id}>
            <p className="mb-2 text-[11px] font-semibold uppercase tracking-wide text-ink-muted">
              {t(`symptom.group.${group.id}` as MessageKey)}
            </p>
            <div className="divide-y divide-blush-100">
              {group.ids.map((id) => (
                <div key={id} className="py-2">
                  <div className="flex items-center gap-2">
                    <p className="min-w-0 flex-1 text-sm font-medium text-ink">
                      {t(`symptom.id.${id}` as MessageKey)}
                    </p>
                    <div className="flex gap-1">
                      {[0, 1, 2, 3, 4].map((value) => {
                        const selected = severity[id] === value
                        return (
                          <button
                            key={value}
                            type="button"
                            onClick={() => setRow(id, value)}
                            className={`h-7 w-7 rounded-full text-xs font-semibold ${
                              selected
                                ? 'bg-blush-600 text-white'
                                : 'bg-blush-50 text-blush-700'
                            }`}
                          >
                            {value}
                          </button>
                        )
                      })}
                    </div>
                  </div>
                  {allowsCount(id) ? (
                    <label className="mt-2 flex items-center justify-between text-xs text-ink-soft">
                      {t('symptom.count')}
                      <input
                        type="number"
                        min={0}
                        max={99}
                        disabled={severity.hot_flash == null}
                        value={hotCount ?? 0}
                        onChange={(e) => setHotCount(Number(e.target.value))}
                        className="soft-input w-20 py-1 text-right"
                      />
                    </label>
                  ) : null}
                </div>
              ))}
            </div>
          </div>
        ))}

        <label className="block text-sm">
          {t('symptom.note')}
          <input
            className="soft-input mt-1"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder={t('symptom.notePlaceholder')}
          />
        </label>

        <div className="flex flex-wrap gap-2">
          <button type="submit" className="btn-primary">
            {t('symptom.saveEdit')}
          </button>
          <button type="button" className="btn-ghost" onClick={onClose}>
            {t('common.close')}
          </button>
        </div>
      </form>
    </Sheet>
  )
}
