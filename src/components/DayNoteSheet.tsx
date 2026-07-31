import { useEffect, useState, type FormEvent } from 'react'
import { Sheet } from './Sheet'
import type { RemarkKind } from '../types'
import { addRemark } from '../db/actions'
import { useLocale } from '../i18n'
import { formatLongDateLocalized } from '../i18n'

type Props = {
  open: boolean
  dateKey: string
  onClose: () => void
  onSaved: () => void
}

export function DayNoteSheet({ open, dateKey, onClose, onSaved }: Props) {
  const { t, locale } = useLocale()
  const [body, setBody] = useState('')
  const [kind, setKind] = useState<RemarkKind>('cycle')

  useEffect(() => {
    if (open) {
      setBody('')
      setKind('cycle')
    }
  }, [open, dateKey])

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (!body.trim()) return
    await addRemark({
      body,
      kind,
      occurredOn: dateKey,
    })
    onSaved()
  }

  return (
    <Sheet open={open} title={t('symptom.title')} onClose={onClose}>
      <p className="mb-3 text-sm text-ink-soft">
        {t('symptom.date')}{' '}
        <strong>{formatLongDateLocalized(dateKey, locale)}</strong>
      </p>
      <form onSubmit={onSubmit} className="space-y-3">
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
            autoFocus
            placeholder={t('symptom.placeholder')}
          />
        </label>
        <div className="flex gap-2">
          <button type="submit" className="btn-primary">
            {t('common.save')}
          </button>
          <button type="button" className="btn-ghost" onClick={onClose}>
            {t('common.cancel')}
          </button>
        </div>
      </form>
    </Sheet>
  )
}
