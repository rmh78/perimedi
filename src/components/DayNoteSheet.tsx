import { useEffect, useState, type FormEvent } from 'react'
import { Sheet } from './Sheet'
import type { RemarkKind } from '../types'
import { addRemark } from '../db/actions'
import { formatLongDate } from '../lib/dates'

type Props = {
  open: boolean
  dateKey: string
  onClose: () => void
  onSaved: () => void
}

export function DayNoteSheet({ open, dateKey, onClose, onSaved }: Props) {
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
    <Sheet open={open} title="Add symptom" onClose={onClose}>
      <p className="mb-3 text-sm text-ink-soft">
        Date: <strong>{formatLongDate(dateKey)}</strong>
      </p>
      <form onSubmit={onSubmit} className="space-y-3">
        <label className="block text-sm">
          Type
          <select
            className="soft-input mt-1"
            value={kind}
            onChange={(e) => setKind(e.target.value as RemarkKind)}
          >
            <option value="cycle">Period / cycle</option>
            <option value="side_effect">Side effect</option>
            <option value="note">General note</option>
            <option value="other">Other</option>
          </select>
        </label>
        <label className="block text-sm">
          Description
          <textarea
            className="soft-input mt-1"
            rows={3}
            value={body}
            onChange={(e) => setBody(e.target.value)}
            required
            autoFocus
            placeholder="e.g. cramps, headache, mood…"
          />
        </label>
        <div className="flex gap-2">
          <button type="submit" className="btn-primary">
            Save
          </button>
          <button type="button" className="btn-ghost" onClick={onClose}>
            Cancel
          </button>
        </div>
      </form>
    </Sheet>
  )
}
