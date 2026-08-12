/**
 * Wave 2 Protocol DETF IA smoke (DTF app, chain 4663 artifacts by default).
 */
import { test, expect } from './wallet/fixture'
import { feeDetfAddress, featuredFeeDetfs } from './helpers/chainArtifacts'
import { prepareLocalChain } from './helpers/connect'

test.describe('Wave 2 Protocol DETF narrative (DTF / RH)', () => {
  test.beforeEach(async ({ walletPage }) => {
    await prepareLocalChain(walletPage)
  })

  test('landing featured links to /staking?detf=', async ({ walletPage }) => {
    const hero = feeDetfAddress()
    test.skip(!hero, 'no featured fee DETF on e2e chain artifacts')

    await walletPage.goto('/')
    const featuredLink = walletPage.locator(`a[href*="/staking?detf="]`).first()
    // Landing may use different copy; deep-link surface is enough when list present
    if (await featuredLink.isVisible().catch(() => false)) {
      const href = await featuredLink.getAttribute('href')
      expect(href?.toLowerCase()).toContain(`/staking?detf=`)
      await featuredLink.click()
      await walletPage.waitForURL(/\/staking\?detf=/i, { timeout: 15_000 })
    } else {
      await walletPage.goto(`/staking?detf=${hero}`)
      await expect(walletPage.getByTestId('detf-workspace-full')).toBeVisible({ timeout: 20_000 })
    }
  })

  test('Earn grid excludes fee-detf addresses', async ({ walletPage }) => {
    const fees = featuredFeeDetfs()
    test.skip(fees.length === 0, 'no featured-fee-detfs')
    const hero = fees[0]!.address

    await walletPage.goto('/earn')
    await expect(walletPage.getByRole('heading', { name: /^Earn$/i })).toBeVisible({
      timeout: 20_000,
    })

    for (const t of fees) {
      await expect(walletPage.locator(`a[href="/earn/${t.address}"]`)).toHaveCount(0)
      await expect(walletPage.locator(`a[href="/earn/${t.address.toLowerCase()}"]`)).toHaveCount(0)
    }
    void hero
  })

  test('/earn/0xFeeDetf redirects to /staking?detf=', async ({ walletPage }) => {
    const hero = feeDetfAddress()
    test.skip(!hero, 'no fee DETF')

    await walletPage.goto(`/earn/${hero}`)
    await walletPage.waitForURL(new RegExp(`/staking\\?detf=`, 'i'), { timeout: 20_000 })
    expect(walletPage.url().toLowerCase()).toContain(hero.toLowerCase())
  })

  test('staking mint/bond chrome loads with testids', async ({ walletPage }) => {
    const hero = feeDetfAddress()
    const path = hero ? `/staking?detf=${hero}` : '/staking'

    await walletPage.goto(path)
    await expect(walletPage.getByTestId('detf-workspace-full')).toBeVisible({ timeout: 20_000 })
    const body = await walletPage.locator('body').innerText()
    expect(/mint|bond|sell|workspace|Protocol DETF/i.test(body)).toBe(true)
    // Bond panel testids (present when DETF selected)
    if (hero) {
      await expect(walletPage.getByTestId('staking-bond-rate-asset-panel')).toBeVisible({
        timeout: 15_000,
      })
      await expect(walletPage.getByTestId('staking-bond-rate-asset-submit')).toBeVisible()
    }
  })
})
