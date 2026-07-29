import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { Sheet } from './Sheet'
import type { CycleRule, Schedule, TherapyPresetId } from '../types'
import { THERAPY_PRESETS, WEEKDAY_SHORT } from '../types'
import { upsertSchedule } from '../db/actions'
import {
  freshScheduleForm,
  scheduleToForm,
  type SchedFormState,
} from '../lib/scheduleForm'
import { todayKey } from '../lib/dates'
import {
  formatPreviewDate,
  normalizeTherapyCycle,
  previewTherapyCycle,
} from '../lib/therapyCycle'

type Props = {
  open: boolean
  medicationId: string | null
  schedule: Schedule | null
  defaultDoseLabel?: string
  onClose: () => void
  onSaved: () => void
}

export function EditScheduleSheet({
  open,
  medicationId,
  schedule,
  defaultDoseLabel,
  onClose,
  onSaved,
}: Props) {
  const [form, setForm] = useState<SchedFormState>(freshScheduleForm)

  useEffect(() => {
    if (!open) return
    if (schedule) setForm(scheduleToForm(schedule))
    else setForm(freshScheduleForm())
  }, [open, schedule])

  const draft: Schedule = useMemo(
    () => ({
      id: schedule?.id ?? 'draft',
      medicationId: medicationId || '',
      daysOfWeek: form.daysOfWeek,
      timeOfDay: form.times[0] || '08:00',
      times: form.times,
      doseLabel: form.doseLabel || undefined,
      active: form.active,
      startDate: form.startDate || undefined,
      endDate: form.endDate || undefined,
      cycleRule: form.cycleRule,
      therapyCycle: form.cyclic
        ? {
            enabled: true,
            mode:
              form.therapyPreset === 'week_slots' ? 'week_slots' : 'on_off_days',
            anchorDate: form.anchorDate,
            onDays: form.onDays,
            offDays: form.offDays,
            slots:
              form.therapyPreset === 'week_slots' ? form.weekSlots : undefined,
          }
        : undefined,
    }),
    [form, medicationId, schedule],
  )

  const preview = useMemo(
    () => previewTherapyCycle(draft, todayKey()),
    [draft],
  )

  function applyTherapyPreset(id: TherapyPresetId) {
    const p = THERAPY_PRESETS.find((x) => x.id === id)
    if (!p) return
    if (id === 'continuous') {
      setForm((f) => ({ ...f, cyclic: false, therapyPreset: 'continuous' }))
      return
    }
    setForm((f) => ({
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
    if (!medicationId) return
    const anchor = form.anchorDate || form.startDate || todayKey()
    const therapyCycle = normalizeTherapyCycle(
      form.cyclic
        ? {
            enabled: true,
            mode:
              form.therapyPreset === 'week_slots'
                ? 'week_slots'
                : form.therapyPreset === 'continuous'
                  ? 'continuous'
                  : 'on_off_days',
            anchorDate: anchor,
            onDays: form.onDays,
            offDays: form.offDays,
            slots: form.weekSlots,
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
      id: schedule?.id,
      medicationId,
      daysOfWeek: form.daysOfWeek,
      times: form.times,
      doseLabel: form.doseLabel || undefined,
      active: form.active,
      startDate: form.startDate || undefined,
      endDate: form.endDate || undefined,
      cycleRule: form.cycleRule,
      cycleDayFrom:
        form.cycleRule === 'cycle_day_range' ? form.cycleDayFrom : undefined,
      cycleDayTo:
        form.cycleRule === 'cycle_day_range' ? form.cycleDayTo : undefined,
      therapyCycle,
    })
    onSaved()
  }

  return (
    <Sheet
      open={open}
      title={schedule ? 'Edit schedule' : 'Add schedule'}
      onClose={onClose}
      wide
    >
      <form onSubmit={onSubmit} className="space-y-4">
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={form.active}
            onChange={(e) =>
              setForm((f) => ({ ...f, active: e.target.checked }))
            }
          />
          Active
        </label>

        <section className="rounded-xl bg-blush-50/50 p-3 ring-1 ring-blush-100">
          <p className="text-sm font-semibold">Frequency</p>
          <p className="mb-2 text-xs text-ink-muted">
            Empty = every day
          </p>
          <div className="flex flex-wrap gap-1.5">
            {WEEKDAY_SHORT.map((label, idx) => {
              const on = form.daysOfWeek.includes(idx)
              return (
                <button
                  key={label}
                  type="button"
                  onClick={() =>
                    setForm((f) => ({
                      ...f,
                      daysOfWeek: on
                        ? f.daysOfWeek.filter((d) => d !== idx)
                        : [...f.daysOfWeek, idx].sort(),
                    }))
                  }
                  className={`rounded-full px-2.5 py-1 text-xs font-semibold ${
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
        </section>

        <section className="rounded-xl bg-blush-50/50 p-3 ring-1 ring-blush-100">
          <p className="text-sm font-semibold">At what time?</p>
          <div className="mt-2 space-y-2">
            {form.times.map((t, i) => (
              <div key={i} className="flex flex-wrap items-center gap-2">
                <input
                  type="time"
                  className="soft-input !w-auto"
                  value={t}
                  onChange={(e) =>
                    setForm((f) => {
                      const times = [...f.times]
                      times[i] = e.target.value
                      return { ...f, times }
                    })
                  }
                  required
                />
                {form.times.length > 1 && (
                  <button
                    type="button"
                    className="text-xs font-semibold text-rose-600"
                    onClick={() =>
                      setForm((f) => ({
                        ...f,
                        times: f.times.filter((_, j) => j !== i),
                      }))
                    }
                  >
                    Remove
                  </button>
                )}
              </div>
            ))}
          </div>
          <button
            type="button"
            className="mt-2 text-sm font-semibold text-blush-700"
            onClick={() =>
              setForm((f) => ({ ...f, times: [...f.times, '12:00'] }))
            }
          >
            + Add time
          </button>
          <label className="mt-3 block text-sm">
            Dose override (optional)
            <input
              className="soft-input mt-1"
              value={form.doseLabel}
              onChange={(e) =>
                setForm((f) => ({ ...f, doseLabel: e.target.value }))
              }
              placeholder={defaultDoseLabel}
            />
          </label>
        </section>

        <section className="rounded-xl bg-blush-50/50 p-3 ring-1 ring-blush-100">
          <div className="flex items-center justify-between gap-2">
            <p className="text-sm font-semibold">Cyclic schedule</p>
            <button
              type="button"
              className={`rounded-full px-3 py-1 text-xs font-semibold ${
                form.cyclic
                  ? 'bg-blush-600 text-white'
                  : 'bg-slate-200 text-slate-700'
              }`}
              onClick={() =>
                setForm((f) => ({
                  ...f,
                  cyclic: !f.cyclic,
                  therapyPreset: !f.cyclic ? '21_7' : 'continuous',
                  onDays: !f.cyclic ? 21 : f.onDays,
                  offDays: !f.cyclic ? 7 : f.offDays,
                }))
              }
            >
              {form.cyclic ? 'On' : 'Off'}
            </button>
          </div>

          {form.cyclic && (
            <div className="mt-3 space-y-3">
              <label className="block text-sm">
                Preset
                <select
                  className="soft-input mt-1"
                  value={form.therapyPreset}
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

              {form.therapyPreset !== 'week_slots' && (
                <div className="grid gap-3 sm:grid-cols-2">
                  <label className="text-sm font-medium">
                    Apply (days)
                    <input
                      type="number"
                      min={1}
                      max={365}
                      className="soft-input mt-1"
                      value={form.onDays}
                      onChange={(e) =>
                        setForm((f) => ({
                          ...f,
                          onDays: Number(e.target.value) || 1,
                          therapyPreset: 'custom_days',
                        }))
                      }
                    />
                  </label>
                  <label className="text-sm font-medium">
                    Pause (days)
                    <input
                      type="number"
                      min={0}
                      max={365}
                      className="soft-input mt-1"
                      value={form.offDays}
                      onChange={(e) =>
                        setForm((f) => ({
                          ...f,
                          offDays: Number(e.target.value) || 0,
                          therapyPreset: 'custom_days',
                        }))
                      }
                    />
                  </label>
                </div>
              )}

              {form.therapyPreset === 'week_slots' && (
                <div className="space-y-2">
                  {form.weekSlots.map((slot, idx) => (
                    <div
                      key={idx}
                      className="grid gap-2 rounded-xl bg-white/80 p-2 sm:grid-cols-[auto_1fr]"
                    >
                      <button
                        type="button"
                        onClick={() =>
                          setForm((f) => ({
                            ...f,
                            weekSlots: f.weekSlots.map((s, i) =>
                              i === idx ? { ...s, take: !s.take } : s,
                            ),
                          }))
                        }
                        className={`rounded-full px-3 py-1.5 text-xs font-semibold ${
                          slot.take
                            ? 'bg-emerald-600 text-white'
                            : 'bg-slate-300 text-slate-800'
                        }`}
                      >
                        {slot.take ? 'Apply' : 'Pause'}
                      </button>
                      <input
                        className="soft-input text-sm"
                        placeholder="Dose (optional)"
                        disabled={!slot.take}
                        value={slot.doseLabel ?? ''}
                        onChange={(e) =>
                          setForm((f) => ({
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

              <label className="block text-sm">
                Cycle starts on
                <input
                  type="date"
                  className="soft-input mt-1"
                  value={form.anchorDate}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, anchorDate: e.target.value }))
                  }
                />
              </label>

              <div className="rounded-xl bg-white/90 px-3 py-2 text-xs text-ink-soft ring-1 ring-blush-100">
                <p className="font-semibold text-ink">{preview.label}</p>
                <p className="mt-1">
                  Next pause:{' '}
                  <span className="font-semibold text-blush-800">
                    {formatPreviewDate(preview.nextPauseStart)}
                  </span>
                </p>
                <p>
                  Next apply:{' '}
                  <span className="font-semibold text-blush-800">
                    {formatPreviewDate(preview.nextApplyStart)}
                  </span>
                </p>
              </div>
            </div>
          )}
        </section>

        <section className="rounded-xl bg-blush-50/50 p-3 ring-1 ring-blush-100">
          <p className="text-sm font-semibold">Duration</p>
          <div className="mt-2 grid gap-3 sm:grid-cols-2">
            <label className="text-sm">
              Start
              <input
                type="date"
                className="soft-input mt-1"
                value={form.startDate}
                onChange={(e) =>
                  setForm((f) => ({
                    ...f,
                    startDate: e.target.value,
                    anchorDate: f.cyclic
                      ? f.anchorDate || e.target.value
                      : f.anchorDate,
                  }))
                }
              />
            </label>
            <label className="text-sm">
              End (optional)
              <input
                type="date"
                className="soft-input mt-1"
                value={form.endDate}
                onChange={(e) =>
                  setForm((f) => ({ ...f, endDate: e.target.value }))
                }
              />
            </label>
          </div>
        </section>

        <section className="rounded-xl bg-blush-50/50 p-3 ring-1 ring-blush-100">
          <p className="text-sm font-semibold">Menstrual alignment (optional)</p>
          <label className="mt-2 block text-sm">
            Rule
            <select
              className="soft-input mt-1"
              value={form.cycleRule}
              onChange={(e) =>
                setForm((f) => ({
                  ...f,
                  cycleRule: e.target.value as CycleRule,
                }))
              }
            >
              <option value="none">None</option>
              <option value="period_only">Period days only</option>
              <option value="cycle_day_range">Cycle day range</option>
            </select>
          </label>
          {form.cycleRule === 'cycle_day_range' && (
            <div className="mt-2 grid gap-2 sm:grid-cols-2">
              <label className="text-sm">
                From day
                <input
                  type="number"
                  min={1}
                  max={45}
                  className="soft-input mt-1"
                  value={form.cycleDayFrom}
                  onChange={(e) =>
                    setForm((f) => ({
                      ...f,
                      cycleDayFrom: Number(e.target.value),
                    }))
                  }
                />
              </label>
              <label className="text-sm">
                To day
                <input
                  type="number"
                  min={1}
                  max={45}
                  className="soft-input mt-1"
                  value={form.cycleDayTo}
                  onChange={(e) =>
                    setForm((f) => ({
                      ...f,
                      cycleDayTo: Number(e.target.value),
                    }))
                  }
                />
              </label>
            </div>
          )}
        </section>

        <div className="flex flex-wrap gap-2">
          <button type="submit" className="btn-primary">
            Save schedule
          </button>
          <button type="button" className="btn-ghost" onClick={onClose}>
            Cancel
          </button>
        </div>
      </form>
    </Sheet>
  )
}
