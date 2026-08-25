import { test, expect } from './wallet/fixture'

test.describe('App routes & redirects (DTF)', () => {
  test('home, explore, create, you, learn, earn load', async ({ walletPage }) => {
    for (const path of ['/', '/explore', '/create', '/you', '/learn', '/earn']) {
      const res = await walletPage.goto(path)
      expect(res?.ok() || res?.status() === 304).toBeTruthy()
      await expect(walletPage.locator('body')).not.toBeEmpty()
    }
  })

  test('/mint is gone', async ({ walletPage }) => {
    const res = await walletPage.goto('/mint')
    expect(res?.status()).toBe(404)
    await expect(walletPage.getByRole('heading', { name: 'Mint Test Tokens' })).toHaveCount(0)
    await walletPage.goto('/explore')
    await walletPage.getByRole('button', { name: 'More' }).click()
    await expect(walletPage.locator('a[href="/mint"]')).toHaveCount(0)
    await expect(walletPage.getByRole('link', { name: 'Mint Test Tokens' })).toHaveCount(0)
  })

  test('/vaults redirects toward earn', async ({ walletPage }) => {
    await walletPage.goto('/vaults')
    await walletPage.waitForURL(/earn/, { timeout: 15_000 })
    expect(walletPage.url()).toMatch(/earn/)
  })

  test('/detfs redirects toward earn', async ({ walletPage }) => {
    await walletPage.goto('/detfs')
    await walletPage.waitForURL(/earn/, { timeout: 15_000 })
    expect(walletPage.url()).toMatch(/earn/)
  })

  test('staking workspace loads', async ({ walletPage }) => {
    await walletPage.goto('/staking')
    const body = await walletPage.locator('body').innerText()
    expect(/DETF|Staking|workspace|DTF-DETF|mint|bond/i.test(body)).toBe(true)
  })

  test('insights stake tab is on the DETF actions panel', async ({ walletPage }) => {
    await walletPage.goto('/insights?tab=stake')
    await expect(walletPage.getByTestId('detf-actions')).toBeVisible({ timeout: 20_000 })
    await expect(walletPage.getByRole('button', { name: /^Stake$/ })).toBeVisible()
    const body = await walletPage.locator('body').innerText()
    expect(/claim token|rebasing claim|Stake/i.test(body)).toBe(true)
  })
})
