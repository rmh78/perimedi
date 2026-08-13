/**
 * Multi-viewport screenshots for layout review.
 *
 *   npm run preview   # or: npm run dev
 *   npm run shot:responsive
 *
 * Override: BASE_URL=http://127.0.0.1:4173
 */

import { chromium } from 'playwright'
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

const VIEWPORTS = [
  { name: '375-se', width: 375, height: 667, mobile: true },
  { name: '390-iphone', width: 390, height: 844, mobile: true },
  { name: '768-tablet', width: 768, height: 1024, mobile: true },
  { name: '1280-desktop', width: 1280, height: 800, mobile: false },
]

const TABS = [
  { path: '/', name: 'cycle' },
  { path: '/month', name: 'month' },
  { path: '/more', name: 'more' },
]

async function shot(page, name) {
  const file = path.join(outDir, `${name}.png`)
  await page.screenshot({ path: file, fullPage: false })
  console.log(`  wrote ${path.relative(root, file)}`)
}

async function loadSample(page) {
  await page.goto(BASE_URL + '/more', { waitUntil: 'networkidle' })
  await page.waitForTimeout(300)
  const load = page.getByRole('button', {
    name: /Load sample|Beispiel laden/i,
  })
  if (!(await load.count())) return false
  await load.first().click()
  const dlg = page.getByRole('alertdialog')
  if (await dlg.count()) {
    await dlg
      .getByRole('button', { name: /Load sample|Beispiel laden/i })
      .click()
  }
  await page.waitForTimeout(800)
  return true
}

async function main() {
  await mkdir(outDir, { recursive: true })
  console.log(`Responsive shots → ${path.relative(root, outDir)}/`)
  console.log(`BASE_URL=${BASE_URL}`)

  const browser = await chromium.launch({ headless: true })

  try {
    for (const vp of VIEWPORTS) {
      const context = await browser.newContext({
        viewport: { width: vp.width, height: vp.height },
        deviceScaleFactor: vp.mobile ? 2 : 1,
        isMobile: vp.mobile,
        hasTouch: vp.mobile,
        locale: 'en-US',
      })
      const page = await context.newPage()
      await page.goto(BASE_URL + '/', {
        waitUntil: 'networkidle',
        timeout: 30_000,
      })
      await page.getByRole('heading', { name: 'PeriMedi' }).waitFor({
        timeout: 15_000,
      })
      await loadSample(page)

      for (const tab of TABS) {
        await page.goto(BASE_URL + tab.path, { waitUntil: 'networkidle' })
        await page.waitForTimeout(500)
        await shot(page, `${vp.name}-${tab.name}`)
      }

      if (vp.name === '375-se') {
        const scroller = page.locator('[data-cycle-plot-scroll]')
        await page.goto(BASE_URL + '/', { waitUntil: 'networkidle' })
        await page.waitForTimeout(400)
        if (await scroller.count()) {
          await scroller.evaluate((el) => {
            const max = el.scrollWidth - el.clientWidth
            el.scrollLeft = Math.max(0, Math.floor(max * 0.4))
          })
          await page.waitForTimeout(250)
          await shot(page, '375-se-cycle-scrolled')
        }
      }

      await context.close()
    }
    console.log('Done.')
  } catch (err) {
    console.error('\nScreenshot run failed.')
    console.error(err instanceof Error ? err.message : err)
    process.exitCode = 1
  } finally {
    await browser.close()
  }
}

main()
