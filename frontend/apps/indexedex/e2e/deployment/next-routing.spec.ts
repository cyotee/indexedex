import { expect, test } from '@playwright/test'

test('research pages resolve async params and metadata', async ({ page }) => {
  const errors: string[] = []
  page.on('pageerror', error => errors.push(error.message))
  for (const slug of ['detf', 'detf-types', 'rate-providers']) {
    const response = await page.goto(`/research/${slug}`, { waitUntil: 'domcontentloaded' })
    expect(response?.status()).toBe(200)
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
    await expect(page).toHaveTitle(/Research.*IndexedEx/)
  }
  expect(errors).toEqual([])
})

test('missing research content stays not found', async ({ page }) => {
  await page.goto('/research/not-a-research-note', { waitUntil: 'domcontentloaded' })
  await expect(page.getByRole('heading', { name: '404' })).toBeVisible()
})

test('portfolio alias preserves repeated and encoded search parameters', async ({ page }) => {
  await page.goto('/you?token=one&token=two&q=a%20%26%20b', { waitUntil: 'domcontentloaded' })
  await expect(page).toHaveURL(/\/portfolio\?/)
  const url = new URL(page.url())
  expect(url.searchParams.getAll('token')).toEqual(['one', 'two'])
  expect(url.searchParams.get('q')).toBe('a & b')
})

test('wallet dialog opens with React 19 on the staking route', async ({ page }) => {
  const errors: string[] = []
  page.on('pageerror', error => errors.push(error.message))
  await page.goto('/staking', { waitUntil: 'domcontentloaded' })
  await page.getByRole('button', { name: /Connect Wallet/i }).first().click()
  await expect(page.getByRole('dialog')).toBeVisible()
  expect(errors).toEqual([])
})
