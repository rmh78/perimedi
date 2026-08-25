import { useRef, useState } from 'react'
import { clearAllData, loadSampleData } from '../lib/seed'
import {
  downloadJson,
  exportAllData,
  importAllData,
} from '../lib/backup'
import type { ExportPayload } from '../types'
import { useLocale, type Locale } from '../i18n'
import { useConfirm } from '../context/ConfirmContext'

const sectionShell =
  'rounded-xl ring-1 ring-blush-100 bg-white/40 px-2.5 py-2.5 space-y-2'
const sectionTitle =
  'text-[11px] font-semibold uppercase tracking-wide text-ink-muted'

/** Compact size shared with Month / Cycle header controls. */
const pageBtn = '!min-h-9 !px-3'

/** Language + backup tools — full More page content. */
export function MorePanel() {
  const { t, locale, setLocale } = useLocale()
  const confirm = useConfirm()
  const fileRef = useRef<HTMLInputElement>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  return (
    <div className="space-y-3">
      <section className={sectionShell}>
        <p className={sectionTitle}>{t('language.label')}</p>
        <div className="flex flex-wrap gap-1.5">
          {(['en', 'de'] as const).map((code) => (
            <button
              key={code}
              type="button"
              className={`${pageBtn} ${
                locale === code ? 'btn-primary' : 'btn-ghost'
              }`}
              onClick={() => setLocale(code as Locale)}
              aria-pressed={locale === code}
            >
              {t(code === 'en' ? 'language.en' : 'language.de')}
            </button>
          ))}
        </div>
      </section>

      {(message || error) && (
        <div
          className={`rounded-xl px-2.5 py-1.5 text-xs ${
            error
              ? 'bg-rose-50 text-rose-900'
              : 'bg-emerald-50 text-emerald-900'
          }`}
        >
          {error ?? message}
        </div>
      )}

      <section className={sectionShell}>
        <p className={sectionTitle}>{t('more.tabBackup')}</p>
        <div className="-mx-2.5 -mb-2.5 overflow-hidden rounded-b-xl">
          <Action
            title={t('more.sampleTitle')}
            body={t('more.sampleBody')}
            label={t('more.sampleLabel')}
            onClick={async () => {
              const ok = await confirm({
                message: t('more.sampleConfirm'),
                confirmLabel: t('more.sampleLabel'),
              })
              if (!ok) return
              await loadSampleData()
              setMessage(t('more.sampleLoaded'))
              setError(null)
            }}
          />
          <Action
            title={t('more.exportTitle')}
            body={t('more.exportBody')}
            label={t('more.exportLabel')}
            onClick={async () => {
              try {
                downloadJson(await exportAllData())
                setMessage(t('more.exportDone'))
                setError(null)
              } catch (e) {
                setError(
                  e instanceof Error ? e.message : t('more.exportFailed'),
                )
              }
            }}
          />
          <Action
            title={t('more.importTitle')}
            body={t('more.importBody')}
            label={t('more.importLabel')}
            onClick={() => fileRef.current?.click()}
          />
          <Action
            title={t('more.clearTitle')}
            body={t('more.clearBody')}
            label={t('more.clearLabel')}
            danger
            last
            onClick={async () => {
              const ok = await confirm({
                message: t('more.clearConfirm'),
                confirmLabel: t('more.clearLabel'),
                danger: true,
              })
              if (!ok) return
              await clearAllData()
              setMessage(t('more.cleared'))
              setError(null)
            }}
          />
        </div>
        <input
          ref={fileRef}
          type="file"
          accept="application/json,.json"
          className="hidden"
          onChange={async (e) => {
            const file = e.target.files?.[0]
            if (!file) return
            try {
              const payload = JSON.parse(await file.text()) as ExportPayload
              await importAllData(payload)
              setMessage(t('more.importDone'))
              setError(null)
            } catch (err) {
              setError(
                err instanceof Error ? err.message : t('more.importFailed'),
              )
            }
            e.target.value = ''
          }}
        />
      </section>
    </div>
  )
}

function Action({
  title,
  body,
  label,
  onClick,
  danger,
  last,
}: {
  title: string
  body: string
  label: string
  onClick: () => void | Promise<void>
  danger?: boolean
  last?: boolean
}) {
  return (
    <div
      className={`flex items-center gap-2 px-2.5 py-2 ${
        last ? '' : 'border-b border-blush-100/80'
      }`}
    >
      <div className="min-w-0 flex-1">
        <p className="text-xs font-semibold text-ink">{title}</p>
        <p className="mt-0.5 text-[10px] leading-snug text-ink-soft">{body}</p>
      </div>
      <button
        type="button"
        onClick={() => void onClick()}
        className={`shrink-0 ${pageBtn} ${danger ? 'btn-soft' : 'btn-ghost'}`}
      >
        {label}
      </button>
    </div>
  )
}
