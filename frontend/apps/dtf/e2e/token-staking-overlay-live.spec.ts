import { test, expect } from '@playwright/test'

// The landing overlay is now a navigation notice; it makes no wallet transactions.
test('migration notice supports keyboard dismissal and links to staking', async ({ page }) => {
  await page.goto('/')
  const overlay = page.getByTestId('token-staking-overlay')
  await expect(overlay.getByRole('heading', { name: 'Migration complete' })).toBeVisible()

  await page.keyboard.press('Escape')
  await expect(overlay).toHaveCount(0)
  await expect(page.getByRole('heading', { name: 'Your whole strategy, in a single token.' })).toBeVisible()

  await page.reload()
  await expect(overlay).toBeVisible()
  await overlay.getByRole('link', { name: 'Go to staking' }).click()
  await expect(page).toHaveURL(/\/staking$/)
})
