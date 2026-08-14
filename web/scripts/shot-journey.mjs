/**
 * Empty-to-tracking 375×667 journey shots (OpenSpec ios-native-app §11).
 *
 *   npm --prefix web run dev
 *   npm --prefix web run shot:journey
 *
 * Writes web/shots/journey-01-empty.png … journey-12-month.png from a
 * cleared IndexedDB — never loads sample data.
 */

import { chromium, devices } from 'playwright'
import { mkdir } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const root = path.resolve(__dirname, '..')
const outDir = path.join(root, 'shots')

const BASE_URL = (process.env.BASE_URL || 'http://localhost:5173').replace(
  /\/$/,
  '',
)

const SE = {
  ...devices['iPhone SE'],
  viewport: { width: 375, height: 667 },
  deviceScaleFactor: 2,
  isMobile: true,
  hasTouch: true,
}

function addDaysKey(key, n) {
  const d = new Date(`${key}T12:00:00`)
  d.setDate(d.getDate() + n)
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

async function waitApp(page) {
  await page.goto(BASE_URL + '/', {
    waitUntil: 'networkidle',
    timeout: 30_000,
  })
  await page.getByRole('heading', { name: 'PeriMedi' }).waitFor({
    timeout: 15_000,
  })
  await page.waitForTimeout(250)
}

async function clearData(page) {
  await page.evaluate(async () => {
    localStorage.setItem('perimedi.locale', 'en')
    await new Promise((resolve, reject) => {
      const req = indexedDB.deleteDatabase('perimedi')
      req.onsuccess = () => resolve()
      req.onerror = () => reject(req.error)
      req.onblocked = () => resolve()
    })
  })
  await page.reload({ waitUntil: 'networkidle' })
  await page.getByRole('heading', { name: 'PeriMedi' }).waitFor({
    timeout: 15_000,
  })
  await page.waitForTimeout(400)
}

async function shot(page, name) {
  const file = path.join(outDir, `${name}.png`)
  await page.screenshot({ path: file, fullPage: false })
  console.log(`  wrote ${path.relative(root, file)}`)
}

async function fillLabeled(page, label, value) {
  const field = page.getByLabel(label, { exact: false }).first()
  await field.scrollIntoViewIfNeeded()
  await field.fill(value)
  await page.keyboard.press('Escape').catch(() => {})
}

async function fillDateInputs(page, start, end) {
  const dates = page.locator('input[type="date"]')
  await dates.nth(0).waitFor({ state: 'visible' })
  await dates.nth(0).fill(start)
  if (end != null && (await dates.count()) > 1) {
    await dates.nth(1).fill(end)
  }
}

async function addMedication(page, { name, form, dose, start, mode, preset }) {
  await page.getByRole('button', { name: '+ Med' }).click()
  const dlg = page.getByRole('dialog', { name: /medication/i })
  await dlg.waitFor({ timeout: 10_000 })
  await dlg.locator('input:not([type])').first().fill(name)
  await dlg.locator('select').first().selectOption(form)
  await dlg.getByPlaceholder('e.g. 10 mg').fill(dose)
  if (mode === 'cyclic') {
    await dlg.getByRole('button', { name: 'Cyclic' }).click()
    if (preset) await dlg.locator('select').nth(1).selectOption(preset)
  } else if (mode === 'specific_days') {
    await dlg.getByRole('button', { name: 'Specific days' }).click()
  } else {
    await dlg.getByRole('button', { name: 'Every day' }).click()
  }
  const startInput = dlg.locator('input[type="date"]').first()
  if (await startInput.count()) {
    await startInput.fill(start)
  }
  await dlg.getByRole('button', { name: 'Save medication' }).click()
  await dlg.waitFor({ state: 'hidden', timeout: 10_000 }).catch(() => {})
}

async function main() {
  await mkdir(outDir, { recursive: true })
  console.log(`Journey 375×667 → ${path.relative(root, outDir)}/`)
  console.log(`BASE_URL=${BASE_URL}`)

  const browser = await chromium.launch({ headless: true })
  const context = await browser.newContext({ ...SE, locale: 'en-US' })
  const page = await context.newPage()

  try {
    await waitApp(page)
    await clearData(page)

    const today = await page.evaluate(() => {
      const d = new Date()
      const y = d.getFullYear()
      const m = String(d.getMonth() + 1).padStart(2, '0')
      const day = String(d.getDate()).padStart(2, '0')
      return `${y}-${m}-${day}`
    })
    const periodStart = addDaysKey(today, -8)
    const periodEnd = addDaysKey(today, -4)

    await shot(page, 'journey-01-empty')

    await page.getByRole('button', { name: 'Cycle settings' }).click()
    await page.getByRole('button', { name: '+ Add period' }).click()
    await fillDateInputs(page, periodStart, periodEnd)
    await page.waitForTimeout(200)
    await shot(page, 'journey-02-period-dialog')

    await page.getByRole('button', { name: 'Add period' }).click()
    await page.getByRole('button', { name: 'Close' }).nth(1).click()
    await page.waitForTimeout(400)
    await shot(page, 'journey-03-period-saved')

    await addMedication(page, {
      name: 'Estrogen',
      form: 'PILL',
      dose: '1 mg',
      start: periodStart,
      mode: 'every_day',
    })
    await page.waitForTimeout(500)
    await shot(page, 'journey-04-med-everyday')

    await addMedication(page, {
      name: 'Progesterone',
      form: 'CREAM',
      dose: '200 mg',
      start: periodStart,
      mode: 'cyclic',
      preset: '21_7',
    })
    await page.waitForTimeout(500)
    await shot(page, 'journey-05-med-dated-or-cyclic')

    await page.getByTitle('Edit Estrogen').click()
    const editDlg = page.getByRole('dialog', { name: /medication/i })
    await editDlg.waitFor()
    await editDlg.getByPlaceholder('e.g. 10 mg').fill('2 mg')
    await editDlg.getByRole('button', { name: 'Save changes' }).click()
    await page.waitForTimeout(500)
    await shot(page, 'journey-06-edited')

    await page.getByTitle('Edit Progesterone').click()
    await page.getByRole('button', { name: 'Delete' }).click()
    const dlg = page.getByRole('alertdialog')
    if (await dlg.count()) {
      await dlg.getByRole('button', { name: /Delete/i }).click()
    }
    await page.waitForTimeout(500)
    await shot(page, 'journey-07-deleted')

    await page.getByRole('button', { name: 'Previous day' }).click()
    await page.waitForTimeout(300)
    await shot(page, 'journey-08-pager-prev')

    await page.getByRole('button', { name: 'Next day' }).click()
    await page.waitForTimeout(300)
    await shot(page, 'journey-09-pager-next')

    await page.getByTitle('Mark Estrogen as taken').click()
    await page.waitForTimeout(300)
    await shot(page, 'journey-10-taken')

    await page.getByRole('button', { name: '+ Symptom' }).click()
    await page.getByLabel('Description').fill('hot flush')
    await page.getByRole('button', { name: 'Add', exact: true }).click()
    await page.waitForTimeout(400)
    await shot(page, 'journey-11-symptom')

    await page.getByRole('navigation').getByRole('link', { name: /^Month$/ }).click()
    await page.waitForTimeout(400)
    await shot(page, 'journey-12-month')

    console.log('Done. Review PNGs under shots/journey-*.png')
  } catch (err) {
    console.error('\nJourney screenshot run failed.')
    console.error(err instanceof Error ? err.stack || err.message : err)
    process.exitCode = 1
  } finally {
    await browser.close()
  }
}

main()
