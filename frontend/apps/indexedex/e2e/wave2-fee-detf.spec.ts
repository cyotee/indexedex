/**
 * Wave 2 Protocol DETF IA smoke (no deploy).
 * Landing → /staking?detf=, Earn grid excludes fee list addresses, /earn/0xFee → staking.
 */
import { test, expect } from './wallet/fixture'
import fs from 'node:fs'
import path from 'node:path'

const FEE_LIST = path.join(
  process.cwd(),
  'app/addresses/chain/11155111/featured-fee-detfs.tokenlist.json',
)

function feeDetfAddresses(): `0x${string}`[] {
  if (!fs.existsSync(FEE_LIST)) return []
  const j = JSON.parse(fs.readFileSync(FEE_LIST, 'utf8')) as {
    tokens?: Array<{ address?: string }>
  }
  return (j.tokens ?? [])
    .map((t) => t.address)
    .filter((a): a is `0x${string}` => typeof a === 'string' && /^0x[0-9a-fA-F]{40}$/.test(a))
}

test.describe('Wave 2 Protocol DETF narrative', () => {
  test('landing featured links to /staking?detf=', async ({ walletPage }) => {
    const fees = feeDetfAddresses()
    test.skip(fees.length === 0, 'no featured-fee-detfs on chain 11155111')

    await walletPage.goto('/')
    await expect(walletPage.getByRole('heading', { name: /Protocol DETF/i })).toBeVisible({
      timeout: 20_000,
    })

    const hero = fees[0]!
    const featuredLink = walletPage.locator(`a[href*="/staking?detf="]`).first()
    await expect(featuredLink).toBeVisible()
    const href = await featuredLink.getAttribute('href')
    expect(href?.toLowerCase()).toContain(`/staking?detf=${hero.toLowerCase()}`)

    await featuredLink.click()
    await walletPage.waitForURL(/\/staking\?detf=/i, { timeout: 15_000 })
    expect(walletPage.url().toLowerCase()).toContain(hero.toLowerCase())
    await expect(walletPage.getByText(/Protocol DETF/i).first()).toBeVisible()
  })

  test('Earn grid excludes fee-detf addresses; banner points at staking', async ({
    walletPage,
  }) => {
    const fees = feeDetfAddresses()
    test.skip(fees.length === 0, 'no featured-fee-detfs on chain 11155111')
    const hero = fees[0]!

    await walletPage.goto('/earn')
    await expect(walletPage.getByRole('heading', { name: /^Earn$/i })).toBeVisible({
      timeout: 20_000,
    })

    // Banner cross-promo (not a catalog row).
    const banner = walletPage.getByText(/lives on the Protocol DETF workspace|Protocol DETFs use a dedicated workspace/i)
    await expect(banner.first()).toBeVisible()

    const bannerCta = walletPage.locator('a[href*="/staking"]').filter({ hasText: /Open/i }).first()
    await expect(bannerCta).toBeVisible()
    const bannerHref = await bannerCta.getAttribute('href')
    expect(bannerHref).toMatch(/\/staking/)

    // Fee DETF must not appear as an Earn detail catalog link.
    const earnDetailLinks = walletPage.locator(`a[href="/earn/${hero}"], a[href="/earn/${hero.toLowerCase()}"]`)
    await expect(earnDetailLinks).toHaveCount(0)

    // Address string may appear in banner/promo only if we show truncated forms —
    // ensure no row "Open" to /earn/{fee}.
    for (const addr of fees) {
      await expect(walletPage.locator(`a[href="/earn/${addr}"]`)).toHaveCount(0)
      await expect(walletPage.locator(`a[href="/earn/${addr.toLowerCase()}"]`)).toHaveCount(0)
    }
  })

  test('/earn/0xFeeDetf redirects to /staking?detf=', async ({ walletPage }) => {
    const fees = feeDetfAddresses()
    test.skip(fees.length === 0, 'no featured-fee-detfs on chain 11155111')
    const hero = fees[0]!

    await walletPage.goto(`/earn/${hero}`)
    await walletPage.waitForURL(new RegExp(`/staking\\?detf=${hero}`, 'i'), { timeout: 20_000 })
    expect(walletPage.url().toLowerCase()).toContain(`/staking?detf=${hero.toLowerCase()}`)
  })

  test('staking mint/bond chrome loads', async ({ walletPage }) => {
    const fees = feeDetfAddresses()
    const path =
      fees.length > 0 ? `/staking?detf=${fees[0]}` : '/staking'

    await walletPage.goto(path)
    await expect(walletPage.getByText(/Protocol DETF|mint|bond/i).first()).toBeVisible({
      timeout: 20_000,
    })
    // Sections present as text (do not require live contract success).
    const body = await walletPage.locator('body').innerText()
    expect(/mint|bond|sell|workspace|selector/i.test(body)).toBe(true)
  })

  test('Token handoff Open {symbol} → staking when fee list present', async ({ walletPage }) => {
    const fees = feeDetfAddresses()
    test.skip(fees.length === 0, 'no featured-fee-detfs on chain 11155111')

    await walletPage.goto('/token')
    const openLink = walletPage.locator('a[href*="/staking?detf="]').filter({ hasText: /Open /i }).first()
    await expect(openLink).toBeVisible({ timeout: 20_000 })
    const href = await openLink.getAttribute('href')
    expect(href?.toLowerCase()).toContain(fees[0]!.toLowerCase())
  })
})
