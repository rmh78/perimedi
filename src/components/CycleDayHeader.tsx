import { parseISO } from 'date-fns'
import type { ReactNode } from 'react'
import type { Remark } from '../types'
import { deleteRemark } from '../db/actions'
import { useConfirm } from '../context/ConfirmContext'
import { useLocale } from '../i18n'
import { IconDrop, IconPlusMed, IconSparkPlus } from './Icons'
import type { DayColumn } from './cycleTypes'

type Props = {
  selectedCol: DayColumn | null
  selectedSymptoms: Remark[]
  canPagePrev: boolean
  canPageNext: boolean
  onPageDay: (delta: -1 | 1) => void
  onGoToToday: () => void
  onAddMedication?: () => void
  onAddSymptom?: (dateKey: string) => void
  onOpenPeriodSettings: () => void
}

export function CycleDayHeader({
  selectedCol,
  selectedSymptoms,
  canPagePrev,
  canPageNext,
  onPageDay,
  onGoToToday,
  onAddMedication,
  onAddSymptom,
  onOpenPeriodSettings,
}: Props) {
  const { t, formatDate } = useLocale()
  const confirm = useConfirm()

  return (
    <div className="border-b border-blush-100/80 px-3 py-2 sm:px-5 sm:py-3">
      <div className="flex flex-wrap items-center gap-x-1 gap-y-1.5">
        {selectedCol ? (
          <div className="flex min-w-0 flex-1 basis-full items-center sm:basis-0">
            <button
              type="button"
              className="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-blush-700 transition hover:bg-blush-100 disabled:pointer-events-none disabled:opacity-35"
              aria-label={t('diagram.prevDay')}
              title={t('diagram.prevDay')}
              disabled={!canPagePrev}
              onClick={() => onPageDay(-1)}
            >
              <ChevronLeftIcon />
            </button>
            <p className="min-w-0 flex-1 truncate text-center text-sm font-semibold text-ink">
              {t('diagram.dayBadge', { day: selectedCol.cycleDay })}
              {selectedCol.dateKey
                ? ` · ${formatDate(parseISO(selectedCol.dateKey), 'EEE, MMM d')}`
                : ''}
            </p>
            <button
              type="button"
              className="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-blush-700 transition hover:bg-blush-100 disabled:pointer-events-none disabled:opacity-35"
              aria-label={t('diagram.nextDay')}
              title={t('diagram.nextDay')}
              disabled={!canPageNext}
              onClick={() => onPageDay(1)}
            >
              <ChevronRightIcon />
            </button>
          </div>
        ) : (
          <div className="min-w-0 flex-1 basis-full sm:basis-0" />
        )}

        <div className="ml-auto flex shrink-0 items-center gap-0.5">
          <button
            type="button"
            className="btn-ghost !min-h-9 shrink-0 !px-2.5 !py-1.5 text-xs"
            onClick={onGoToToday}
          >
            {t('common.today')}
          </button>
          {onAddMedication && (
            <DayActionIconButton
              label={t('diagram.addMed')}
              onClick={onAddMedication}
            >
              <IconPlusMed />
            </DayActionIconButton>
          )}
          <DayActionIconButton
            label={t('diagram.cycleSettings')}
            onClick={onOpenPeriodSettings}
          >
            <IconDrop />
          </DayActionIconButton>
          {onAddSymptom && selectedCol?.dateKey && (
            <DayActionIconButton
              label={t('diagram.addSymptom')}
              onClick={() => onAddSymptom(selectedCol.dateKey!)}
            >
              <IconSparkPlus />
            </DayActionIconButton>
          )}
        </div>
      </div>

      {selectedCol &&
        (selectedCol.isLoggedPeriod ||
          selectedCol.info?.isPredictedPeriod ||
          selectedSymptoms.length > 0) && (
          <div className="mt-1.5 flex min-w-0 flex-col gap-1">
            <div className="flex flex-wrap items-center gap-1.5">
              {selectedCol.isLoggedPeriod ? (
                <span className="inline-flex items-center gap-1.5 rounded-full bg-rose-100 px-2.5 py-1 text-xs font-semibold leading-none text-rose-800 ring-1 ring-rose-200">
                  <span className="h-2 w-2 rounded-full bg-rose-500" />
                  {t('diagram.periodTitle')}
                </span>
              ) : selectedCol.info?.isPredictedPeriod ? (
                <span className="inline-flex items-center gap-1.5 rounded-full bg-rose-50 px-2.5 py-1 text-xs font-semibold leading-none text-rose-700 ring-1 ring-rose-100">
                  <span className="h-2 w-2 rounded-full bg-rose-300" />
                  {t('diagram.predictedPeriodTitle')}
                </span>
              ) : null}
            </div>
            {selectedSymptoms.length > 0 && (
              <div className="flex min-w-0 flex-wrap items-center gap-1.5">
                {selectedSymptoms.map((s) => (
                  <div
                    key={s.id}
                    className="inline-flex max-w-full min-w-0 items-center gap-1 rounded-full bg-violet-50 py-1 pl-2.5 pr-1 text-xs font-medium leading-none text-violet-900 ring-1 ring-violet-100"
                  >
                    <button
                      type="button"
                      className="inline-flex min-w-0 max-w-full items-center gap-1.5 text-left leading-none transition hover:text-violet-700"
                      title={s.body}
                      onClick={() => {
                        if (onAddSymptom && selectedCol.dateKey) {
                          onAddSymptom(selectedCol.dateKey)
                        }
                      }}
                    >
                      <span className="h-2 w-2 shrink-0 rounded-full bg-violet-400" />
                      <span className="min-w-0 truncate leading-none">
                        {s.body}
                      </span>
                    </button>
                    <button
                      type="button"
                      className="inline-flex h-4 w-4 shrink-0 items-center justify-center rounded-full text-sm leading-none text-violet-700 transition hover:bg-violet-100"
                      aria-label={t('common.delete')}
                      title={t('common.delete')}
                      onClick={() => {
                        void confirm({
                          message: t('symptom.deleteConfirm'),
                          danger: true,
                        }).then((ok) => {
                          if (ok) void deleteRemark(s.id)
                        })
                      }}
                    >
                      ×
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
    </div>
  )
}

function DayActionIconButton({
  label,
  onClick,
  children,
}: {
  label: string
  onClick: () => void
  children: ReactNode
}) {
  return (
    <button
      type="button"
      className="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-white text-blush-800 ring-1 ring-blush-100 transition hover:bg-blush-50"
      aria-label={label}
      title={label}
      onClick={onClick}
    >
      {children}
    </button>
  )
}

function ChevronLeftIcon() {
  return (
    <svg
      viewBox="0 0 20 20"
      fill="none"
      className="h-5 w-5"
      aria-hidden
    >
      <path
        d="M12.5 4.5 7 10l5.5 5.5"
        stroke="currentColor"
        strokeWidth="1.75"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  )
}

function ChevronRightIcon() {
  return (
    <svg
      viewBox="0 0 20 20"
      fill="none"
      className="h-5 w-5"
      aria-hidden
    >
      <path
        d="M7.5 4.5 13 10l-5.5 5.5"
        stroke="currentColor"
        strokeWidth="1.75"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  )
}
