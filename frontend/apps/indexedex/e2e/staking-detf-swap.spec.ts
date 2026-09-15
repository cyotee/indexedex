import { test, expect } from '@playwright/test'
import { createTestClient, encodeFunctionData, erc20Abi, formatUnits, http, parseAbi, parseUnits, toEventSelector, type Address, type Hex } from 'viem'
import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts'
import { installInjectedWallet, DEFAULT_E2E_RPC } from './wallet/injectWallet'
import { connectInjectedWallet } from './helpers/connect'
import { publicClient } from './helpers/rpc'
import { loadSwapComparison } from '../app/staking/lib/swapComparison'
import { readProtocolDetf } from '../app/lib/tokenStaking/migration'
import platform from '../../../packages/protocol/src/addresses/chain/4663/platform.json'

test.describe('DTF-DETF reserve swaps', () => {
  test.skip(process.env.E2E_STAKING_SWAPS !== '1', 'Requires an explicitly selected local mainnet fork')
  test.setTimeout(240_000)
  const client = publicClient()
  const fork = createTestClient({ mode: 'anvil', transport: http(DEFAULT_E2E_RPC) })

  test.beforeEach(async () => {
    expect(['127.0.0.1', 'localhost']).toContain(new URL(DEFAULT_E2E_RPC).hostname)
    expect(await client.request({ method: 'web3_clientVersion' })).toMatch(/^anvil\//)
    expect(await client.getChainId()).toBe(4663)
    await fork.mine({ blocks: 1 })
  })

  test('defaults to selling DTF-DETF and preserves its amount when choosing ETH or DTF', async ({ page }, testInfo) => {
    await page.goto('/staking', { waitUntil: 'domcontentloaded' })
    await expect(page.getByTestId('staking-swap-detf')).toHaveAttribute('data-pool-id', /^0x/, { timeout: 60_000 })
    const panel = page.getByTestId('staking-detf-swap')
    const input = page.getByTestId('staking-swap-detf-amount-input')
    const output = page.getByTestId('staking-swap-detf-quote')
    const choice = page.getByTestId('staking-detf-settlement')
    await expect(page.getByTestId('staking-swap-detf-direction')).toHaveValue('sell')
    await expect(choice).toHaveValue('eth')
    await expect(choice.locator('option')).toHaveText(['ETH', 'DTF'])
    await page.getByTestId('staking-swap-base-amount-input').fill('0.000003')
    await input.fill('0.000001')
    await expect(output).toHaveText(/^\d.* ETH$/, { timeout: 60_000 })
    const ethPool = await page.getByTestId('staking-swap-detf').getAttribute('data-pool-id')
    await choice.selectOption('dtf')
    await expect(input).toHaveValue('0.000001')
    await expect(output).toHaveText(/^\d.* DTF$/, { timeout: 60_000 })
    expect(await page.getByTestId('staking-swap-detf').getAttribute('data-pool-id')).not.toBe(ethPool)
    await expect(page.getByTestId('staking-swap-base-amount-input')).toHaveValue('0.000003')
    await expect(page.getByTestId('staking-swap-reserve-amount-input')).toHaveValue('0.000003')
    await input.fill('0.0000000001')
    await expect(output).toHaveText('— DTF')
    await input.fill('0.000001')
    await expect(output).toHaveText(/^\d.* DTF$/)
    await panel.screenshot({ path: testInfo.outputPath('detf-swap-desktop.png') })
    await page.setViewportSize({ width: 390, height: 844 })
    await panel.scrollIntoViewIfNeeded()
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
    await panel.screenshot({ path: testInfo.outputPath('detf-swap-mobile.png') })
  })

  test('labels the approval after a failed simulation, then sells exactly 1 DTF-DETF for ETH', async ({ page }) => {
    const snapshot = await fork.snapshot()
    try {
      const key = generatePrivateKey()
      const account = privateKeyToAccount(key)
      await fork.setBalance({ address: account.address, value: parseUnits('10', 18) })
      expect((await client.getCode({ address: account.address })) ?? '0x').toBe('0x')
      const detf = await readProtocolDetf(client, platform.tokenStaking as Address)
      if (!detf) throw new Error('Missing protocol DETF')
      const pools = await loadSwapComparison(client, platform.tokenStaking as Address, detf, platform)
      const managerBalance = await client.readContract({ address: detf, abi: erc20Abi, functionName: 'balanceOf', args: [pools.poolManager] })
      const supply = await client.readContract({ address: detf, abi: erc20Abi, functionName: 'totalSupply' })
      const holder = await client.readContract({ address: detf, abi: parseAbi(['function rebasingClaimToken() view returns(address)']), functionName: 'rebasingClaimToken' })
      const amount = parseUnits('1', pools.detfDecimals)
      // Transfer existing inventory only on the verified fork; keep reserve state unchanged.
      await fork.impersonateAccount({ address: holder })
      try {
        await fork.setBalance({ address: holder, value: parseUnits('1', 18) })
        const hash = await client.request({ method: 'eth_sendTransaction', params: [{ from: holder, to: detf, gas: '0xf4240', data: encodeFunctionData({ abi: erc20Abi, functionName: 'transfer', args: [account.address, amount] }) }] })
        expect((await client.waitForTransactionReceipt({ hash })).status).toBe('success')
      } finally {
        await fork.stopImpersonatingAccount({ address: holder })
      }
      const methods: string[] = []
      await installInjectedWallet(page, { privateKey: key, onRequest: request => methods.push(request.method) })
      await page.goto('/staking', { waitUntil: 'domcontentloaded' })
      await page.evaluate((router) => {
        type Request = { method: string; params?: { to?: string }[] }
        const state = window as unknown as { ethereum: { request: (args: Request) => Promise<unknown> }; failSwapSimulation?: boolean }
        const original = state.ethereum.request.bind(state.ethereum)
        state.ethereum.request = async args => {
          if (state.failSwapSimulation && args.method === 'eth_call' && args.params?.[0]?.to?.toLowerCase() === router.toLowerCase()) {
            throw Object.assign(new Error('execution reverted'), { code: 3, data: '0x' })
          }
          return original(args)
        }
      }, pools.router)
      await connectInjectedWallet(page)
      await page.getByTestId('staking-swap-detf-amount-input').fill('1')
      const action = page.getByTestId('staking-swap-detf-action')
      const status = page.getByTestId('staking-swap-detf-status')
      for (const label of ['Approve DTF-DETF', 'Allow DTF-DETF swaps']) {
        await expect(action).toHaveText(label, { timeout: 60_000 })
        await expect(action).toBeEnabled()
        await action.click()
        await expect(status).toContainText('confirmed.', { timeout: 120_000 })
        await expect(action).not.toHaveText(label)
      }
      const approvalHash = await page.getByTestId('staking-swap-detf-tx').innerText()
      // Quoting can temporarily fund eth_call but must never change real manager inventory.
      expect(await client.readContract({ address: detf, abi: erc20Abi, functionName: 'balanceOf', args: [pools.poolManager] })).toBe(managerBalance)
      const sent = methods.filter(method => method === 'eth_sendTransaction').length
      await page.evaluate(() => { (window as unknown as { failSwapSimulation: boolean }).failSwapSimulation = true })
      await expect(action).toHaveText('Swap DTF-DETF for ETH')
      await action.click()
      await expect(status).toContainText('Simulation failed. No new transaction was submitted.')
      await expect(page.getByTestId('staking-swap-detf')).toContainText('Last submitted transaction: Swap permission.')
      await expect(page.getByTestId('staking-swap-detf-tx')).toHaveText(approvalHash)
      expect(methods.filter(method => method === 'eth_sendTransaction')).toHaveLength(sent)

      await page.evaluate(() => { (window as unknown as { failSwapSimulation: boolean }).failSwapSimulation = false })
      await expect(action).toBeEnabled()
      const before = await client.getBalance({ address: account.address })
      const quote = (await page.getByTestId('staking-swap-detf-quote').innerText()).split(' ')[0]
      await action.click()
      await expect(status).toHaveText('DTF-DETF reserve swap confirmed.', { timeout: 120_000 })
      const receipt = await client.getTransactionReceipt({ hash: await page.getByTestId('staking-swap-detf-tx').innerText() as Hex })
      expect(receipt.status).toBe('success')
      expect(await client.readContract({ address: detf, abi: erc20Abi, functionName: 'balanceOf', args: [account.address] })).toBe(0n)
      expect(await client.getBalance({ address: account.address }) + receipt.gasUsed * receipt.effectiveGasPrice - before).toBeGreaterThanOrEqual(parseUnits(quote, 18) * 9950n / 10000n)
      expect(await client.readContract({ address: detf, abi: erc20Abi, functionName: 'balanceOf', args: [pools.poolManager] })).toBe(managerBalance)
      expect(await client.readContract({ address: detf, abi: erc20Abi, functionName: 'totalSupply' })).toBe(supply)
    } finally {
      await fork.revert({ id: snapshot })
    }
  })

  test('does not show an executable quote when the RPC ignores simulation funding', async ({ page }) => {
    await page.goto('/staking', { waitUntil: 'domcontentloaded' })
    await expect(page.getByTestId('staking-swap-detf')).toHaveAttribute('data-pool-id', /^0x/, { timeout: 60_000 })
    await page.route(`${new URL(DEFAULT_E2E_RPC).origin}/**`, async route => {
      if (!route.request().postData()) { await route.continue(); return }
      const payload = route.request().postDataJSON() as { method?: string; params?: unknown[] }
      if (payload.method === 'eth_call' && (payload.params?.length ?? 0) > 2) {
        await route.continue({ postData: JSON.stringify({ ...payload, params: payload.params?.slice(0, 2) }) })
      } else await route.continue()
    })
    await page.getByTestId('staking-swap-detf-amount-input').fill('1')
    await expect(page.getByTestId('staking-swap-detf').getByRole('alert')).toContainText('could not simulate reserve input funding', { timeout: 60_000 })
    await expect(page.getByTestId('staking-swap-detf-quote')).toHaveText('— ETH')
  })

  for (const settlement of ['eth', 'dtf'] as const) {
    test(`sells wallet-held DTF-DETF for ${settlement.toUpperCase()} with exact reserve settlement`, async ({ page }) => {
      const snapshot = await fork.snapshot()
      try {
        const key = generatePrivateKey()
        const account = privateKeyToAccount(key)
        await fork.setBalance({ address: account.address, value: parseUnits('10', 18) })
        expect((await client.getCode({ address: account.address })) ?? '0x').toBe('0x')
        const staking = platform.tokenStaking as Address
        const detf = await readProtocolDetf(client, staking)
        if (!detf) throw new Error('Missing protocol DETF')
        const pools = await loadSwapComparison(client, staking, detf, platform)
        const balance = (token: Address, owner = account.address) => client.readContract({ address: token, abi: erc20Abi, functionName: 'balanceOf', args: [owner] })
        const managerBalance = await balance(detf, platform.poolManager as Address)
        const supply = await client.readContract({ address: detf, abi: erc20Abi, functionName: 'totalSupply' })
        await installInjectedWallet(page, { privateKey: key })
        await page.goto('/staking', { waitUntil: 'domcontentloaded' })
        await connectInjectedWallet(page)
        const input = page.getByTestId('staking-swap-detf-amount-input')
        const action = page.getByTestId('staking-swap-detf-action')
        const status = page.getByTestId('staking-swap-detf-status')
        const direction = page.getByTestId('staking-swap-detf-direction')
        await direction.selectOption('buy')
        await input.fill('0.00001')
        await expect(action).toHaveText('Swap ETH for DTF-DETF', { timeout: 60_000 })
        await expect(action).toBeEnabled()
        await action.click()
        await expect(status).toHaveText('DTF-DETF reserve swap confirmed.', { timeout: 120_000 })
        const acquired = await balance(detf)
        expect(acquired).toBeGreaterThan(1n)
        await direction.selectOption('sell')
        await page.getByTestId('staking-detf-settlement').selectOption(settlement)
        const amount = acquired / 2n
        await input.fill(formatUnits(amount, pools.detfDecimals))

        async function approve(symbol: string) {
          for (const label of [`Approve ${symbol}`, `Allow ${symbol} swaps`]) {
            await expect(action).toBeEnabled({ timeout: 60_000 })
            if ((await action.innerText()) === label) {
              await action.click()
              await expect(status).toContainText('confirmed.', { timeout: 120_000 })
              await expect(action).not.toHaveText(label, { timeout: 60_000 })
            }
          }
        }
        await approve('DTF-DETF')
        await expect(action).toHaveText(`Swap DTF-DETF for ${settlement.toUpperCase()}`, { timeout: 60_000 })
        const expectedPool = await page.getByTestId('staking-swap-detf').getAttribute('data-pool-id')
        const quoted = (await page.getByTestId('staking-swap-detf-quote').innerText()).split(' ')[0]
        const minOut = parseUnits(quoted, settlement === 'eth' ? 18 : pools.decimals) * 9950n / 10000n
        const before = settlement === 'eth' ? await client.getBalance({ address: account.address }) : await balance(pools.dtf)
        await action.click()
        await expect(status).toHaveText('DTF-DETF reserve swap confirmed.', { timeout: 120_000 })
        const hash = await page.getByTestId('staking-swap-detf-tx').innerText() as Hex
        const receipt = await client.getTransactionReceipt({ hash })
        expect(receipt.status).toBe('success')
        expect(await balance(detf)).toBe(acquired - amount)
        const after = settlement === 'eth' ? await client.getBalance({ address: account.address }) : await balance(pools.dtf)
        expect(after - before + (settlement === 'eth' ? receipt.gasUsed * receipt.effectiveGasPrice : 0n)).toBeGreaterThanOrEqual(minOut)
        const event = toEventSelector('Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)')
        expect(receipt.logs.some(log => log.address.toLowerCase() === platform.poolManager.toLowerCase() && log.topics[0] === event && log.topics[1]?.toLowerCase() === expectedPool?.toLowerCase())).toBe(true)
        expect(await balance(detf, platform.poolManager as Address)).toBe(managerBalance)
        expect(await balance(pools.weth)).toBe(0n)
        expect(await client.readContract({ address: detf, abi: erc20Abi, functionName: 'totalSupply' })).toBe(supply)

        if (settlement === 'dtf') {
          const dtfAmount = (after - before) / 2n
          await direction.selectOption('buy')
          await input.fill(formatUnits(dtfAmount, pools.decimals))
          await approve('DTF')
          await expect(action).toHaveText('Swap DTF for DTF-DETF', { timeout: 60_000 })
          const held = await balance(detf)
          const dtfBefore = await balance(pools.dtf)
          await action.click()
          await expect(status).toHaveText('DTF-DETF reserve swap confirmed.', { timeout: 120_000 })
          expect(await balance(pools.dtf)).toBe(dtfBefore - dtfAmount)
          expect(await balance(detf)).toBeGreaterThan(held)
        }
      } finally {
        await fork.revert({ id: snapshot })
      }
    })
  }
})
