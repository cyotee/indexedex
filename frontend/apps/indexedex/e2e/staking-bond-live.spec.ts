import { parseEther } from 'viem'
import { test, expect, ANVIL_ACCOUNT_0 } from './wallet/fixture'
import { findBaseBySymbol } from './helpers/chainArtifacts'
import { readProtocolDetf } from '../app/lib/tokenStaking/migration'
import platform from '../../../packages/protocol/src/addresses/chain/4663/platform.json'
import { readBondNftVault } from '../app/lib/detf/bondNftVault'
import { insightsViewAbi } from '../app/insights/lib/insightsAbi'
import { prepareLocalChain, connectInjectedWallet } from './helpers/connect'
import {
  chainIdMatches,
  ensureWeth,
  erc20Balance,
  isDetfReserveLive,
  nftBalance,
  rpcAlive,
  publicClient,
} from './helpers/rpc'

/**
 * Live DETF bond via /staking UI (rate-asset path).
 *
 * Prerequisites:
 *   - Anvil at E2E_RPC_URL (default http://127.0.0.1:8545)
 *   - cast chain-id === E2E_CHAIN_ID (default 4663)
 *   - fee_detf stack preferred (DTF-DETF live after scripted first bond)
 *   - Account #0 has WETH (wrap ETH if needed)
 *
 * Run:
 *   npm run test:e2e:live -w @indexedex/app-indexedex
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
    const detf = (await readProtocolDetf(publicClient(), platform.tokenStaking as `0x${string}`))!
    expect(detf).toBeTruthy()

    const live = await isDetfReserveLive(detf)
    test.skip(live === false, 'DETF reserve not live — run fee_detf stage 11 first bond')
    // live === null means method missing; continue and let UI attempt

    const weth = findBaseBySymbol('WETH') ?? findBaseBySymbol('WETH9')
    test.skip(!weth, 'WETH missing from base-tokens')

    await ensureWeth(parseEther('0.2'))
    const wethBefore = await erc20Balance(weth.address as `0x${string}`, ANVIL_ACCOUNT_0.address)
    test.skip(wethBefore < parseEther('0.00001'), 'Insufficient WETH on Anvil #0')

    const client = publicClient()
    const nftVault = await readBondNftVault(client, detf)
    expect(nftVault, 'The DETF must expose its actual funded bond child').toBeTruthy()
    const stakingToken = await client.readContract({ address: detf, abi: insightsViewAbi, functionName: 'rebasingClaimToken' })
    const nftBefore = await nftBalance(nftVault!, ANVIL_ACCOUNT_0.address)
    const stakedBefore = await erc20Balance(stakingToken, nftVault!)

    await walletPage.goto(`/staking?detf=${detf}&tab=bond`, { waitUntil: 'networkidle' })
    await expect(walletPage.getByTestId('detf-workspace-full')).toBeVisible({ timeout: 30_000 })
    await expect(walletPage.getByTestId('detf-bond-amount')).toBeVisible({
      timeout: 20_000,
    })

    await walletPage.getByTestId('detf-action-token').selectOption(weth.address)

    // The selected duration remains subject to the actual oracle's allowed range.
    await walletPage.getByTestId('detf-bond-days').fill('30')
    await walletPage.getByTestId('detf-bond-amount-input').fill('0.00001')

    const submit = walletPage.getByTestId('detf-bond')
    const approval = walletPage.getByTestId('detf-approve')
    await expect(approval.or(submit)).toBeVisible({ timeout: 30_000 })
    if (await approval.isVisible()) {
      await expect(approval).toBeEnabled()
      await approval.click()
      await expect(walletPage.getByTestId('detf-action-status')).toHaveText('Approved. Bond or mint next.', { timeout: 60_000 })
    }
    await expect(submit).toBeEnabled({ timeout: 30_000 })
    await submit.click()
    await expect(walletPage.getByTestId('detf-action-status')).toHaveText('Bond confirmed.', { timeout: 120_000 })

    // A purchase must spend the payment, mint a bond, and fund its staked escrow.
    // Approval receipts or status text alone never satisfy this money-path test.
    await expect.poll(() => erc20Balance(weth.address as `0x${string}`, ANVIL_ACCOUNT_0.address)).toBe(wethBefore - parseEther('0.00001'))
    await expect.poll(() => nftBalance(nftVault!, ANVIL_ACCOUNT_0.address)).toBe(nftBefore + 1n)
    await expect.poll(() => erc20Balance(stakingToken, nftVault!)).toBeGreaterThan(stakedBefore)
  })
})
