import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { Sheet } from './Sheet'
import type { RemarkKind } from '../types'
import { addRemark, deleteRemark, updateRemark } from '../db/actions'
import { useRemarks } from '../hooks/useAppData'
import { toDateKey } from '../lib/dates'
import { useLocale, type MessageKey } from '../i18n'
import { useConfirm } from '../context/ConfirmContext'
import { formatLongDateLocalized } from '../i18n'

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
  const [kind, setKind] = useState<RemarkKind>('cycle')
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
      setKind('cycle')
      setEditingId(null)
    }
  }, [open, dateKey])

  function startEdit(id: string) {
    const row = daySymptoms.find((s) => s.id === id)
    if (!row) return
    setEditingId(id)
    setKind(row.kind)
    setBody(row.body)
  }

  function cancelEdit() {
    setEditingId(null)
    setKind('cycle')
    setBody('')
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (!body.trim()) return
    if (editingId) {
      await updateRemark(editingId, { kind, body })
    } else {
      await addRemark({
        body,
        kind,
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

      <div className="mb-4 space-y-2">
        <p className="text-[11px] font-semibold uppercase tracking-wide text-ink-muted">
          {t('symptom.logged')}
        </p>
        {daySymptoms.length === 0 ? (
          <p className="rounded-xl bg-slate-50 px-3 py-2 text-xs text-ink-muted ring-1 ring-slate-100">
            {t('symptom.empty')}
          </p>
        ) : (
          <ul className="overflow-hidden rounded-xl ring-1 ring-blush-100">
            {daySymptoms.map((s, i) => (
              <li
                key={s.id}
                className={`flex items-start gap-2 px-2.5 py-2 ${
                  i < daySymptoms.length - 1
                    ? 'border-b border-blush-100/80'
                    : ''
                } ${editingId === s.id ? 'bg-lilac-50/70' : ''}`}
              >
                <div className="min-w-0 flex-1">
                  <p className="text-xs font-semibold text-violet-800">
                    {t(`remark.${s.kind}` as MessageKey)}
                  </p>
                  <p className="mt-0.5 text-sm text-ink">{s.body}</p>
                </div>
                <div className="flex shrink-0 gap-1.5">
                  <button
                    type="button"
                    className="btn-ghost !min-h-9 !px-2.5 !py-1 text-xs"
                    onClick={() => startEdit(s.id)}
                  >
                    {t('common.edit')}
                  </button>
                  <button
                    type="button"
                    className="btn-soft !min-h-9 !px-2.5 !py-1 text-xs"
                    onClick={() => void onDelete(s.id)}
                  >
                    {t('common.delete')}
                  </button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>

      <form onSubmit={onSubmit} className="space-y-3 border-t border-blush-100 pt-3">
        <p className="text-[11px] font-semibold uppercase tracking-wide text-ink-muted">
          {editingId ? t('symptom.editSection') : t('symptom.addSection')}
        </p>
        <label className="block text-sm">
          {t('symptom.type')}
          <select
            className="soft-input mt-1"
            value={kind}
            onChange={(e) => setKind(e.target.value as RemarkKind)}
          >
            <option value="cycle">{t('remark.cycle')}</option>
            <option value="side_effect">{t('remark.side_effect')}</option>
            <option value="note">{t('remark.note')}</option>
            <option value="other">{t('remark.other')}</option>
          </select>
        </label>
        <label className="block text-sm">
          {t('symptom.description')}
          <textarea
            className="soft-input mt-1"
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
    </Sheet>
  )
}
