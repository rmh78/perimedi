import { useEffect, useState, type FormEvent } from 'react'
import { Sheet } from './Sheet'
import type { Medication, MedForm, Schedule } from '../types'
import { MED_FORM_LABELS, WEEKDAY_SHORT } from '../types'
import {
  deleteMedication,
  deleteSchedule,
  upsertMedication,
} from '../db/actions'
import { useSchedules } from '../hooks/useAppData'
import { describeTherapyCycle, getScheduleTimes } from '../lib/therapyCycle'

type Props = {
  open: boolean
  medication: Medication | null
  /** When adding new med */
  isNew?: boolean
  onClose: () => void
  onSaved: (medication: Medication) => void
  onEditSchedule: (medicationId: string, schedule: Schedule | null) => void
}

export function EditMedicationSheet({
  open,
  medication,
  isNew,
  onClose,
  onSaved,
  onEditSchedule,
}: Props) {
  const schedules = useSchedules()
  const [name, setName] = useState('')
  const [form, setForm] = useState<MedForm>('PILL')
  const [doseLabel, setDoseLabel] = useState('')
  const [instructions, setInstructions] = useState('')

  useEffect(() => {
    if (!open) return
    if (medication && !isNew) {
      setName(medication.name)
      setForm(medication.form)
      setDoseLabel(medication.doseLabel)
      setInstructions(medication.instructions ?? '')
    } else {
      setName('')
      setForm('PILL')
      setDoseLabel('')
      setInstructions('')
    }
  }, [open, medication, isNew])

  const medId = medication?.id
  const medSchedules = medId
    ? schedules.filter((s) => s.medicationId === medId)
    : []

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (!name.trim() || !doseLabel.trim()) return
    const id = await upsertMedication({
      id: isNew ? undefined : medication?.id,
      name,
      form,
      doseLabel,
      instructions,
    })
    onSaved({
      id,
      name: name.trim(),
      form,
      doseLabel: doseLabel.trim(),
      instructions: instructions.trim() || undefined,
      createdAt: medication?.createdAt ?? new Date().toISOString(),
    })
  }

  return (
    <Sheet
      open={open}
      title={isNew || !medication ? 'Add medication' : 'Edit medication'}
      onClose={onClose}
    >
      <form onSubmit={onSubmit} className="space-y-3">
        <label className="block text-sm">
          <span className="mb-1 block font-medium text-ink-soft">Name</span>
          <input
            className="soft-input"
            value={name}
            onChange={(e) => setName(e.target.value)}
            required
            autoFocus
          />
        </label>
        <label className="block text-sm">
          <span className="mb-1 block font-medium text-ink-soft">Form</span>
          <select
            className="soft-input"
            value={form}
            onChange={(e) => setForm(e.target.value as MedForm)}
          >
            {Object.entries(MED_FORM_LABELS).map(([k, v]) => (
              <option key={k} value={k}>
                {v}
              </option>
            ))}
          </select>
        </label>
        <label className="block text-sm">
          <span className="mb-1 block font-medium text-ink-soft">Default dose</span>
          <input
            className="soft-input"
            value={doseLabel}
            onChange={(e) => setDoseLabel(e.target.value)}
            required
            placeholder="e.g. 1 tablet, 10 mg"
          />
        </label>
        <label className="block text-sm">
          <span className="mb-1 block font-medium text-ink-soft">
            Instructions (optional)
          </span>
          <input
            className="soft-input"
            value={instructions}
            onChange={(e) => setInstructions(e.target.value)}
          />
        </label>

        <div className="flex flex-wrap gap-2 pt-1">
          <button type="submit" className="btn-primary">
            Save
          </button>
          <button type="button" className="btn-ghost" onClick={onClose}>
            Cancel
          </button>
        </div>
      </form>

      {!isNew && medication && (
        <div className="mt-6 border-t border-blush-100 pt-4">
          <div className="mb-2 flex items-center justify-between gap-2">
            <p className="text-sm font-semibold text-ink">Schedules</p>
            <button
              type="button"
              className="text-xs font-semibold text-blush-700"
              onClick={() => onEditSchedule(medication.id, null)}
            >
              + Add schedule
            </button>
          </div>
          {medSchedules.length === 0 ? (
            <p className="text-sm text-ink-muted">
              No schedule yet — add when to take this med.
            </p>
          ) : (
            <ul className="space-y-2">
              {medSchedules.map((s) => (
                <li
                  key={s.id}
                  className="flex flex-wrap items-center justify-between gap-2 rounded-xl bg-blush-50/80 px-3 py-2 text-sm ring-1 ring-blush-100"
                >
                  <span className="min-w-0 text-ink-soft">
                    {getScheduleTimes(s).join(', ')} ·{' '}
                    {s.daysOfWeek.length
                      ? s.daysOfWeek.map((d) => WEEKDAY_SHORT[d]).join(', ')
                      : 'Every day'}
                    {s.doseLabel ? ` · ${s.doseLabel}` : ''}
                    <span className="block text-xs text-blush-800">
                      {describeTherapyCycle(s)}
                    </span>
                  </span>
                  <span className="flex shrink-0 gap-2 text-xs font-semibold">
                    <button
                      type="button"
                      className="text-blush-700"
                      onClick={() => onEditSchedule(medication.id, s)}
                    >
                      Edit
                    </button>
                    <button
                      type="button"
                      className="text-rose-600"
                      onClick={() => {
                        if (confirm('Remove this schedule?')) void deleteSchedule(s.id)
                      }}
                    >
                      Remove
                    </button>
                  </span>
                </li>
              ))}
            </ul>
          )}

          <button
            type="button"
            className="mt-4 text-sm font-semibold text-rose-700"
            onClick={() => {
              if (
                confirm(
                  `Delete ${medication.name} and all its schedules?`,
                )
              ) {
                void deleteMedication(medication.id).then(onClose)
              }
            }}
          >
            Delete medication
          </button>
        </div>
      )}
    </Sheet>
  )
}
