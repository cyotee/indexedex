import { parseEther } from 'viem'
import { test, expect, ANVIL_ACCOUNT_0 } from './wallet/fixture'
import { feeDetfAddress, findBaseBySymbol, loadPlatform } from './helpers/chainArtifacts'
import { prepareLocalChain, connectInjectedWallet } from './helpers/connect'
import {
  chainIdMatches,
  ensureWeth,
  erc20Balance,
  isDetfReserveLive,
  nftBalance,
  rpcAlive,
} from './helpers/rpc'

/**
 * Live DETF bond via /staking UI (rate-asset path).
 *
 * Prerequisites:
 *   - Anvil at E2E_RPC_URL (default http://127.0.0.1:8545)
 *   - cast chain-id === E2E_CHAIN_ID (default 4663)
 *   - fee_detf stack preferred (CHIR live after scripted first bond)
 *   - Account #0 has WETH (wrap ETH if needed)
 *
 * Run:
 *   npm run test:e2e:live -w @indexedex/app-dtf
 *   # or: npx playwright test e2e/staking-bond-live.spec.ts
 */
test.describe('Live staking bond (Anvil RH)', () => {
  test.setTimeout(180_000)

  test.beforeEach(async ({ walletPage }) => {
    test.skip(!(await rpcAlive()), 'RPC not reachable — start Anvil RH stack first')
    test.skip(
      !(await chainIdMatches()),
      `RPC chain id must be ${process.env.E2E_CHAIN_ID ?? 4663}`,
    )
    await prepareLocalChain(walletPage)
    await connectInjectedWallet(walletPage)
  })

  test('bond rate asset (WETH) via staking UI when fee DETF live', async ({ walletPage }) => {
    const detf = feeDetfAddress()
    test.skip(!detf, 'No fee DETF in chain artifacts')

    const live = await isDetfReserveLive(detf)
    test.skip(live === false, 'DETF reserve not live — run fee_detf stage 11 first bond')
    // live === null means method missing; continue and let UI attempt

    const weth = findBaseBySymbol('WETH') ?? findBaseBySymbol('WETH9')
    test.skip(!weth, 'WETH missing from base-tokens')

    await ensureWeth(parseEther('0.2'))
    const wethBefore = await erc20Balance(weth.address as `0x${string}`, ANVIL_ACCOUNT_0.address)
    test.skip(wethBefore < parseEther('0.01'), 'Insufficient WETH on Anvil #0')

    const platform = loadPlatform()
    const nftVault = (platform.protocolNftVault ?? platform.bondNftVault) as string | undefined

    await walletPage.goto(`/staking?detf=${detf}`, { waitUntil: 'networkidle' })
    await expect(walletPage.getByTestId('detf-workspace-full')).toBeVisible({ timeout: 30_000 })
    await expect(walletPage.getByTestId('staking-bond-rate-asset-amount')).toBeVisible({
      timeout: 20_000,
    })

    // Minimal lock days for faster oracle-path (still subject to on-chain min lock)
    await walletPage.getByTestId('staking-bond-lock-days').fill('30')
    await walletPage.getByTestId('staking-bond-rate-asset-amount').fill('0.01')

    const submit = walletPage.getByTestId('staking-bond-rate-asset-submit')
    await expect(submit).toBeEnabled({ timeout: 30_000 })

    const nftBefore =
      nftVault && /^0x[0-9a-fA-F]{40}$/.test(nftVault)
        ? await nftBalance(nftVault as `0x${string}`, ANVIL_ACCOUNT_0.address)
        : null

    await submit.click()

    // Approve + bond: UI may take two txs; poll for WETH spend or NFT mint
    await expect
      .poll(
        async () => {
          const wethAfter = await erc20Balance(
            weth.address as `0x${string}`,
            ANVIL_ACCOUNT_0.address,
          )
          if (wethAfter < wethBefore) return true
          if (nftBefore !== null && nftVault) {
            const n = await nftBalance(nftVault as `0x${string}`, ANVIL_ACCOUNT_0.address)
            if (n > nftBefore) return true
          }
          const body = await walletPage.locator('body').innerText()
          if (/Bond rate asset confirmed|confirmed: 0x/i.test(body)) return true
          if (/revert|failed|error/i.test(body) && /bond/i.test(body)) {
            // surface failure instead of hanging
            return 'fail'
          }
          return false
        },
        { timeout: 120_000 },
      )
      .not.toBe(false)

    const outcome = await (async () => {
      const wethAfter = await erc20Balance(weth.address as `0x${string}`, ANVIL_ACCOUNT_0.address)
      if (wethAfter < wethBefore) return 'weth-spent'
      if (nftBefore !== null && nftVault) {
        const n = await nftBalance(nftVault as `0x${string}`, ANVIL_ACCOUNT_0.address)
        if (n > nftBefore) return 'nft-minted'
      }
      const body = await walletPage.locator('body').innerText()
      if (/Bond rate asset confirmed|confirmed: 0x/i.test(body)) return 'status-ok'
      return 'unknown'
    })()

    expect(['weth-spent', 'nft-minted', 'status-ok']).toContain(outcome)
  })
})
