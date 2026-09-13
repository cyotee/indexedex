import { test, expect } from '@playwright/test'

test('IndexedEx landing has no staking or domain overlay', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByTestId('token-staking-overlay')).toHaveCount(0)
  await expect(page.getByTestId('domain-announcement-overlay')).toHaveCount(0)
  await expect(page.getByRole('link', { name: 'Join a live DETF' })).toBeVisible()
  expect(await page.evaluate(() => document.body.style.overflow)).not.toBe('hidden')
})
