import { test, expect } from './wallet/fixture'

test.describe('App routes & redirects (DTF)', () => {
  test('home, explore, create, you, learn, earn, token load', async ({ walletPage }) => {
    for (const path of ['/', '/explore', '/create', '/you', '/learn', '/earn', '/token']) {
      const res = await walletPage.goto(path)
      expect(res?.ok() || res?.status() === 304).toBeTruthy()
      await expect(walletPage.locator('body')).not.toBeEmpty()
    }
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
    expect(/DETF|Staking|workspace|CHIR|mint|bond/i.test(body)).toBe(true)
  })
})
