import { parseEther, type Address } from 'viem'

import { loadPlatform } from './helpers/chainArtifacts'
import { prepareLocalChain } from './helpers/connect'
import {
  chainIdMatches,
  dealErc20,
  erc20Balance,
  hasCode,
  publicClient,
  rpcAlive,
  warmErc20Allowance,
} from './helpers/rpc'
import { test, expect, ANVIL_ACCOUNT_0 } from './wallet/fixture'

const DTF_TOKEN = '0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01' as Address
const STAKE_AMOUNT = parseEther('1')
/** Deal at least this much so the overlay can stake even on a fresh fork. */
const MIN_WALLET_DTF = parseEther('20000')

const stakingAbi = [
  {
    type: 'function',
    name: 'phase',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint8' }],
  },
  {
    type: 'function',
    name: 'balanceOf',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'totalSupply',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'rewardReserve',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
] as const

function stakingAddress(): Address | undefined {
  const fromEnv = process.env.NEXT_PUBLIC_TOKEN_STAKING?.trim()
  if (fromEnv && /^0x[0-9a-fA-F]{40}$/.test(fromEnv)) return fromEnv as Address
  const platform = loadPlatform()
  const fromPlatform = platform.tokenStaking
  if (typeof fromPlatform === 'string' && /^0x[0-9a-fA-F]{40}$/.test(fromPlatform)) {
    return fromPlatform as Address
  }
  return undefined
}

async function stakingPhase(address: Address): Promise<bigint> {
  const value = await publicClient().readContract({
    address,
    abi: stakingAbi,
    functionName: 'phase',
  })
  return BigInt(value)
}

async function stakingSupply(address: Address): Promise<bigint> {
  const value = await publicClient().readContract({
    address,
    abi: stakingAbi,
    functionName: 'totalSupply',
  })
  return BigInt(value)
}

async function stakingReserve(address: Address): Promise<bigint> {
  const value = await publicClient().readContract({
    address,
    abi: stakingAbi,
    functionName: 'rewardReserve',
  })
  return BigInt(value)
}

/**
 * Live $DTF stake via the landing overlay (injected EIP-1193, not MetaMask).
 *
 * Prerequisites:
 *   - Anvil RH fork at E2E_RPC_URL (chain 4663)
 *   - TokenStaking diamond in platform.json / NEXT_PUBLIC_TOKEN_STAKING
 *   - Phase 0 (Staking). Anvil #0 is dealt $DTF if the wallet is short.
 *
 * Run:
 *   E2E_SKIP_WEBSERVER=1 npx playwright test e2e/token-staking-overlay-live.spec.ts
 */
test.describe('Live token-staking overlay (Anvil RH)', () => {
  test.setTimeout(180_000)

  test('approve + stake $DTF through the overlay and change on-chain balances', async ({
    walletPage,
    walletAddress,
  }) => {
    test.skip(!(await rpcAlive()), 'RPC not reachable — start Anvil RH stack first')
    test.skip(
      !(await chainIdMatches()),
      `RPC chain id must be ${process.env.E2E_CHAIN_ID ?? 4663}`,
    )

    const staking = stakingAddress()
    test.skip(!staking, 'No tokenStaking address in env or chain/4663/platform.json')
    test.skip(!(await hasCode(staking)), `No code at tokenStaking ${staking}`)
    test.skip((await stakingPhase(staking)) !== 0n, 'TokenStaking phase is not Staking')

    const dtfBeforeDeal = await erc20Balance(DTF_TOKEN, ANVIL_ACCOUNT_0.address)
    if (dtfBeforeDeal < MIN_WALLET_DTF) {
      const dealt = await dealErc20(DTF_TOKEN, ANVIL_ACCOUNT_0.address, MIN_WALLET_DTF)
      expect(dealt, 'anvil_setStorageAt did not credit $DTF to Anvil #0').toBeGreaterThanOrEqual(
        MIN_WALLET_DTF,
      )
    }
    // Sparse fork slots: materialize allowance[anvil0][staking] at 0 so Approve can estimate.
    await warmErc20Allowance(DTF_TOKEN, ANVIL_ACCOUNT_0.address, staking, 0n)

    await prepareLocalChain(walletPage)

    const overlay = walletPage.getByTestId('token-staking-overlay')
    await expect(overlay).toBeVisible({ timeout: 30_000 })
    await expect(overlay.getByRole('heading', { name: 'Stake $DTF' })).toBeVisible()
    await expect(overlay.getByText('Staking is not live on this chain yet.')).toHaveCount(0)

    const connect = overlay.getByTestId('token-staking-connect')
    if (await connect.isVisible().catch(() => false)) {
      await connect.click()
    }
    await expect(overlay.locator('.dtf-landing__stake-connected')).toBeVisible({
      timeout: 25_000,
    })
    await expect(overlay.getByText(new RegExp(walletAddress.slice(0, 6), 'i'))).toBeVisible()

    const amountInput = overlay.getByTestId('token-staking-amount-input')
    await expect(amountInput).toBeVisible({ timeout: 30_000 })

    const dtfBefore = await erc20Balance(DTF_TOKEN, ANVIL_ACCOUNT_0.address)
    test.skip(dtfBefore < STAKE_AMOUNT, 'Anvil #0 still has no $DTF after deal')
    const stakeBefore = await erc20Balance(staking, ANVIL_ACCOUNT_0.address)
    const supplyBefore = await stakingSupply(staking)
    const reserveBefore = await stakingReserve(staking)

    await amountInput.fill('1')

    const cta = overlay.getByTestId('token-staking-cta')
    await expect(cta).toBeVisible()
    await expect
      .poll(async () => (await cta.getAttribute('data-gate')) ?? '', { timeout: 20_000 })
      .toMatch(/approve|execute/)

    if ((await cta.getAttribute('data-gate')) === 'approve') {
      await expect(cta).toBeEnabled()
      await cta.click()
      await expect
        .poll(async () => (await cta.getAttribute('data-gate')) ?? '', { timeout: 90_000 })
        .toBe('execute')
    }

    await expect(cta).toHaveAttribute('data-gate', 'execute')
    await expect(cta).toBeEnabled()
    const expectedStake = stakeBefore + STAKE_AMOUNT
    const expectedLabel = `${expectedStake / 10n ** 18n} $DTF`
    await cta.click()

    // Wait on the overlay first. Polling Anvil via the test viem client while
    // the injected wallet's send is in-flight can hang the Node HTTP agent.
    await expect(overlay.getByText(expectedLabel).first()).toBeVisible({ timeout: 120_000 })
    await expect(overlay.getByRole('button', { name: 'Unstake' })).toBeVisible()

    const stakeAfter = await erc20Balance(staking, ANVIL_ACCOUNT_0.address)
    const dtfAfter = await erc20Balance(DTF_TOKEN, ANVIL_ACCOUNT_0.address)
    const supplyAfter = await stakingSupply(staking)
    const reserveAfter = await stakingReserve(staking)

    expect(stakeAfter).toBe(stakeBefore + STAKE_AMOUNT)
    expect(dtfAfter).toBe(dtfBefore - STAKE_AMOUNT)
    expect(supplyAfter).toBe(supplyBefore + STAKE_AMOUNT)
    expect(reserveAfter).toBe(reserveBefore)

    const stakedLabel = `${stakeAfter / 10n ** 18n} $DTF`
    await expect(overlay.getByText(stakedLabel).first()).toBeVisible({ timeout: 20_000 })
  })
})
