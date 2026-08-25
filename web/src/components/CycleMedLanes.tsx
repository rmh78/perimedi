import type { PlannedDose } from '../types'
import { setDoseStatus } from '../db/actions'
import { useLocale } from '../i18n'
import {
  CYCLE_DOSE_META_MAX_WIDTH_PX,
  CYCLE_DOSE_META_STICKY_LEFT_PX,
  CYCLE_MED_RING_PX,
} from '../lib/cycleLayout'
import { iconBgFromColor, takenFillFromColor } from '../lib/medColors'
import type { DoseSegment, MedLane } from '../lib/medSegments'
import type { DayColumn, TakenState } from './cycleTypes'
import { MedFormIcon } from './MedFormIcon'

const MED_RING_PX = CYCLE_MED_RING_PX

function takenStateFromDoses(dayDoses: PlannedDose[]): TakenState {
  if (dayDoses.length === 0) return null
  return dayDoses.every((d) => d.status === 'taken') ? 'taken' : 'open'
}

export function MedLaneLabel({
  lane,
  dayDoses,
  onEdit,
}: {
  lane: MedLane
  dayDoses: PlannedDose[]
  onEdit?: () => void
}) {
  const { t } = useLocale()
  const color = lane.color
  const state = takenStateFromDoses(dayDoses)
  const isTaken = state === 'taken'
  const hasDose = state != null

  async function toggleTaken() {
    if (!hasDose) return
    const next = isTaken ? 'pending' : 'taken'
    await Promise.all(
      dayDoses.map((dose) =>
        setDoseStatus({
          medicationId: dose.medication.id,
          scheduleId: dose.schedule.id,
          date: dose.date,
          timeOfDay: dose.timeOfDay,
          status: next,
          existingLogId: dose.log?.id,
        }),
      ),
    )
  }

  const ring = isTaken ? color : hasDose ? `${color}99` : '#f0d0da'
  const statusLabel = isTaken
    ? t('diagram.taken')
    : hasDose
      ? t('diagram.notTaken')
      : t('diagram.noDose')
  const statusColor = isTaken ? color : hasDose ? '#64748b' : undefined

  return (
    <div className="flex w-full min-w-0 items-center gap-1.5 py-1">
      {/*
        Ring is a padded wrapper (not box-shadow): horizontal scrollports clip
        outer shadows on sticky labels, which made the left side of the circle vanish.
      */}
      <span
        className={`relative shrink-0 rounded-full ${
          hasDose ? '' : 'opacity-70'
        }`}
        style={{
          padding: MED_RING_PX,
          background: ring,
        }}
      >
        <button
          type="button"
          disabled={!hasDose}
          onClick={toggleTaken}
          title={
            hasDose
              ? isTaken
                ? t('diagram.markNotTaken', { name: lane.name })
                : t('diagram.markTaken', { name: lane.name })
              : `${lane.name}: ${t('diagram.noDose')}`
          }
          aria-pressed={hasDose ? isTaken : undefined}
          aria-label={
            hasDose
              ? `${lane.name}: ${statusLabel}`
              : `${lane.name}: ${t('diagram.noDose')}`
          }
          className={`relative block h-10 w-10 overflow-hidden rounded-full transition ${
            hasDose
              ? 'cursor-pointer hover:scale-105 active:scale-95'
              : 'cursor-default'
          }`}
          style={{
            background: iconBgFromColor(color, 0.35),
          }}
        >
          <MedFormIcon form={lane.form} fill />
        </button>
        {isTaken && (
          <span
            className="absolute -bottom-0.5 -right-0.5 z-10 flex h-5 w-5 items-center justify-center rounded-full text-[10px] font-bold text-white ring-2 ring-white shadow-sm"
            style={{ background: color }}
            aria-hidden
          >
            ✓
          </span>
        )}
      </span>

      {onEdit ? (
        <button
          type="button"
          className="group min-w-0 flex-1 text-left"
          title={t('diagram.editMed', { name: lane.name })}
          onClick={onEdit}
        >
          <p className="line-clamp-2 break-words text-left text-[12px] font-semibold leading-snug text-ink underline-offset-2 group-hover:underline sm:text-sm">
            {lane.name}
          </p>
          <p
            className="mt-0.5 text-[10px] font-semibold leading-tight"
            style={{ color: statusColor ?? undefined }}
          >
            {statusLabel === t('diagram.noDose') ? (
              <span className="font-medium text-ink-muted">{statusLabel}</span>
            ) : (
              statusLabel
            )}
          </p>
        </button>
      ) : (
        <div className="min-w-0 flex-1 text-left">
          <p className="line-clamp-2 break-words text-[12px] font-semibold leading-snug text-ink sm:text-sm">
            {lane.name}
          </p>
          <p
            className="mt-0.5 text-[10px] font-semibold leading-tight"
            style={{ color: statusColor ?? undefined }}
          >
            {statusLabel === t('diagram.noDose') ? (
              <span className="font-medium text-ink-muted">{statusLabel}</span>
            ) : (
              statusLabel
            )}
          </p>
        </div>
      )}
    </div>
  )
}

function dayIsTaken(cell: {
  statuses: Array<'pending' | 'taken' | 'skipped'>
}) {
  return cell.statuses.length > 0 && cell.statuses.every((s) => s === 'taken')
}

/** Shared track chrome for every med — multi-day bands and single-day doses. */
export function MedLaneTrack({
  lane,
  cycleLen: _cycleLen,
  gridTemplate,
  columns,
  onSelectDay,
}: {
  lane: MedLane
  cycleLen: number
  gridTemplate: string
  columns: DayColumn[]
  onSelectDay: (col: DayColumn) => void
}) {
  const { t } = useLocale()
  const color = lane.color
  const byDay = new Map(lane.days.map((d) => [d.cycleDay, d]))
  const takenFill = takenFillFromColor(color, 0.42)

  return (
    <div className="relative">
      <div
        className="pointer-events-none grid min-h-11 items-stretch bg-gradient-to-r from-blush-50/40 to-lilac-50/30 py-[3px] ring-1 ring-blush-100/80"
        style={{
          gridTemplateColumns: gridTemplate,
        }}
      >
        {lane.segments.map((seg) => (
          <DoseBand
            key={`${seg.fromDay}-${seg.toDay}-${seg.doseLabel}`}
            segment={seg}
            color={color}
          />
        ))}
      </div>
      {/* Taken fill (med color) + day pick — min height ~44px for touch */}
      <div
        className="absolute inset-0 z-10 grid py-[3px]"
        style={{
          gridTemplateColumns: gridTemplate,
        }}
      >
        {columns.map((col) => {
          const cell = byDay.get(col.cycleDay)
          const taken = Boolean(cell && dayIsTaken(cell))
          return (
            <button
              key={col.cycleDay}
              type="button"
              disabled={!col.dateKey}
              onClick={() => onSelectDay(col)}
              title={
                cell
                  ? `${t('diagram.dayN', { day: col.cycleDay })}: ${cell.doseLabel}${
                      taken
                        ? ` · ${t('diagram.taken')}`
                        : ` · ${t('diagram.notTaken')}`
                    }`
                  : col.dateKey
                    ? `${t('diagram.dayN', { day: col.cycleDay })} · ${col.dateKey}`
                    : t('diagram.dayN', { day: col.cycleDay })
              }
              className={`min-h-0 px-0.5 ${
                !col.dateKey ? 'cursor-default' : 'cursor-pointer'
              }`}
            >
              <span
                className="block h-full min-h-11 w-full rounded-md transition hover:bg-blush-300/10"
                style={taken ? { background: takenFill } : undefined}
              />
            </button>
          )
        })}
      </div>
    </div>
  )
}

/**
 * Dose segment card. Dose + day meta is position:sticky so it stays visible
 * while the day grid scrolls horizontally (pinned just right of med labels).
 */
function DoseBand({
  segment,
  color,
}: {
  segment: DoseSegment
  color: string
}) {
  const { t } = useLocale()
  const span = segment.toDay - segment.fromDay + 1
  const narrow = span === 1

  const dayLine =
    segment.fromDay === segment.toDay
      ? t('diagram.dayN', { day: segment.fromDay })
      : t('diagram.daysRange', {
          from: segment.fromDay,
          to: segment.toDay,
        })

  const meta = `${segment.doseLabel} · ${dayLine}`

  return (
    <div
      title={meta}
      className="relative box-border flex min-h-11 min-w-0 flex-col justify-center overflow-visible rounded-md text-left"
      style={{
        gridColumn: `${segment.fromDay} / span ${span}`,
        margin: '0 1.5px',
        maxWidth: '100%',
        background: '#fffafb',
        border: `1px solid ${color}55`,
        boxShadow: '0 1px 2px rgba(61, 44, 51, 0.04)',
      }}
    >
      {narrow ? (
        <span className="sr-only">{meta}</span>
      ) : (
        <div
          className="sticky z-[25] box-border rounded px-1.5 py-0.5 backdrop-blur-[1px]"
          style={{
            left: CYCLE_DOSE_META_STICKY_LEFT_PX,
            maxWidth: CYCLE_DOSE_META_MAX_WIDTH_PX,
            // Semi-transparent so band color shows through behind the label
            background: 'color-mix(in srgb, #fffafb 55%, transparent)',
            borderLeft: `2px solid ${color}`,
          }}
        >
          <p className="truncate text-[11px] font-bold leading-snug text-[#3d2c33]">
            {segment.doseLabel}
          </p>
          <p className="truncate text-[10px] font-medium leading-tight text-[#6b5560]">
            {dayLine}
          </p>
        </div>
      )}
    </div>
  )
}
