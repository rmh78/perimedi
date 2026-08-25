import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { Sheet } from './Sheet'
import { addRemark, deleteRemark, updateRemark } from '../db/actions'
import { useRemarks } from '../hooks/useAppData'
import { toDateKey } from '../lib/dates'
import { useLocale } from '../i18n'
import { useConfirm } from '../context/ConfirmContext'
import { formatLongDateLocalized } from '../i18n'
import { HistoryIconButton } from './HistoryIconButton'

type Props = {
  open: boolean
  dateKey: string
  onClose: () => void
  onSaved: () => void
}

function isSymptomKind(kind: string): boolean {
  return kind === 'cycle' || kind === 'side_effect' || kind === 'note' || kind === 'other'
}

export function DayNoteSheet({ open, dateKey, onClose, onSaved }: Props) {
  const { t, locale } = useLocale()
  const confirm = useConfirm()
  const remarks = useRemarks()
  const [body, setBody] = useState('')
  const [editingId, setEditingId] = useState<string | null>(null)

  const daySymptoms = useMemo(
    () =>
      remarks.filter(
        (r) => toDateKey(r.occurredOn) === dateKey && isSymptomKind(r.kind),
      ),
    [remarks, dateKey],
  )

  useEffect(() => {
    if (open) {
      setBody('')
      setEditingId(null)
    }
  }, [open, dateKey])

  function startEdit(id: string) {
    const row = daySymptoms.find((s) => s.id === id)
    if (!row) return
    setEditingId(id)
    setBody(row.body)
  }

  function cancelEdit() {
    setEditingId(null)
    setBody('')
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (!body.trim()) return
    if (editingId) {
      await updateRemark(editingId, { body })
    } else {
      await addRemark({
        body,
        kind: 'note',
        occurredOn: dateKey,
      })
    }
    cancelEdit()
    onSaved()
  }

  async function onDelete(id: string) {
    const ok = await confirm({
      message: t('symptom.deleteConfirm'),
      danger: true,
    })
    if (!ok) return
    await deleteRemark(id)
    if (editingId === id) cancelEdit()
    onSaved()
  }

  return (
    <Sheet
      open={open}
      title={t('symptom.title')}
      icon="/action-icons/symptom.jpg"
      onClose={onClose}
    >
      <p className="mb-3 text-sm text-ink-soft">
        {t('symptom.date')}{' '}
        <strong>{formatLongDateLocalized(dateKey, locale)}</strong>
      </p>

      <form onSubmit={onSubmit} className="space-y-3">
        <p className="text-[11px] font-semibold uppercase tracking-wide text-ink-muted">
          {editingId ? t('symptom.editSection') : t('symptom.addSection')}
        </p>
        <label className="block text-sm">
          {t('symptom.description')}
          <textarea
            className="soft-input mt-1 py-2.5"
            rows={3}
            value={body}
            onChange={(e) => setBody(e.target.value)}
            required
            placeholder={t('symptom.placeholder')}
          />
        </label>
        <div className="flex flex-wrap gap-2">
          <button type="submit" className="btn-primary">
            {editingId ? t('symptom.saveEdit') : t('symptom.saveAdd')}
          </button>
          {editingId ? (
            <button type="button" className="btn-ghost" onClick={cancelEdit}>
              {t('common.cancel')}
            </button>
          ) : (
            <button type="button" className="btn-ghost" onClick={onClose}>
              {t('common.close')}
            </button>
          )}
        </div>
      </form>

      <div className="mt-4 space-y-2 border-t border-blush-100 pt-3">
        <p className="text-[11px] font-semibold uppercase tracking-wide text-ink-muted">
          {t('symptom.logged')}
        </p>
        {daySymptoms.length === 0 ? (
          <p className="rounded-xl bg-slate-50 px-3 py-2 text-xs text-ink-muted ring-1 ring-slate-100">
            {t('symptom.empty')}
          </p>
        ) : (
          <ul className="divide-y divide-blush-100">
            {daySymptoms.map((s) => (
              <li
                key={s.id}
                className={`flex items-center gap-2 py-2 ${
                  editingId === s.id ? 'bg-blush-50/80' : ''
                }`}
              >
                <div className="min-w-0 flex-1">
                  <p className="line-clamp-2 text-sm font-semibold text-ink">{s.body}</p>
                </div>
                <div className="flex shrink-0 gap-1">
                  <HistoryIconButton
                    kind="edit"
                    label={t('common.edit')}
                    onClick={() => startEdit(s.id)}
                  />
                  <HistoryIconButton
                    kind="delete"
                    label={t('common.delete')}
                    onClick={() => void onDelete(s.id)}
                  />
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </Sheet>
  )
}
