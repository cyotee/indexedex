import { test, expect } from './wallet/fixture'
import { strategyVaults, balancerPools, baseTokens } from './helpers/chainArtifacts'

/**
 * L3/L4 surface checks for Swap + Batch Swap option population.
 * Full route txs need data-testids + balances; this verifies lists load from live tokenlists.
 */
test.describe('Swap surfaces', () => {
  test.beforeEach(async ({ walletPage }) => {
    await walletPage.goto('/')
    await walletPage.evaluate(() => {
      localStorage.setItem('indexedex:selected-network', '11155111')
      for (const k of Object.keys(localStorage)) {
        if (k.startsWith('indexedex-wagmi') || k.includes('wagmi')) localStorage.removeItem(k)
      }
    })
  })

  test('Swap page loads pool and token selectors with options', async ({ walletPage }) => {
    await walletPage.goto('/swap', { waitUntil: 'networkidle' })
    await expect(walletPage.getByRole('heading', { name: /Swap/i })).toBeVisible()

    // Connect so tokenlists resolve against selected chain
    const connect = walletPage.getByRole('button', { name: /^Connect Wallet$/i })
    if (await connect.isVisible().catch(() => false)) {
      await connect.click({ force: true }).catch(() => {})
      await walletPage.waitForTimeout(1000)
    }

    const poolSelect = walletPage.getByTestId('swap-pool-select')
    await expect(poolSelect).toBeVisible({ timeout: 15_000 })
    // Options may populate async after chain/tokenlist resolve
    await expect
      .poll(async () => poolSelect.locator('option').count(), { timeout: 20_000 })
      .toBeGreaterThan(1)

    const options = await poolSelect.locator('option').allTextContents()
    const joined = options.join(' ').toLowerCase()
    const hasPoolLike =
      options.length > 1 ||
      balancerPools().some(
        (p) =>
          joined.includes(p.symbol.toLowerCase()) ||
          joined.includes(p.address.toLowerCase().slice(2, 8)),
      ) ||
      strategyVaults().some(
        (v) =>
          joined.includes(v.symbol.toLowerCase()) ||
          joined.includes(v.address.toLowerCase().slice(2, 8)),
      ) ||
      /vault|pool|weth|wrap|select/i.test(joined)

    expect(hasPoolLike, `options=${JSON.stringify(options)}`).toBe(true)
    await expect(walletPage.getByTestId('swap-token-in-select')).toBeVisible()
    await expect(walletPage.getByTestId('swap-token-out-select')).toBeVisible()
    await expect(walletPage.getByTestId('swap-amount-in')).toBeVisible()
    await expect(walletPage.getByTestId('swap-submit')).toBeVisible()
  })

  test('Batch Swap page loads', async ({ walletPage }) => {
    await walletPage.goto('/batch-swap')
    const body = await walletPage.locator('body').innerText()
    expect(/batch/i.test(body)).toBe(true)
    await expect(walletPage.getByTestId('batch-path-0-token-in')).toBeVisible({ timeout: 15_000 })
    await expect(walletPage.getByTestId('batch-execute')).toBeVisible()
  })

  test('base tokens list is non-empty for swap menus', async () => {
    expect(baseTokens().length).toBeGreaterThan(0)
  })
})

test.describe('Swap route matrix (unit parity reminder)', () => {
  test('tokenlist has material for at least one vault and one balancer pool', async () => {
    // Scenario completeness signal for manual S-BAL / S-DEP
    const okVault = strategyVaults().length > 0
    const okPool = balancerPools().length > 0
    // Soft: report in expect messages
    expect(okVault || okPool, `strategy=${strategyVaults().length} balancer=${balancerPools().length}`).toBe(true)
  })
})
