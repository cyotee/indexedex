import { expect, test } from '@playwright/test'

const baseURL = process.env.E2E_BASE_URL ?? 'http://127.0.0.1:3013'
const notice = (page: import('@playwright/test').Page) => page.getByRole('dialog', { name: 'Same protocol. Another place to call home.' })

test('landing reassures users, stays on DTF and keeps the background inert', async ({ page }) => {
  await page.goto('/')
  await expect(notice(page)).toBeVisible()
  await expect(notice(page)).toContainText('Both domains serve the same protocol.')
  await expect(notice(page)).toContainText('We’ll support both for the foreseeable future.')
  await expect(notice(page)).toContainText('The old DTF account on X is deprecated.')
  await expect(page.getByTestId('token-staking-overlay')).toHaveCount(0)
  await page.getByRole('button', { name: 'Close domain announcement' }).focus()
  // Native modal dialogs prevent focus entering the background. Browser chrome
  // can still receive focus at the tab boundaries, which is expected behavior.
  await page.locator('.dtf-landing__nav a').first().evaluate((link: HTMLElement) => link.focus())
  await expect(page.getByRole('button', { name: 'Close domain announcement' })).toBeFocused()
  await page.keyboard.press('Tab')
  await expect(page.getByRole('link', { name: 'Go to indexedex.com' })).toBeFocused()
  await page.keyboard.press('Shift+Tab')
  await expect(page.getByRole('button', { name: 'Close domain announcement' })).toBeFocused()
  await page.waitForTimeout(2000)
  await expect(page).toHaveURL(`${baseURL}/`)
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true)
})

for (const method of ['close', 'continue', 'escape']) {
  test(`${method} advances from the domain announcement to staking`, async ({ page }) => {
    await page.goto('/')
    await expect(notice(page)).toBeVisible()
    if (method === 'escape') await page.keyboard.press('Escape')
    else await page.getByRole('button', { name: method === 'close' ? 'Close domain announcement' : 'Continue using DTF' }).click()
    await expect(notice(page)).toHaveCount(0)
    await expect(page.getByRole('dialog', { name: 'Stake $DTF' })).toBeVisible()
    expect(await page.evaluate(() => document.body.style.overflow)).toBe('hidden')
    await page.getByRole('button', { name: 'Close staking overlay' }).click()
    expect(await page.evaluate(() => document.body.style.overflow)).not.toBe('hidden')
    await expect(page).toHaveURL(`${baseURL}/`)
    await page.reload()
    await expect(notice(page)).toBeVisible()
    await expect(page.getByTestId('token-staking-overlay')).toHaveCount(0)
    await page.getByRole('button', { name: 'Close domain announcement' }).click()
    await expect(page.getByRole('dialog', { name: 'Stake $DTF' })).toBeVisible()
    await page.getByRole('button', { name: 'Close staking overlay' }).click()
    await page.getByRole('link', { name: 'Join a live DETF' }).click()
    await expect(page).toHaveURL(`${baseURL}/explore`)
    await page.getByRole('banner').getByRole('link', { name: /IndexedEx/ }).click()
    await expect(notice(page)).toBeVisible()
    await expect(page.getByTestId('token-staking-overlay')).toHaveCount(0)
    const response = await page.goto('/staking')
    expect(response?.status()).toBe(200)
    await expect(notice(page)).toHaveCount(0)
    await expect(page.locator('body')).toContainText('Protocol DETF')
  })
}

test('IndexedEx opens in this tab and X opens in a new tab', async ({ page, context }) => {
  for (const url of ['https://indexedex.com/', 'https://x.com/Indexedex']) {
    await context.route(url, route => route.fulfill({ contentType: 'text/html', body: '<h1>Destination</h1>' }))
  }
  await page.goto('/')
  const popupPromise = page.waitForEvent('popup')
  await page.getByRole('link', { name: 'Follow @Indexedex on X (opens in a new tab)' }).click()
  const popup = await popupPromise
  await expect(popup).toHaveURL('https://x.com/Indexedex')
  await expect(page).toHaveURL(`${baseURL}/`)
  expect(await popup.evaluate(() => window.opener === null)).toBe(true)
  await popup.close()
  await page.getByRole('link', { name: 'Go to indexedex.com' }).click()
  await expect(page).toHaveURL('https://indexedex.com/')
  expect(context.pages()).toHaveLength(1)
})

test('an old saved dismissal cannot skip the domain announcement', async ({ page }) => {
  await page.addInitScript(() => {
    sessionStorage.setItem('dtf-domain-announcement-dismissed-v1', 'true')
  })
  await page.goto('/')
  await expect(notice(page)).toBeVisible()
  await page.getByRole('button', { name: 'Continue using DTF' }).click()
  await expect(notice(page)).toHaveCount(0)
  await expect(page.getByRole('dialog', { name: 'Stake $DTF' })).toBeVisible()
  await page.getByRole('button', { name: 'Close staking overlay' }).click()
  await expect(page.getByRole('link', { name: 'Join a live DETF' })).toBeVisible()
})
