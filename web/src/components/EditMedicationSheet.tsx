import { useEffect, useState, type FormEvent } from 'react'
import { Sheet } from './Sheet'
import type { Medication, MedForm } from '../types'
import { useLocale, type MessageKey } from '../i18n'
import { useConfirm } from '../context/ConfirmContext'
import {
  deleteMedication,
  upsertMedication,
  upsertSchedule,
} from '../db/actions'
import { useSchedules } from '../hooks/useAppData'
import { normalizeTherapyCycle } from '../lib/therapyCycle'
import {
  MED_COLOR_PALETTE,
  MED_FORM_ICON_COLOR,
  resolveMedColor,
} from '../lib/medColors'
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
  const { t } = useLocale()
  const confirm = useConfirm()
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

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (!name.trim() || !doseLabel.trim()) {
      setError(t('med.errorNameDose'))
      return
    }
    if (!sched.times.length || !sched.times[0]) {
      setError(t('med.errorTime'))
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
        remindersEnabled: medication?.remindersEnabled,
      })

      const isCyclic = schedMode === 'cyclic'
      const daysOfWeek =
        schedMode === 'specific_days' ? sched.daysOfWeek : []

      const anchor = sched.anchorDate || sched.startDate || todayKey()
      const therapyCycle = normalizeTherapyCycle(
        isCyclic
          ? {
              enabled: true,
              mode: 'on_off_days',
              anchorDate: anchor,
              onDays: sched.onDays,
              offDays: sched.offDays,
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
        remindersEnabled: medication?.remindersEnabled ?? true,
      })
    } catch (err) {
      setError(err instanceof Error ? err.message : t('med.errorSave'))
    } finally {
      setSaving(false)
    }
  }

  return (
    <Sheet
      open={open}
      title={isNew || !medication ? t('med.addTitle') : t('med.editTitle')}
      icon="/action-icons/med.jpg"
      iconAccent={color}
      onClose={onClose}
      wide
    >
      <form onSubmit={onSubmit} className="space-y-3 text-sm">
        {/* Medication — dense grid */}
        <section className="space-y-2">
          <label className="block">
            <span className="mb-0.5 block text-xs font-medium text-ink-soft">
              {t('med.name')}
            </span>
            <input
              className="soft-input !rounded-xl !px-2.5 !py-1.5"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
            />
          </label>
          <div className="grid grid-cols-2 gap-2">
            <label className="block">
              <span className="mb-0.5 block text-xs font-medium text-ink-soft">
                {t('med.form')}
              </span>
              <select
                className="soft-input !rounded-xl !px-2.5 !py-1.5"
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
                {(['PILL', 'CREAM', 'DROPS', 'INJECTION', 'OTHER'] as MedForm[]).map((k) => (
                  <option key={k} value={k}>
                    {t(`form.${k}` as MessageKey)}
                  </option>
                ))}
              </select>
            </label>
            <label className="block">
              <span className="mb-0.5 block text-xs font-medium text-ink-soft">
                {t('med.defaultDose')}
              </span>
              <input
                className="soft-input !rounded-xl !px-2.5 !py-1.5"
                value={doseLabel}
                onChange={(e) => setDoseLabel(e.target.value)}
                required
                placeholder={t('med.dosePlaceholder')}
              />
            </label>
          </div>
          <div>
            <p className="mb-0.5 text-xs font-medium text-ink-soft">{t('med.color')}</p>
            <div
            className="flex min-w-0 gap-1"
            role="group"
            aria-label={t('med.color')}
          >
            {MED_COLOR_PALETTE.map((c) => {
              const selected = color.toLowerCase() === c.toLowerCase()
              return (
                <button
                  key={c}
                  type="button"
                  title={c}
                  onClick={() => setColor(c)}
                  className="h-[18px] min-w-0 flex-1 rounded-full"
                  style={{
                    background: c,
                    boxShadow: selected
                      ? `0 0 0 2px #fff, 0 0 0 3px ${c}`
                      : '0 0 0 1px rgba(0,0,0,0.1)',
                  }}
                  aria-label={t('med.colorAria', { color: c })}
                  aria-pressed={selected}
                />
              )
            })}
            </div>
          </div>
        </section>

        {/* Schedule */}
        <section className="space-y-2 border-t border-blush-100 pt-3">
          <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-muted">
            {t('med.sectionSchedule')}
          </p>

          <div className="grid grid-cols-2 gap-2">
            <label className="block">
              <span className="mb-0.5 block text-xs font-medium text-ink-soft">
                {t('med.start')}
              </span>
              <input
                type="date"
                className="soft-input !rounded-xl !px-2 !py-1.5"
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
                {t('med.endOptional')}
              </span>
              <input
                type="date"
                className="soft-input !rounded-xl !px-2 !py-1.5"
                value={sched.endDate}
                onChange={(e) =>
                  setSched((f) => ({ ...f, endDate: e.target.value }))
                }
              />
            </label>
          </div>

          <div>
            <p className="mb-0.5 text-xs font-medium text-ink-soft">{t('med.takeAt')}</p>
            <div className="flex flex-wrap items-center gap-1.5">
            {sched.times.map((time, i) => (
              <div key={i} className="flex items-center gap-1">
                <input
                  type="time"
                  className="soft-input !w-auto !rounded-lg !px-2 !py-1"
                  value={time}
                  onChange={(e) =>
                    setSched((f) => {
                      const times = [...f.times]
                      times[i] = e.target.value
                      return { ...f, times }
                    })
                  }
                  required
                  aria-label={t('med.doseTimeAria', { n: i + 1 })}
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
                    aria-label={t('med.removeTimeAria', { n: i + 1 })}
                  >
                    ×
                  </button>
                )}
              </div>
            ))}
            <button
              type="button"
              className="text-sm font-semibold text-blush-700"
              onClick={() =>
                setSched((f) => ({ ...f, times: [...f.times, '12:00'] }))
              }
              aria-label={t('med.anotherTime')}
            >
              +
            </button>
            </div>
          </div>

          <label className="block">
            <span className="mb-0.5 block text-xs font-medium text-ink-soft">
              {t('med.scheduleType')}
            </span>
            <select
            className="soft-input !w-auto !rounded-xl !px-2.5 !py-1.5"
            value={schedMode}
            onChange={(e) => {
              const mode = e.target.value as typeof schedMode
              setSchedMode(mode)
              if (mode === 'cyclic') {
                setSched((f) => ({
                  ...f,
                  daysOfWeek: [],
                  cyclic: true,
                  therapyPreset: 'custom_days',
                  onDays: f.onDays || 21,
                  offDays: f.offDays || 7,
                  anchorDate: f.anchorDate || f.startDate,
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
          >
            <option value="every_day">{t('sched.everyDay')}</option>
            <option value="specific_days">{t('sched.specificDays')}</option>
            <option value="cyclic">{t('sched.cyclic')}</option>
            </select>
          </label>

          {schedMode === 'specific_days' && (
            <div>
              <p className="mb-0.5 text-xs font-medium text-ink-soft">{t('med.days')}</p>
              <div className="flex flex-wrap gap-1">
                {([0, 1, 2, 3, 4, 5, 6] as const).map((idx) => {
                  const label = t(`weekday.${idx}` as MessageKey)
                  const on = sched.daysOfWeek.includes(idx)
                  return (
                    <button
                      key={idx}
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
            <div className="grid grid-cols-2 gap-2">
              <label className="block">
                <span className="mb-0.5 block text-xs font-medium text-ink-soft">
                  {t('med.applyDays')}
                </span>
                <input
                  type="number"
                  min={1}
                  max={60}
                  className="soft-input !rounded-xl !px-2.5 !py-1.5"
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
                  {t('med.pauseDays')}
                </span>
                <input
                  type="number"
                  min={1}
                  max={60}
                  className="soft-input !rounded-xl !px-2.5 !py-1.5"
                  value={sched.offDays}
                  onChange={(e) =>
                    setSched((f) => ({
                      ...f,
                      offDays: Number(e.target.value) || 1,
                      therapyPreset: 'custom_days',
                    }))
                  }
                />
              </label>
            </div>
          )}

          {!isNew && medSchedules.length > 1 && (
            <p className="text-[11px] text-ink-muted">
              {t('med.multiScheduleNote', { count: medSchedules.length })}
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
            {saving ? t('common.saving') : isNew ? t('med.saveNew') : t('med.saveChanges')}
          </button>
          <button
            type="button"
            className="btn-ghost !px-3 !py-1.5 text-sm"
            onClick={onClose}
          >
            {t('common.cancel')}
          </button>
          {!isNew && medication && (
            <button
              type="button"
              className="btn-soft ml-auto !min-h-9 !px-3"
              onClick={() => {
                void confirm({
                  message: t('med.deleteConfirm', { name: medication.name }),
                  danger: true,
                }).then((ok) => {
                  if (ok) void deleteMedication(medication.id).then(onClose)
                })
              }}
            >
              {t('common.delete')}
            </button>
          )}
        </div>
      </form>
    </Sheet>
  )
}
