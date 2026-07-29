import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { Sheet } from './Sheet'
import type { Medication, MedForm, Schedule, TherapyPresetId } from '../types'
import { MED_FORM_LABELS, THERAPY_PRESETS, WEEKDAY_SHORT } from '../types'
import {
  deleteMedication,
  upsertMedication,
  upsertSchedule,
} from '../db/actions'
import { useSchedules } from '../hooks/useAppData'
import {
  formatPreviewDate,
  normalizeTherapyCycle,
  previewTherapyCycle,
} from '../lib/therapyCycle'
import {
  MED_COLOR_PALETTE,
  MED_FORM_ICON_COLOR,
  resolveMedColor,
} from '../lib/medColors'
import { MedFormIcon } from './MedFormIcon'
import {
  freshScheduleForm,
  scheduleToForm,
  type SchedFormState,
} from '../lib/scheduleForm'
import { todayKey } from '../lib/dates'

type Props = {
  open: boolean
  medication: Medication | null
  /** When adding new med */
  isNew?: boolean
  onClose: () => void
  onSaved: (medication: Medication) => void
}

export function EditMedicationSheet({
  open,
  medication,
  isNew,
  onClose,
  onSaved,
}: Props) {
  const schedules = useSchedules()
  const [name, setName] = useState('')
  const [form, setForm] = useState<MedForm>('PILL')
  const [doseLabel, setDoseLabel] = useState('')
  const [color, setColor] = useState<string>(MED_FORM_ICON_COLOR.PILL)
  const [sched, setSched] = useState<SchedFormState>(freshScheduleForm)
  /** Specific weekdays XOR cyclic — not both */
  const [schedMode, setSchedMode] = useState<
    'every_day' | 'specific_days' | 'cyclic'
  >('every_day')
  const [primaryScheduleId, setPrimaryScheduleId] = useState<string | undefined>()
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const medId = medication?.id
  const medSchedules = medId
    ? schedules.filter((s) => s.medicationId === medId)
    : []

  useEffect(() => {
    if (!open) return
    setError(null)
    setSaving(false)
    if (medication && !isNew) {
      setName(medication.name)
      setForm(medication.form)
      setDoseLabel(medication.doseLabel)
      setColor(resolveMedColor(medication))
      const primary = schedules
        .filter((s) => s.medicationId === medication.id)
        .sort((a, b) => a.timeOfDay.localeCompare(b.timeOfDay))[0]
      if (primary) {
        const loaded = scheduleToForm(primary)
        // Prefer cyclic over weekdays if both were stored
        if (loaded.cyclic) {
          loaded.daysOfWeek = []
          setSchedMode('cyclic')
        } else if (loaded.daysOfWeek.length > 0) {
          loaded.cyclic = false
          setSchedMode('specific_days')
        } else {
          loaded.cyclic = false
          setSchedMode('every_day')
        }
        setSched(loaded)
        setPrimaryScheduleId(primary.id)
      } else {
        setSched(freshScheduleForm())
        setSchedMode('every_day')
        setPrimaryScheduleId(undefined)
      }
    } else {
      setName('')
      setForm('PILL')
      setDoseLabel('')
      setColor(MED_FORM_ICON_COLOR.PILL)
      setSched(freshScheduleForm())
      setSchedMode('every_day')
      setPrimaryScheduleId(undefined)
    }
    // Only re-init when sheet opens or target med changes — not on every schedules tick
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, medication?.id, isNew])

  const draftSchedule: Schedule = useMemo(
    () => ({
      id: primaryScheduleId ?? 'draft',
      medicationId: medId || 'draft',
      daysOfWeek: schedMode === 'specific_days' ? sched.daysOfWeek : [],
      timeOfDay: sched.times[0] || '08:00',
      times: sched.times,
      doseLabel: undefined,
      active: true,
      startDate: sched.startDate || undefined,
      endDate: sched.endDate || undefined,
      cycleRule: 'none',
      therapyCycle:
        schedMode === 'cyclic'
          ? {
              enabled: true,
              mode:
                sched.therapyPreset === 'week_slots'
                  ? 'week_slots'
                  : 'on_off_days',
              anchorDate: sched.anchorDate,
              onDays: sched.onDays,
              offDays: sched.offDays,
              slots:
                sched.therapyPreset === 'week_slots'
                  ? sched.weekSlots
                  : undefined,
            }
          : undefined,
    }),
    [sched, schedMode, medId, primaryScheduleId],
  )

  const preview = useMemo(
    () => previewTherapyCycle(draftSchedule, todayKey()),
    [draftSchedule],
  )

  function applyTherapyPreset(id: TherapyPresetId) {
    const p = THERAPY_PRESETS.find((x) => x.id === id)
    if (!p) return
    if (id === 'continuous') {
      setSched((f) => ({ ...f, cyclic: false, therapyPreset: 'continuous' }))
      return
    }
    setSched((f) => ({
      ...f,
      cyclic: true,
      therapyPreset: id,
      onDays: p.onDays,
      offDays: p.offDays,
      weekSlots: p.slots ? p.slots.map((s) => ({ ...s })) : f.weekSlots,
    }))
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (!name.trim() || !doseLabel.trim()) {
      setError('Name and default dose are required.')
      return
    }
    if (!sched.times.length || !sched.times[0]) {
      setError('Add at least one time for the schedule.')
      return
    }
    setSaving(true)
    setError(null)
    try {
      const id = await upsertMedication({
        id: isNew ? undefined : medication?.id,
        name,
        form,
        doseLabel,
        color,
      })

      const isCyclic = schedMode === 'cyclic'
      const daysOfWeek =
        schedMode === 'specific_days' ? sched.daysOfWeek : []

      const anchor = sched.anchorDate || sched.startDate || todayKey()
      const therapyCycle = normalizeTherapyCycle(
        isCyclic
          ? {
              enabled: true,
              mode:
                sched.therapyPreset === 'week_slots'
                  ? 'week_slots'
                  : sched.therapyPreset === 'continuous'
                    ? 'continuous'
                    : 'on_off_days',
              anchorDate: anchor,
              onDays: sched.onDays,
              offDays: sched.offDays,
              slots: sched.weekSlots,
            }
          : {
              enabled: false,
              mode: 'continuous',
              anchorDate: anchor,
              onDays: 0,
              offDays: 0,
            },
        anchor,
      )

      await upsertSchedule({
        id: primaryScheduleId,
        medicationId: id,
        daysOfWeek,
        times: sched.times,
        doseLabel: undefined,
        active: true,
        startDate: sched.startDate || undefined,
        endDate: sched.endDate || undefined,
        cycleRule: 'none',
        cycleDayFrom: undefined,
        cycleDayTo: undefined,
        therapyCycle,
      })

      onSaved({
        id,
        name: name.trim(),
        form,
        doseLabel: doseLabel.trim(),
        color,
        createdAt: medication?.createdAt ?? new Date().toISOString(),
      })
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save medication.')
    } finally {
      setSaving(false)
    }
  }

  return (
    <Sheet
      open={open}
      title={isNew || !medication ? 'Add medication' : 'Edit medication'}
      onClose={onClose}
      wide
    >
      <form onSubmit={onSubmit} className="space-y-3 text-sm">
        {/* Medication — dense grid */}
        <section className="space-y-2">
          <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-muted">
            Medication
          </p>
          <label className="block">
            <span className="mb-0.5 block text-xs font-medium text-ink-soft">
              Name
            </span>
            <input
              className="soft-input !rounded-xl !px-2.5 !py-1.5 !text-sm"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              autoFocus
            />
          </label>
          <div className="grid grid-cols-2 gap-2">
            <label className="block">
              <span className="mb-0.5 block text-xs font-medium text-ink-soft">
                Form
              </span>
              <select
                className="soft-input !rounded-xl !px-2.5 !py-1.5 !text-sm"
                value={form}
                onChange={(e) => {
                  const next = e.target.value as MedForm
                  setForm((prev) => {
                    if (color === MED_FORM_ICON_COLOR[prev]) {
                      setColor(MED_FORM_ICON_COLOR[next])
                    }
                    return next
                  })
                }}
              >
                {Object.entries(MED_FORM_LABELS).map(([k, v]) => (
                  <option key={k} value={k}>
                    {v}
                  </option>
                ))}
              </select>
            </label>
            <label className="block">
              <span className="mb-0.5 block text-xs font-medium text-ink-soft">
                Default dose
              </span>
              <input
                className="soft-input !rounded-xl !px-2.5 !py-1.5 !text-sm"
                value={doseLabel}
                onChange={(e) => setDoseLabel(e.target.value)}
                required
                placeholder="e.g. 10 mg"
              />
            </label>
          </div>
          <div>
            <span className="mb-0.5 block text-xs font-medium text-ink-soft">
              Color
            </span>
            <div className="flex items-center gap-2.5 py-1">
              <span
                className="h-9 w-9 shrink-0 overflow-hidden rounded-full"
                style={{
                  boxShadow: `0 0 0 4px ${color}`,
                  background: `${color}33`,
                }}
              >
                <MedFormIcon form={form} fill />
              </span>
              <div className="flex min-w-0 flex-1 flex-nowrap items-center gap-1.5 overflow-x-auto py-1">
                {MED_COLOR_PALETTE.map((c) => {
                  const selected = color.toLowerCase() === c.toLowerCase()
                  return (
                    <button
                      key={c}
                      type="button"
                      title={c}
                      onClick={() => setColor(c)}
                      className="h-5 w-5 shrink-0 rounded-full"
                      style={{
                        background: c,
                        boxShadow: selected
                          ? `0 0 0 2px #fff, 0 0 0 4px ${c}`
                          : '0 0 0 1px rgba(0,0,0,0.1)',
                      }}
                      aria-label={`Color ${c}`}
                      aria-pressed={selected}
                    />
                  )
                })}
              </div>
            </div>
          </div>
        </section>

        {/* Schedule */}
        <section className="space-y-2 border-t border-blush-100 pt-3">
          <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-muted">
            Schedule
          </p>

          <div className="flex flex-wrap gap-1 rounded-xl bg-blush-50/50 p-1 ring-1 ring-blush-100">
            {(
              [
                ['every_day', 'Every day'],
                ['specific_days', 'Specific days'],
                ['cyclic', 'Cyclic'],
              ] as const
            ).map(([mode, label]) => (
              <button
                key={mode}
                type="button"
                onClick={() => {
                  setSchedMode(mode)
                  if (mode === 'cyclic') {
                    setSched((f) => ({
                      ...f,
                      daysOfWeek: [],
                      cyclic: true,
                      therapyPreset:
                        f.therapyPreset === 'continuous' ? '21_7' : f.therapyPreset,
                      onDays: f.onDays || 21,
                      offDays: f.offDays || 7,
                    }))
                  } else if (mode === 'specific_days') {
                    setSched((f) => ({
                      ...f,
                      cyclic: false,
                      therapyPreset: 'continuous',
                      daysOfWeek:
                        f.daysOfWeek.length > 0 ? f.daysOfWeek : [1, 3, 5],
                    }))
                  } else {
                    setSched((f) => ({
                      ...f,
                      cyclic: false,
                      therapyPreset: 'continuous',
                      daysOfWeek: [],
                    }))
                  }
                }}
                className={`flex-1 rounded-lg px-2 py-1.5 text-[11px] font-semibold transition ${
                  schedMode === mode
                    ? 'bg-blush-600 text-white shadow-sm'
                    : 'text-ink-soft hover:bg-white/80'
                }`}
              >
                {label}
              </button>
            ))}
          </div>

          {schedMode === 'specific_days' && (
            <div className="rounded-xl bg-blush-50/50 p-2.5 ring-1 ring-blush-100">
              <p className="mb-1.5 text-xs font-semibold text-ink">Days</p>
              <div className="flex flex-wrap gap-1">
                {WEEKDAY_SHORT.map((label, idx) => {
                  const on = sched.daysOfWeek.includes(idx)
                  return (
                    <button
                      key={label}
                      type="button"
                      onClick={() =>
                        setSched((f) => ({
                          ...f,
                          daysOfWeek: on
                            ? f.daysOfWeek.filter((d) => d !== idx)
                            : [...f.daysOfWeek, idx].sort(),
                        }))
                      }
                      className={`rounded-full px-2 py-0.5 text-[11px] font-semibold ${
                        on
                          ? 'bg-blush-500 text-white'
                          : 'bg-white text-ink-soft ring-1 ring-blush-100'
                      }`}
                    >
                      {label}
                    </button>
                  )
                })}
              </div>
            </div>
          )}

          {schedMode === 'cyclic' && (
            <div className="space-y-2 rounded-xl bg-blush-50/50 p-2.5 ring-1 ring-blush-100">
              <label className="block">
                <span className="mb-0.5 block text-xs font-medium text-ink-soft">
                  Preset
                </span>
                <select
                  className="soft-input !rounded-xl !px-2.5 !py-1.5 !text-sm"
                  value={sched.therapyPreset}
                  onChange={(e) =>
                    applyTherapyPreset(e.target.value as TherapyPresetId)
                  }
                >
                  {THERAPY_PRESETS.filter((p) => p.id !== 'continuous').map(
                    (p) => (
                      <option key={p.id} value={p.id}>
                        {p.label}
                      </option>
                    ),
                  )}
                </select>
              </label>

              {sched.therapyPreset !== 'week_slots' && (
                <div className="grid grid-cols-2 gap-2">
                  <label className="block">
                    <span className="mb-0.5 block text-xs font-medium text-ink-soft">
                      Apply (days)
                    </span>
                    <input
                      type="number"
                      min={1}
                      max={365}
                      className="soft-input !rounded-xl !px-2.5 !py-1.5 !text-sm"
                      value={sched.onDays}
                      onChange={(e) =>
                        setSched((f) => ({
                          ...f,
                          onDays: Number(e.target.value) || 1,
                          therapyPreset: 'custom_days',
                        }))
                      }
                    />
                  </label>
                  <label className="block">
                    <span className="mb-0.5 block text-xs font-medium text-ink-soft">
                      Pause (days)
                    </span>
                    <input
                      type="number"
                      min={0}
                      max={365}
                      className="soft-input !rounded-xl !px-2.5 !py-1.5 !text-sm"
                      value={sched.offDays}
                      onChange={(e) =>
                        setSched((f) => ({
                          ...f,
                          offDays: Number(e.target.value) || 0,
                          therapyPreset: 'custom_days',
                        }))
                      }
                    />
                  </label>
                </div>
              )}

              {sched.therapyPreset === 'week_slots' && (
                <div className="space-y-1.5">
                  {sched.weekSlots.map((slot, idx) => (
                    <div
                      key={idx}
                      className="grid grid-cols-[auto_1fr] gap-1.5"
                    >
                      <button
                        type="button"
                        onClick={() =>
                          setSched((f) => ({
                            ...f,
                            weekSlots: f.weekSlots.map((s, i) =>
                              i === idx ? { ...s, take: !s.take } : s,
                            ),
                          }))
                        }
                        className={`rounded-full px-2.5 py-1 text-[11px] font-semibold ${
                          slot.take
                            ? 'bg-emerald-600 text-white'
                            : 'bg-slate-300 text-slate-800'
                        }`}
                      >
                        {slot.take ? 'Apply' : 'Pause'}
                      </button>
                      <input
                        className="soft-input !rounded-xl !px-2 !py-1 !text-sm"
                        placeholder="Dose"
                        disabled={!slot.take}
                        value={slot.doseLabel ?? ''}
                        onChange={(e) =>
                          setSched((f) => ({
                            ...f,
                            weekSlots: f.weekSlots.map((s, i) =>
                              i === idx
                                ? { ...s, doseLabel: e.target.value }
                                : s,
                            ),
                          }))
                        }
                      />
                    </div>
                  ))}
                </div>
              )}

              <label className="block">
                <span className="mb-0.5 block text-xs font-medium text-ink-soft">
                  Cycle starts on
                </span>
                <input
                  type="date"
                  className="soft-input !rounded-xl !px-2.5 !py-1.5 !text-sm"
                  value={sched.anchorDate}
                  onChange={(e) =>
                    setSched((f) => ({ ...f, anchorDate: e.target.value }))
                  }
                />
              </label>

              <p className="rounded-lg bg-white/90 px-2 py-1.5 text-[11px] text-ink-soft ring-1 ring-blush-100">
                <span className="font-semibold text-ink">{preview.label}</span>
                {' · '}
                Pause {formatPreviewDate(preview.nextPauseStart)}
                {' · '}
                Apply {formatPreviewDate(preview.nextApplyStart)}
              </p>
            </div>
          )}

          <div className="rounded-xl bg-blush-50/50 p-2.5 ring-1 ring-blush-100">
            <p className="mb-0.5 text-xs font-semibold text-ink">
              Take at
            </p>
            <p className="mb-1.5 text-[11px] text-ink-muted">
              Clock times for each dose (e.g. 08:00 and 20:00 if twice a day)
            </p>
            <div className="flex flex-wrap items-center gap-1.5">
              {sched.times.map((t, i) => (
                <div key={i} className="flex items-center gap-1">
                  <input
                    type="time"
                    className="soft-input !w-auto !rounded-lg !px-2 !py-1 !text-sm"
                    value={t}
                    onChange={(e) =>
                      setSched((f) => {
                        const times = [...f.times]
                        times[i] = e.target.value
                        return { ...f, times }
                      })
                    }
                    required
                    aria-label={`Dose time ${i + 1}`}
                  />
                  {sched.times.length > 1 && (
                    <button
                      type="button"
                      className="text-[11px] font-semibold text-rose-600"
                      onClick={() =>
                        setSched((f) => ({
                          ...f,
                          times: f.times.filter((_, j) => j !== i),
                        }))
                      }
                      aria-label={`Remove time ${i + 1}`}
                    >
                      ×
                    </button>
                  )}
                </div>
              ))}
              <button
                type="button"
                className="text-[11px] font-semibold text-blush-700"
                onClick={() =>
                  setSched((f) => ({ ...f, times: [...f.times, '12:00'] }))
                }
              >
                + Another dose time
              </button>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-2 rounded-xl bg-blush-50/50 p-2.5 ring-1 ring-blush-100">
            <label className="block">
              <span className="mb-0.5 block text-xs font-medium text-ink-soft">
                Start
              </span>
              <input
                type="date"
                className="soft-input !rounded-xl !px-2 !py-1.5 !text-sm"
                value={sched.startDate}
                onChange={(e) =>
                  setSched((f) => ({
                    ...f,
                    startDate: e.target.value,
                    anchorDate: f.cyclic
                      ? f.anchorDate || e.target.value
                      : f.anchorDate,
                  }))
                }
              />
            </label>
            <label className="block">
              <span className="mb-0.5 block text-xs font-medium text-ink-soft">
                End (optional)
              </span>
              <input
                type="date"
                className="soft-input !rounded-xl !px-2 !py-1.5 !text-sm"
                value={sched.endDate}
                onChange={(e) =>
                  setSched((f) => ({ ...f, endDate: e.target.value }))
                }
              />
            </label>
          </div>

          {!isNew && medSchedules.length > 1 && (
            <p className="text-[11px] text-ink-muted">
              Edits the primary schedule ({medSchedules.length} total). Extra
              schedules stay as-is.
            </p>
          )}
        </section>

        {error && (
          <p className="rounded-lg bg-rose-50 px-2.5 py-1.5 text-xs text-rose-800">
            {error}
          </p>
        )}

        <div className="flex flex-wrap items-center gap-2 border-t border-blush-100 pt-2.5">
          <button
            type="submit"
            className="btn-primary !px-4 !py-1.5 text-sm"
            disabled={saving}
          >
            {saving ? 'Saving…' : isNew ? 'Save medication' : 'Save changes'}
          </button>
          <button
            type="button"
            className="btn-ghost !px-3 !py-1.5 text-sm"
            onClick={onClose}
          >
            Cancel
          </button>
          {!isNew && medication && (
            <button
              type="button"
              className="ml-auto text-xs font-semibold text-rose-700"
              onClick={() => {
                if (
                  confirm(`Delete ${medication.name} and all its schedules?`)
                ) {
                  void deleteMedication(medication.id).then(onClose)
                }
              }}
            >
              Delete
            </button>
          )}
        </div>
      </form>
    </Sheet>
  )
}
