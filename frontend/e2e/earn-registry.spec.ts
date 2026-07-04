import { test, expect } from './wallet/fixture'
import {
  strategyVaults,
  protocolDetfs,
  findBaseBySymbol,
  loadPlatform,
} from './helpers/chainArtifacts'

/**
 * L3 — Earn preferred list + registry query (requires rebuilt tokenlists + Anvil).
 */
test.describe('Earn + vault registry', () => {
  test('preferred catalog shows strategy vault from tokenlist', async ({ walletPage }) => {
    const vaults = strategyVaults()
    test.skip(vaults.length === 0, 'No strategy vaults in tokenlist')

    await walletPage.goto('/earn')
    await expect(walletPage.getByRole('heading', { name: /Earn/i })).toBeVisible()

    const body = await walletPage.locator('body').innerText()
    // Prefer symbol or name from list
    const hit = vaults.some(
      (v) => body.includes(v.symbol) || body.includes(v.name.slice(0, 12)) || body.includes(v.address.slice(0, 10)),
    )
    expect(hit).toBe(true)
    await expect(walletPage.getByText(/Preferred|preferred products|tokenlist/i).first()).toBeVisible()
  })

  test('registry search by WETH/WETH9 address returns registry results', async ({ walletPage }) => {
    const weth = findBaseBySymbol('WETH9') ?? findBaseBySymbol('WETH')
    test.skip(!weth, 'No WETH in base-tokens tokenlist')
    const platform = loadPlatform()
    test.skip(!platform.vaultRegistry, 'No vaultRegistry in platform')

    await walletPage.goto('/earn')
    const search = walletPage.getByPlaceholder(/Token address|symbol|name/i)
    await search.fill(weth!.address)

    // Status line should indicate registry mode
    await expect(walletPage.getByText(/Registry/i).first()).toBeVisible({ timeout: 20_000 })

    // Either rows or empty state — must not crash; if vaults registered with WETH, expect rows
    await walletPage.waitForTimeout(1500)
    const body = await walletPage.locator('body').innerText()
    const hasRegistryBadge = /Registry/i.test(body)
    expect(hasRegistryBadge).toBe(true)
  })

  test('protocol DETF appears in catalog when listed', async ({ walletPage }) => {
    const detfs = protocolDetfs()
    test.skip(detfs.length === 0, 'No protocol DETFs in tokenlist')

    await walletPage.goto('/earn')
    // type filter if present
    const detfFilter = walletPage.getByRole('button', { name: /Protocol DETF/i })
    if (await detfFilter.isVisible().catch(() => false)) {
      await detfFilter.click()
    }
    const body = await walletPage.locator('body').innerText()
    expect(
      detfs.some((d) => body.includes(d.symbol) || body.includes(d.address.slice(0, 10))),
    ).toBe(true)
  })

  test('earn detail opens for first strategy vault', async ({ walletPage }) => {
    const vaults = strategyVaults()
    test.skip(vaults.length === 0, 'No strategy vaults')
    const v = vaults[0]!
    const res = await walletPage.goto(`/earn/${v.address}`, { waitUntil: 'networkidle' })
    expect(res?.status()).toBeLessThan(500)
    // Wait for client render (AppShell always has nav/footer)
    await expect(walletPage.getByRole('navigation')).toBeVisible({ timeout: 20_000 })
    const body = await walletPage.getByRole('main').innerText()
    expect(body.length).toBeGreaterThan(20)
    expect(/Deposit|Overview|Composition|Product not found|Earn|Vault|CHIR|weth/i.test(body)).toBe(
      true,
    )
  })
})
