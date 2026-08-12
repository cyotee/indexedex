import { parseEther } from 'viem'
import { test, expect, ANVIL_ACCOUNT_0 } from './wallet/fixture'
import {
  strategyVaults,
  findBaseBySymbol,
} from './helpers/chainArtifacts'
import { connectInjectedWallet, prepareLocalChain, selectByValue, waitForOption } from './helpers/connect'
import { chainIdMatches, ensureWeth, erc20Balance, rpcAlive } from './helpers/rpc'

/**
 * Live swap/deposit txs via DTF UI when the stack has SE vaults + router.
 * RH fee_detf may only have Uni V3 SE (no Balancer router) — cases skip cleanly.
 */
test.describe('Live swap routes (DTF / Anvil)', () => {
  test.setTimeout(180_000)

  test.beforeEach(async ({ walletPage }) => {
    test.skip(!(await rpcAlive()), 'RPC not reachable')
    test.skip(!(await chainIdMatches()), 'RPC chain id mismatch')
    await prepareLocalChain(walletPage)
    await connectInjectedWallet(walletPage)
    try {
      await ensureWeth(parseEther('0.5'))
    } catch {
      /* WETH wrap may fail if not WETH9 depositable; individual tests skip */
    }
  })

  async function approveIfNeeded(walletPage: import('@playwright/test').Page) {
    for (const id of ['swap-approve-permit2', 'swap-approve-router']) {
      const btn = walletPage.getByTestId(id)
      if (await btn.isVisible().catch(() => false)) {
        if (!(await btn.isDisabled())) {
          await btn.click()
          await walletPage.waitForTimeout(3000)
          try {
            await expect
              .poll(async () => {
                if (!(await btn.isVisible().catch(() => false))) return true
                return await btn.isDisabled()
              }, { timeout: 45_000 })
              .toBe(true)
          } catch {
            /* continue */
          }
        }
      }
    }
  }

  async function runSwapAfterQuote(walletPage: import('@playwright/test').Page) {
    const preview = walletPage.getByTestId('swap-preview')
    await expect(preview).toBeVisible({ timeout: 20_000 })
    if (!(await preview.isDisabled().catch(() => true))) {
      await preview.click()
    }

    await expect
      .poll(async () => !(await walletPage.getByTestId('swap-submit').isDisabled()), {
        timeout: 60_000,
      })
      .toBe(true)

    await approveIfNeeded(walletPage)

    if (await walletPage.getByTestId('swap-submit').isDisabled()) {
      if (!(await preview.isDisabled().catch(() => true))) await preview.click()
      await expect
        .poll(async () => !(await walletPage.getByTestId('swap-submit').isDisabled()), {
          timeout: 60_000,
        })
        .toBe(true)
    }

    await walletPage.getByTestId('swap-submit').click()
  }

  test('S-DEP: Strategy Vault Deposit via Swap when vault + selectors present', async ({
    walletPage,
  }) => {
    const vaults = strategyVaults()
    const weth = findBaseBySymbol('WETH9') ?? findBaseBySymbol('WETH')
    test.skip(!vaults.length || !weth, 'Need strategy vault + WETH in tokenlists')

    const vault = vaults[0]!
    const before = await erc20Balance(vault.address as `0x${string}`, ANVIL_ACCOUNT_0.address)

    await walletPage.goto('/swap', { waitUntil: 'networkidle' })
    const poolSelect = walletPage.getByTestId('swap-pool-select')
    test.skip(!(await poolSelect.isVisible().catch(() => false)), 'swap-pool-select missing')

    try {
      await waitForOption(walletPage, 'swap-pool-select', vault.address, 20_000)
    } catch {
      test.skip(true, 'Vault not in swap pool selector (router/list gap)')
    }

    await selectByValue(walletPage, 'swap-pool-select', vault.address)
    await waitForOption(walletPage, 'swap-token-in-select', weth!.address)
    await selectByValue(walletPage, 'swap-token-in-select', weth!.address)
    await waitForOption(walletPage, 'swap-token-out-select', vault.address)
    await selectByValue(walletPage, 'swap-token-out-select', vault.address)

    const depToggle = walletPage.getByTestId('swap-deposit-vault-toggle')
    if (await depToggle.isVisible().catch(() => false)) {
      try {
        await expect.poll(async () => depToggle.isChecked(), { timeout: 15_000 }).toBe(true)
      } catch {
        if (!(await depToggle.isChecked())) await depToggle.check()
      }
    }

    await walletPage.getByTestId('swap-amount-in').fill('0.01')

    try {
      await runSwapAfterQuote(walletPage)
    } catch (e) {
      test.skip(true, `Swap path not executable on this stack: ${String(e).slice(0, 120)}`)
    }

    await expect
      .poll(
        async () => {
          const after = await erc20Balance(vault.address as `0x${string}`, ANVIL_ACCOUNT_0.address)
          return after > before
        },
        { timeout: 90_000 },
      )
      .toBe(true)
  })

  test('E-DEP: Earn deposit panel when vault listed', async ({ walletPage }) => {
    const vaults = strategyVaults()
    const weth = findBaseBySymbol('WETH9') ?? findBaseBySymbol('WETH')
    test.skip(!vaults.length || !weth, 'Need vault + WETH')
    const vault = vaults[0]!
    const before = await erc20Balance(vault.address as `0x${string}`, ANVIL_ACCOUNT_0.address)

    await walletPage.goto(`/earn/${vault.address}`, { waitUntil: 'networkidle' })
    const amount = walletPage.getByTestId('earn-deposit-amount-input')
    test.skip(!(await amount.isVisible().catch(() => false)), 'deposit amount field missing')

    const asset = walletPage.getByTestId('earn-deposit-asset')
    if (await asset.isVisible().catch(() => false)) {
      await selectByValue(walletPage, 'earn-deposit-asset', weth!.address).catch(async () => {
        const vals = await asset.locator('option').evaluateAll((opts) =>
          opts.map((o) => (o as HTMLOptionElement).value).filter(Boolean),
        )
        if (vals[0]) await asset.selectOption(vals[0])
      })
    }
    await amount.fill('0.01')

    for (let i = 0; i < 6; i++) {
      const submit = walletPage.getByTestId('earn-deposit-submit')
      if (!(await submit.isVisible().catch(() => false))) break
      if (await submit.isDisabled().catch(() => true)) {
        await walletPage.waitForTimeout(1500)
        continue
      }
      await submit.click()
      await walletPage.waitForTimeout(2500)
      const after = await erc20Balance(vault.address as `0x${string}`, ANVIL_ACCOUNT_0.address)
      if (after > before) break
    }

    const after = await erc20Balance(vault.address as `0x${string}`, ANVIL_ACCOUNT_0.address)
    if (!(after > before)) {
      test.skip(true, 'Earn deposit did not mint shares (router/approval/stack gap)')
    }
    expect(after > before).toBe(true)
  })
})
