import { erc20Abi, parseEther } from 'viem'
import { test, expect, DEFAULT_E2E_RPC } from './wallet/fixture'
import { loadPlatform } from './helpers/chainArtifacts'
import { dealErc20, erc20Balance, publicClient, rpcAlive, warmErc20Allowance } from './helpers/rpc'
import { tokenStakingAbi } from '../app/lib/tokenStaking/abi'
import { DTF_TOKEN, resolveTokenStakingAddress } from '../app/lib/tokenStaking/resolveAddress'

test('IndexedEx shows only staking and allows keyboard dismissal', async ({ page }) => {
  await page.goto('/')
  const overlay = page.getByTestId('token-staking-overlay')
  await expect(overlay.getByRole('heading', { name: 'Stake $DTF' })).toBeVisible()
  await expect(page.getByTestId('domain-announcement-overlay')).toHaveCount(0)
  await expect(page.getByText('Migration complete', { exact: true })).toHaveCount(0)
  await page.keyboard.press('Escape')
  await expect(overlay).toHaveCount(0)
  await expect(page.getByRole('link', { name: 'Join a live DETF' })).toBeVisible()
})

test('RainbowKit connects from staking; approval, staking and withdrawal change onchain balances', async ({ walletPage: page, walletAddress }) => {
  test.setTimeout(180_000)
  expect(['localhost', '127.0.0.1', '[::1]']).toContain(new URL(DEFAULT_E2E_RPC).hostname)
  test.skip(!(await rpcAlive()), 'Existing local Anvil is required; do not deploy a replacement.')
  const client = publicClient()
  expect(await client.request({ method: 'web3_clientVersion' })).toMatch(/anvil/i)
  expect(await client.getChainId()).toBe(4663)
  const staking = resolveTokenStakingAddress(loadPlatform(), process.env.NEXT_PUBLIC_TOKEN_STAKING)
  expect(staking).toBeDefined()
  const legacy = { address: staking!, abi: tokenStakingAbi } as const
  expect(await client.readContract({ ...legacy, functionName: 'phase' })).toBe(0)
  // Never withdraw a pre-existing position belonging to this test wallet.
  expect(await erc20Balance(staking!, walletAddress)).toBe(0n)
  const amount = parseEther('1')
  if (await erc20Balance(DTF_TOKEN, walletAddress) < amount) {
    expect(await dealErc20(DTF_TOKEN, walletAddress, parseEther('10'))).toBe(parseEther('10'))
  }
  await warmErc20Allowance(DTF_TOKEN, walletAddress, staking!, 0n)
  const before = await erc20Balance(DTF_TOKEN, walletAddress)
  const reserve = await client.readContract({ ...legacy, functionName: 'rewardReserve' })

  await page.goto('/')
  const overlay = page.getByTestId('token-staking-overlay')
  await overlay.getByRole('button', { name: 'Connect wallet', exact: true }).click()
  const walletChoice = page.getByRole('button', { name: 'Test Wallet', exact: true })
  await expect(walletChoice).toBeVisible()
  await walletChoice.click()
  await expect(overlay.locator('.dtf-landing__stake-connected')).toHaveAttribute('title', walletAddress)
  const input = overlay.getByTestId('token-staking-amount-input')
  await input.fill('1')
  const cta = overlay.getByTestId('token-staking-cta')
  await expect(cta).toHaveAttribute('data-gate', 'approve')
  await cta.click()
  await expect(cta).toHaveAttribute('data-gate', 'execute', { timeout: 90_000 })
  expect(await client.readContract({ address: DTF_TOKEN, abi: erc20Abi, functionName: 'allowance', args: [walletAddress, staking!] })).toBe(amount)
  await cta.click()
  await expect(overlay.getByRole('button', { name: 'Unstake', exact: true })).toBeEnabled({ timeout: 90_000 })
  expect(await erc20Balance(staking!, walletAddress)).toBe(amount)
  expect(await erc20Balance(DTF_TOKEN, walletAddress)).toBe(before - amount)
  expect(await client.readContract({ ...legacy, functionName: 'rewardReserve' })).toBe(reserve)

  const earned = await client.readContract({ ...legacy, functionName: 'earned', args: [walletAddress] })
  const rewards = overlay.getByRole('button', { name: 'Take $DTF rewards', exact: true })
  if (earned === 0n) {
    // An ended reward period must not advertise rewards for a new stake.
    await expect(rewards).toHaveCount(0)
  } else {
    await expect(rewards).toBeEnabled({ timeout: 30_000 })
    const beforeReward = await erc20Balance(DTF_TOKEN, walletAddress)
    await rewards.click()
    await expect(overlay.getByRole('button', { name: 'Unstake', exact: true })).toBeEnabled({ timeout: 90_000 })
    const paid = await erc20Balance(DTF_TOKEN, walletAddress) - beforeReward
    expect(paid).toBeGreaterThan(0n)
    expect(await client.readContract({ ...legacy, functionName: 'rewardReserve' })).toBe(reserve - paid)
  }

  const beforeWithdraw = await erc20Balance(DTF_TOKEN, walletAddress)
  await overlay.getByRole('button', { name: 'Unstake', exact: true }).click()
  await expect(overlay.getByRole('button', { name: 'Unstake', exact: true })).toHaveCount(0, { timeout: 90_000 })
  expect(await erc20Balance(staking!, walletAddress)).toBe(0n)
  expect(await erc20Balance(DTF_TOKEN, walletAddress)).toBe(beforeWithdraw + amount)
})
