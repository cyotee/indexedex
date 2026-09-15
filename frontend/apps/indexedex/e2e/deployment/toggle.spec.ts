import { expect, test } from '@playwright/test'

test('deployment setting selects the notice independently of hostname', async ({ page }) => {
  await page.goto('/')
  const notice = page.getByTestId('domain-announcement-overlay')
  if (process.env.E2E_SITE_DEPLOYMENT === 'dtf') {
    await expect(notice).toBeVisible()
    await page.getByRole('button', { name: 'Continue using DTF' }).click()
  } else {
    await expect(page.getByRole('link', { name: 'Join a live DETF' })).toBeVisible()
    await expect(notice).toHaveCount(0)
  }
  await page.getByRole('link', { name: 'Join a live DETF' }).click()
  await expect(page).toHaveURL(/\/explore$/)
  await expect(notice).toHaveCount(0)
})
