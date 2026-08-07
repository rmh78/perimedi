/**
 * iPhone SE (375×667) screenshots for multi-screen bottom-nav layout review.
 *
 *   npm run dev   # or preview
 *   npm run shot:se
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

const TABS = [
  { path: '/', name: '01-today', nav: /Today|Heute/i },
  { path: '/cycle', name: '02-cycle', nav: /Cycle|Zyklus/i },
  { path: '/month', name: '03-month', nav: /Month|Monat/i },
  { path: '/more', name: '04-more', nav: /^More$|^Mehr$/i },
]

async function waitApp(page) {
  await page.goto(BASE_URL + '/', {
    waitUntil: 'networkidle',
    timeout: 30_000,
  })
  await page.getByRole('heading', { name: 'PeriMedi' }).waitFor({
    timeout: 15_000,
  })
  await page.waitForTimeout(300)
}

async function shot(page, name, fullPage = true) {
  const file = path.join(outDir, `${name}.png`)
  await page.screenshot({ path: file, fullPage })
  console.log(`  wrote ${path.relative(root, file)}`)
}

async function loadSample(page) {
  page.once('dialog', (d) => d.accept())
  await page.goto(BASE_URL + '/more', { waitUntil: 'networkidle' })
  await page.waitForTimeout(300)
  const load = page.getByRole('button', {
    name: /Load sample|Beispiel laden/i,
  })
  if (await load.count()) {
    await load.first().click()
    await page.waitForTimeout(900)
    return true
  }
  return false
}

async function main() {
  await mkdir(outDir, { recursive: true })
  console.log(`SE 375×667 multi-tab shots → ${path.relative(root, outDir)}/`)
  console.log(`BASE_URL=${BASE_URL}`)

  const browser = await chromium.launch({ headless: true })
  const context = await browser.newContext({ ...SE, locale: 'en-US' })
  const page = await context.newPage()

  try {
    await waitApp(page)

    // Viewport shots per tab via bottom nav
    for (const tab of TABS) {
      await page.goto(BASE_URL + tab.path, { waitUntil: 'networkidle' })
      await page.waitForTimeout(400)
      // Bottom nav visible
      await page.getByRole('navigation').waitFor({ timeout: 5000 })
      await shot(page, `${tab.name}-viewport`, false)
      await shot(page, `${tab.name}-full`, true)
    }

    // Sample data + cycle viewport (incl. horizontal scroll state)
    if (await loadSample(page)) {
      await page.goto(BASE_URL + '/cycle', { waitUntil: 'networkidle' })
      await page.waitForTimeout(700)
      await shot(page, '05-cycle-meds-viewport', false)

      const scroller = page.locator('[data-cycle-plot-scroll]')
      if (await scroller.count()) {
        // Start-of-cycle scroll
        await scroller.evaluate((el) => {
          el.scrollLeft = 0
        })
        await page.waitForTimeout(200)
        await shot(page, '07-cycle-meds-scroll-start', false)

        // Mid-cycle scroll — exercise sticky dose meta + clipped day badge
        await scroller.evaluate((el) => {
          const max = el.scrollWidth - el.clientWidth
          el.scrollLeft = Math.max(0, Math.floor(max * 0.45))
        })
        await page.waitForTimeout(250)
        await shot(page, '08-cycle-meds-scroll-mid', false)
      }

      await page.goto(BASE_URL + '/', { waitUntil: 'networkidle' })
      await page.waitForTimeout(400)
      await shot(page, '06-today-meds-viewport', false)
    }

    console.log('Done. Review PNGs under shots/')
  } catch (err) {
    console.error('\nScreenshot run failed.')
    console.error(err instanceof Error ? err.message : err)
    process.exitCode = 1
  } finally {
    await browser.close()
  }
}

main()
