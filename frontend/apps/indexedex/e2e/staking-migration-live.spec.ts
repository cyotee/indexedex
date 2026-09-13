import { test, expect } from '@playwright/test'
import { createPublicClient, http, erc20Abi, formatUnits, parseUnits, decodeFunctionData, type Address } from 'viem'
import { installInjectedWallet } from './wallet/injectWallet'
import { connectInjectedWallet, prepareLocalChain } from './helpers/connect'
import { tokenStakingAbi } from '../app/lib/tokenStaking/abi'
import { migrationRouteAbi, readProtocolDetf } from '../app/lib/tokenStaking/migration'
import platform from '../../../packages/protocol/src/addresses/chain/4663/platform.json'

// Explicit opt-in: ONLY a disposable copy of the already migrated node.
// No contracts are deployed, and the user's persistent fork is never mutated.
const rpcUrl = process.env.E2E_MIGRATION_RPC_URL
const holder = process.env.E2E_MIGRATION_HOLDER as Address | undefined
const staking = platform.tokenStaking as Address
let sy: Address
let sdetf: Address
const client = createPublicClient({ transport: http(rpcUrl ?? 'http://127.0.0.1:18545') })
async function rpc(method: string, params: unknown[] = []) {
  const res = await fetch(rpcUrl!, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }) })
  const data = await res.json()
  if (data.error) throw new Error(data.error.message)
  return data.result
}
const balance = (token: Address) => client.readContract({ address: token, abi: erc20Abi, functionName: 'balanceOf', args: [holder!] })
const stakeBalance = () => client.readContract({ address: staking, abi: tokenStakingAbi, functionName: 'balanceOf', args: [holder!] })

test.describe('Migrated staking on a disposable fork', () => {
  test.skip(!rpcUrl || !holder, 'Set E2E_MIGRATION_RPC_URL and E2E_MIGRATION_HOLDER to test existing migrated contracts.')
  let snapshot: string
  test.beforeEach(async () => {
    const url = new URL(rpcUrl!)
    expect(['127.0.0.1', 'localhost']).toContain(url.hostname)
    expect(url.port).not.toBe('8545')
    expect(await client.getChainId()).toBe(4663)
    expect(await client.readContract({ address: staking, abi: tokenStakingAbi, functionName: 'phase' })).toBe(2)
    const detf = await readProtocolDetf(client, staking)
    expect(detf).toBeTruthy()
    sy = await client.readContract({ address: detf!, abi: migrationRouteAbi, functionName: 'stakingSY' })
    sdetf = await client.readContract({ address: detf!, abi: migrationRouteAbi, functionName: 'rebasingClaimToken' })
    snapshot = await rpc('evm_snapshot')
    await rpc('anvil_impersonateAccount', [holder])
    await rpc('anvil_setBalance', [holder, '0x8ac7230489e80000'])
  })
  test.afterEach(async () => {
    if (snapshot) expect(await rpc('evm_revert', [snapshot])).toBe(true)
  })

  test('claims, delayed redemption, unstaking and restaking use the migrated product', async ({ page }) => {
    test.setTimeout(240_000)
    const stakeBefore = await stakeBalance()
    const syBefore = await balance(sy)
    expect(stakeBefore).toBeGreaterThan(parseUnits('100', 18))
    await installInjectedWallet(page, { rpcUrl, unlockedAddress: holder })
    await prepareLocalChain(page)
    await connectInjectedWallet(page)
    // Connected reads must not depend on the app's HTTP endpoint.
    await page.route('http://127.0.0.1:8545/**', route => route.abort())
    await page.goto(`/staking?detf=${platform.protocolDetf}`)
    const panel = page.getByTestId('migration-position')
    await expect(page.getByTestId('staking-detf')).toHaveAttribute('data-detf', (await readProtocolDetf(client, staking))!)
    await expect(panel.getByTestId('migration-complete')).toBeVisible({ timeout: 60_000 })
    const claim = panel.getByTestId('migration-claim')
    const input = panel.getByTestId('migration-claim-amount-input')
    for (const invalid of ['0', '-1', '1e18', '0.0000000000000000001', formatUnits(stakeBefore + 1n, 18)]) {
      await input.fill(invalid)
      await expect(claim).toBeDisabled()
    }
    await input.fill('0.000000000000000001')
    await expect(panel.getByText('This amount rounds to zero staking SY. Increase it or use Max.')).toBeVisible()
    await expect(claim).toBeDisabled()

    const partial = parseUnits('100', 18)
    const expectedSY = await client.readContract({ address: staking, abi: tokenStakingAbi, functionName: 'previewClaim', args: [holder!, partial] })
    await input.fill('100')
    await expect(claim).toBeEnabled()
    // Reject once at the wallet boundary. No contract call is mocked.
    await page.evaluate(() => {
      const eth = (window as any).ethereum
      const request = eth.request.bind(eth)
      let rejected = false
      eth.request = (args: { method: string }) => {
        if (args.method === 'eth_sendTransaction' && !rejected) {
          rejected = true
          return Promise.reject(Object.assign(new Error('User rejected the request'), { code: 4001 }))
        }
        return request(args)
      }
    })
    await claim.click()
    await expect(panel.getByTestId('migration-error')).toContainText('Transaction rejected in wallet')
    expect(await stakeBalance()).toBe(stakeBefore)
    expect(await balance(sy)).toBe(syBefore)
    // Losing receipt access must offer a confirmation retry, never resend the claim.
    await page.evaluate(() => {
      const eth = (window as any).ethereum
      const request = eth.request.bind(eth)
      ;(window as any).__restoreMigrationReceipt = () => { eth.request = request }
      eth.request = (args: { method: string }) => args.method === 'eth_getTransactionReceipt'
        ? Promise.reject(new Error('Receipt RPC unavailable')) : request(args)
    })
    await claim.click()
    await expect(panel.getByTestId('migration-check-confirmation')).toBeEnabled({ timeout: 70_000 })
    await expect(claim).toBeDisabled()
    await page.evaluate(() => (window as any).__restoreMigrationReceipt())
    await panel.getByTestId('migration-check-confirmation').click()
    await expect(panel.getByTestId('migration-status')).toContainText('Claim confirmed', { timeout: 60_000 })
    expect(await stakeBalance()).toBe(stakeBefore - partial)
    expect(await balance(sy)).toBe(syBefore + expectedSY)
    const claimHash = (await panel.getByTestId('migration-tx').innerText()).split('Transaction: ')[1] as `0x${string}`
    const claimTx = await client.getTransaction({ hash: claimHash })
    expect(claimTx.to?.toLowerCase()).toBe(staking.toLowerCase())
    expect(decodeFunctionData({ abi: tokenStakingAbi, data: claimTx.input })).toMatchObject({ functionName: 'withdrawClaim', args: [partial] })
    expect((await client.getTransactionReceipt({ hash: claimHash })).status).toBe('success')

    await panel.getByTestId('migration-claim-amount-max').click()
    await expect(claim).toBeEnabled()
    await claim.click()
    await expect(panel.getByTestId('migration-status')).toContainText('Claim confirmed', { timeout: 60_000 })
    expect(await stakeBalance()).toBe(0n)
    await expect(panel.getByTestId('migration-claimable')).toHaveText('0')

    // SY can be held through unsettled rewards and redeemed later.
    await rpc('evm_increaseTime', [90 * 24 * 60 * 60])
    await rpc('evm_mine')
    await page.reload()
    await expect(panel.getByTestId('migration-complete')).toBeVisible()
    const remainingSY = await balance(sy)
    const expectedSDETF = await client.readContract({ address: sy, abi: migrationRouteAbi, functionName: 'previewRedeem', args: [sdetf, remainingSY] })
    const sdetfBefore = await balance(sdetf)
    const redeem = panel.getByTestId('migration-redeem')
    await panel.getByTestId('migration-redeem-amount-input').fill('0.0000000001')
    await expect(redeem).toBeDisabled()
    await panel.getByTestId('migration-redeem-amount-max').click()
    await expect(redeem).toBeEnabled()
    await page.screenshot({ path: '/tmp/dtf-staking-migration-desktop.png', fullPage: true })
    await page.setViewportSize({ width: 390, height: 844 })
    await page.screenshot({ path: '/tmp/dtf-staking-migration-mobile.png', fullPage: true })
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true)
    await redeem.click()
    await expect(panel.getByTestId('migration-status')).toContainText('Redemption confirmed', { timeout: 60_000 })
    expect(await balance(sy)).toBe(0n)
    expect(await balance(sdetf)).toBeGreaterThanOrEqual(sdetfBefore + expectedSDETF)
    const redeemHash = (await panel.getByTestId('migration-tx').innerText()).split('Transaction: ')[1] as `0x${string}`
    const redeemTx = await client.getTransaction({ hash: redeemHash })
    const decoded = decodeFunctionData({ abi: migrationRouteAbi, data: redeemTx.input })
    expect(redeemTx.to?.toLowerCase()).toBe(sy.toLowerCase())
    expect(decoded.functionName).toBe('redeem')
    expect(decoded.args?.[0]?.toString().toLowerCase()).toBe(holder!.toLowerCase())
    expect(decoded.args?.[1]).toBe(remainingSY)
    expect(decoded.args?.[2]?.toString().toLowerCase()).toBe(sdetf.toLowerCase())
    expect(decoded.args?.[3]).toBeGreaterThan(0n)
    expect(decoded.args?.[4]).toBe(false)
    expect((await client.getTransactionReceipt({ hash: redeemHash })).status).toBe('success')
    await expect(panel.getByTestId('migration-empty')).toBeVisible()

    // The redeemed real sDETF must work in the staking controls on this same page.
    const detf = (await readProtocolDetf(client, staking))!
    const amount = parseUnits('0.001', 9)
    const detfBefore = await balance(detf)
    const claimBefore = await balance(sdetf)
    await page.getByRole('button', { name: 'Stake', exact: true }).click()
    const controls = page.getByTestId('detf-staking')
    await controls.getByRole('button', { name: 'Unstake', exact: true }).click()
    await controls.getByTestId('detf-unstake-amount-input').fill('0.001')
    await expect(controls.getByTestId('detf-unstake')).toBeEnabled()
    await controls.getByTestId('detf-unstake').click()
    await expect(controls.getByTestId('detf-staking-status')).toHaveText('Unstake confirmed.')
    expect(await balance(detf)).toBe(detfBefore + amount)
    expect(await balance(sdetf)).toBe(claimBefore - amount)

    await controls.getByRole('button', { name: 'Stake', exact: true }).click()
    await controls.getByTestId('detf-stake-token').selectOption(detf)
    await controls.getByTestId('detf-stake-amount-input').fill('0.001')
    const approval = controls.getByTestId('detf-stake-approve')
    if (await approval.isVisible()) {
      await expect(approval).toBeEnabled()
      await approval.click()
      await expect(controls.getByTestId('detf-staking-status')).toHaveText('Approve confirmed.')
    }
    await expect(controls.getByTestId('detf-stake')).toBeEnabled()
    await controls.getByTestId('detf-stake').click()
    await expect(controls.getByTestId('detf-staking-status')).toHaveText('Stake confirmed.')
    expect(await balance(detf)).toBe(detfBefore)
    expect(await balance(sdetf)).toBe(claimBefore)
  })

  test('disconnected and empty wallet states have no enabled claim action', async ({ page }) => {
    await installInjectedWallet(page, { rpcUrl })
    await prepareLocalChain(page)
    await page.goto('/staking')
    const panel = page.getByTestId('migration-position')
    await expect(panel.getByRole('button', { name: 'Connect wallet to view your position' })).toBeVisible()
    await connectInjectedWallet(page)
    await expect(panel.getByTestId('migration-empty')).toBeVisible()
    await expect(panel.getByTestId('migration-claim')).toBeDisabled()
    await expect(panel.getByTestId('migration-redeem')).toBeDisabled()
  })

  test('RPC failure, account changes and wrong network clear actionable positions', async ({ page }) => {
    await installInjectedWallet(page, { rpcUrl, unlockedAddress: holder })
    await prepareLocalChain(page)
    await connectInjectedWallet(page)
    await page.goto('/staking')
    const panel = page.getByTestId('migration-position')
    await expect(panel.getByTestId('migration-complete')).toBeVisible()
    await expect(page.getByText('RPC: connected wallet', { exact: true })).toBeVisible()
    await page.evaluate(() => {
      const eth = (window as any).ethereum
      const request = eth.request.bind(eth)
      ;(window as any).__restoreMigrationRPC = () => { eth.request = request }
      eth.request = (args: { method: string }) => args.method === 'eth_call'
        ? Promise.reject(new Error('Selected wallet RPC unavailable')) : request(args)
    })
    await expect(page.getByTestId('staking-discovery-status')).toContainText('Could not load DTF-DETF', { timeout: 30_000 })
    await expect(panel.getByTestId('migration-claim')).toHaveCount(0)
    await page.evaluate(() => (window as any).__restoreMigrationRPC())
    await page.getByTestId('staking-discovery-status').getByRole('button', { name: 'Retry', exact: true }).click()
    await expect(panel.getByTestId('migration-complete')).toBeVisible()
    await panel.getByTestId('migration-claim-amount-input').fill('100')
    await page.evaluate(() => {
      const eth = (window as any).ethereum
      const request = eth.request.bind(eth)
      const empty = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'
      eth.request = (args: { method: string }) => args.method === 'eth_accounts' ? Promise.resolve([empty]) : request(args)
      eth.emit('accountsChanged', [empty])
    })
    await expect(panel.getByTestId('migration-empty')).toBeVisible()
    await expect(panel.getByTestId('migration-claim-amount-input')).toHaveValue('')
    await page.evaluate(() => {
      const eth = (window as any).ethereum
      const request = eth.request.bind(eth)
      eth.request = (args: { method: string }) => args.method === 'eth_chainId' ? Promise.resolve('0x1') : request(args)
      eth.emit('chainChanged', '0x1')
    })
    await expect(page.getByTestId('staking-discovery-status')).toContainText('Switch your wallet to the selected network')
    await expect(panel.getByTestId('migration-claim')).toHaveCount(0)
  })

})
