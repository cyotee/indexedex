import { test, expect, DEFAULT_E2E_RPC } from './wallet/fixture'
import { installInjectedWallet } from './wallet/injectWallet'
import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts'
import { connectInjectedWallet } from './helpers/connect'
import { publicClient } from './helpers/rpc'
import { createTestClient, erc20Abi, formatUnits, http, parseUnits, toEventSelector, type Address, type Hex } from 'viem'
import { loadSwapComparison } from '../app/staking/lib/swapComparison'
import { readProtocolDetf } from '../app/lib/tokenStaking/migration'
import platform from '../../../packages/protocol/src/addresses/chain/4663/platform.json'

test.describe('staking swap comparison on a mainnet fork', () => {
  test.skip(process.env.E2E_STAKING_SWAPS !== '1', 'Requires an explicitly selected local mainnet fork')
  test.setTimeout(180_000)
  const client = publicClient()
  const fork = createTestClient({ mode: 'anvil', transport: http(DEFAULT_E2E_RPC) })

  test.beforeEach(async () => {
    expect(['127.0.0.1', 'localhost']).toContain(new URL(DEFAULT_E2E_RPC).hostname)
    expect(await client.request({ method: 'web3_clientVersion' })).toMatch(/^anvil\//)
    expect(await client.getChainId()).toBe(4663)
    // An idle fork does not mine until a transaction; advance its clock before quoting.
    await fork.mine({ blocks: 1 })
  })

  test('either input synchronizes both quotes, direction and invalidation', async ({ walletPage: page }, testInfo) => {
    await page.goto('/staking', { waitUntil: 'domcontentloaded' })
    await expect(page.getByTestId('staking-swap-base')).toHaveAttribute('data-pool-id', /^0x/, { timeout: 60_000 })
    const base = page.getByTestId('staking-swap-base-amount-input')
    const reserve = page.getByTestId('staking-swap-reserve-amount-input')
    await base.fill('0.000001')
    await expect(reserve).toHaveValue('0.000001')
    for (const pool of ['base', 'reserve']) await expect(page.getByTestId(`staking-swap-${pool}-quote`)).toHaveText(/^\d.* DTF$/, { timeout: 60_000 })
    const old = await page.getByTestId('staking-swap-base-quote').innerText()
    await reserve.fill('0.000002')
    await expect(base).toHaveValue('0.000002')
    await expect(page.getByTestId('staking-swap-base-quote')).not.toHaveText(old)
    await reserve.fill('1e3')
    await expect(base).toHaveValue('1e3')
    for (const pool of ['base', 'reserve']) await expect(page.getByTestId(`staking-swap-${pool}-quote`)).toHaveText('— DTF')
    await page.getByTestId('staking-swap-reserve-direction').selectOption('sell')
    await expect(page.getByTestId('staking-swap-base-direction')).toHaveValue('sell')
    await expect(base).toHaveValue('')
    await reserve.fill('1')
    for (const pool of ['base', 'reserve']) await expect(page.getByTestId(`staking-swap-${pool}-quote`)).toHaveText(/^\d.* ETH$/, { timeout: 60_000 })
    await page.getByTestId('staking-swap-comparison').screenshot({ path: testInfo.outputPath('comparison-desktop.png') })
    await page.setViewportSize({ width: 390, height: 844 })
    await page.getByTestId('staking-swap-comparison').scrollIntoViewIfNeeded()
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
    await page.getByTestId('staking-swap-comparison').screenshot({ path: testInfo.outputPath('comparison-mobile.png') })
  })

  test('a reserve quote failure does not hide the base quote', async ({ page }) => {
    const staking = platform.tokenStaking as Address
    const detf = await readProtocolDetf(client, staking)
    if (!detf) throw new Error('Missing protocol DETF')
    const pools = await loadSwapComparison(client, staking, detf, platform)
    await page.goto('/staking', { waitUntil: 'domcontentloaded' })
    await expect(page.getByTestId('staking-swap-base')).toHaveAttribute('data-pool-id', /^0x/)
    await page.route(`${new URL(DEFAULT_E2E_RPC).origin}/**`, async route => {
      if (!route.request().postData()) { await route.continue(); return }
      const payload = route.request().postDataJSON() as { method?: string; params?: { to?: string; data?: string }[] }
      const call = payload.params?.[0]
      if (payload.method === 'eth_call' && call?.to?.toLowerCase() === pools.quoter.toLowerCase() && call.data?.toLowerCase().includes(pools.reserve.hooks.slice(2).toLowerCase())) {
        await route.abort('failed')
      } else await route.continue()
    })
    await page.getByTestId('staking-swap-base-amount-input').fill('0.000001')
    await expect(page.getByTestId('staking-swap-base-quote')).toHaveText(/^\d.* DTF$/, { timeout: 60_000 })
    await expect(page.getByTestId('staking-swap-reserve').getByRole('alert')).toBeVisible({ timeout: 60_000 })
    await expect(page.getByTestId('staking-swap-reserve-quote')).toHaveText('— DTF')
  })

  test('changing wallet during swap preparation prevents submission', async ({ page }) => {
    const key = generatePrivateKey()
    const account = privateKeyToAccount(key)
    await fork.setBalance({ address: account.address, value: parseUnits('10', 18) })
    const methods: string[] = []
    await installInjectedWallet(page, { privateKey: key, onRequest: request => methods.push(request.method) })
    await page.goto('/staking', { waitUntil: 'domcontentloaded' })
    await page.evaluate((router) => {
      type Request = { method: string; params?: { to?: string }[] }
      const state = window as unknown as {
        ethereum: { request: (args: Request) => Promise<unknown>; emit: (event: string, values: string[]) => void }
        releaseSwap?: () => void
        replacementAccount?: string
      }
      const original = state.ethereum.request.bind(state.ethereum)
      state.ethereum.request = args => {
        if (args.method === 'eth_accounts' && state.replacementAccount) return Promise.resolve([state.replacementAccount])
        if (args.method === 'eth_call' && args.params?.[0]?.to?.toLowerCase() === router.toLowerCase()) {
          return new Promise((resolve, reject) => { state.releaseSwap = () => { void original(args).then(resolve, reject) } })
        }
        return original(args)
      }
    }, platform.universalRouter)
    await connectInjectedWallet(page)
    await page.getByTestId('staking-swap-base-amount-input').fill('0.000001')
    const action = page.getByTestId('staking-swap-base-action')
    await expect(action).toHaveText('Swap via base pool', { timeout: 60_000 })
    await expect(action).toBeEnabled()
    await action.click()
    await expect.poll(() => page.evaluate(() => typeof (window as unknown as { releaseSwap?: unknown }).releaseSwap)).toBe('function')
    const replacement = privateKeyToAccount(generatePrivateKey()).address
    await page.evaluate((address) => {
      const state = window as unknown as { ethereum: { emit: (event: string, values: string[]) => void }; replacementAccount?: string; releaseSwap: () => void }
      state.replacementAccount = address
      state.ethereum.emit('accountsChanged', [address])
      state.releaseSwap()
    }, replacement)
    await expect(page.getByTestId('staking-swap-base-status')).toContainText('changed')
    expect(methods.filter(method => method === 'eth_sendTransaction' || method === 'eth_sendRawTransaction')).toEqual([])
    await expect(page.getByTestId('staking-swap-base-tx')).toHaveCount(0)
  })

  for (const pool of ['base', 'reserve'] as const) {
    test(`${pool} executes both directions with verified pool and recipient balances`, async ({ page }) => {
      const blockBefore = await client.getBlockNumber({ cacheTime: 0 })
      const snapshot = await fork.snapshot()
      try {
        // Public Anvil addresses can inherit mainnet delegation code. Use a fresh EOA.
        const privateKey = generatePrivateKey()
        const account = privateKeyToAccount(privateKey)
        await fork.setBalance({ address: account.address, value: parseUnits('10', 18) })
        expect((await client.getCode({ address: account.address })) ?? '0x').toBe('0x')
        await installInjectedWallet(page, { privateKey })
        const staking = platform.tokenStaking as Address
        const detf = await readProtocolDetf(client, staking)
        if (!detf) throw new Error('Missing protocol DETF')
        const pools = await loadSwapComparison(client, staking, detf, platform)
        const balance = () => client.readContract({ address: pools.dtf, abi: erc20Abi, functionName: 'balanceOf', args: [account.address] })
        const wethBalance = (owner: Address) => client.readContract({ address: pools.weth, abi: erc20Abi, functionName: 'balanceOf', args: [owner] })
        await page.goto('/staking', { waitUntil: 'domcontentloaded' })
        await connectInjectedWallet(page)
        const pay = page.getByTestId(`staking-swap-${pool}-amount-input`)
        const action = page.getByTestId(`staking-swap-${pool}-action`)
        const status = page.getByTestId(`staking-swap-${pool}-status`)
        const starting = await balance()
        const wethBefore = await wethBalance(account.address)
        const routerWethBefore = await wethBalance(pools.router)
        const routerEthBefore = await client.getBalance({ address: pools.router })
        await pay.fill('0.000001')
        await expect(action).toHaveText(`Swap via ${pool} pool`, { timeout: 60_000 })
        await expect(action).toBeEnabled()
        await action.click()
        await expect(status).toHaveText(`${pool === 'base' ? 'Base' : 'Reserve'} pool swap confirmed.`, { timeout: 120_000 })
        const bought = (await balance()) - starting
        expect(bought).toBeGreaterThan(0n)
        let hash = await page.getByTestId(`staking-swap-${pool}-tx`).innerText() as Hex
        let receipt = await client.getTransactionReceipt({ hash })
        expect(receipt.status).toBe('success')
        const expectedId = await page.getByTestId(`staking-swap-${pool}`).getAttribute('data-pool-id')
        const swapTopic = toEventSelector('Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)')
        expect(receipt.logs.some(log => log.address.toLowerCase() === platform.poolManager.toLowerCase() && log.topics[0] === swapTopic && log.topics[1]?.toLowerCase() === expectedId?.toLowerCase())).toBe(true)

        await page.getByTestId(`staking-swap-${pool}-direction`).selectOption('sell')
        const sellAmount = bought / 2n
        expect(sellAmount).toBeGreaterThan(0n)
        await pay.fill(formatUnits(sellAmount, pools.decimals))
        for (const label of ['Approve DTF', 'Allow DTF swaps']) {
          await expect(action).toBeEnabled({ timeout: 60_000 })
          if ((await action.innerText()) === label) {
            await action.click()
            await expect(status).toContainText('confirmed.', { timeout: 120_000 })
            await expect(action).not.toHaveText(label, { timeout: 60_000 })
          }
        }
        await expect(action).toHaveText(`Swap via ${pool} pool`, { timeout: 60_000 })
        const quotedEth = (await page.getByTestId(`staking-swap-${pool}-quote`).innerText()).split(' ')[0]
        const minimumEth = parseUnits(quotedEth, 18) * 9950n / 10000n
        const ethBefore = await client.getBalance({ address: account.address })
        await action.click()
        await expect(status).toHaveText(`${pool === 'base' ? 'Base' : 'Reserve'} pool swap confirmed.`, { timeout: 120_000 })
        hash = await page.getByTestId(`staking-swap-${pool}-tx`).innerText() as Hex
        receipt = await client.getTransactionReceipt({ hash })
        expect(receipt.status).toBe('success')
        expect(await balance()).toBe(starting + bought - sellAmount)
        const ethAfter = await client.getBalance({ address: account.address })
        expect(ethAfter + receipt.gasUsed * receipt.effectiveGasPrice - ethBefore).toBeGreaterThanOrEqual(minimumEth)
        expect(receipt.logs.some(log => log.address.toLowerCase() === platform.poolManager.toLowerCase() && log.topics[0] === swapTopic && log.topics[1]?.toLowerCase() === expectedId?.toLowerCase())).toBe(true)
        expect(await wethBalance(account.address)).toBe(wethBefore)
        expect(await wethBalance(pools.router)).toBe(routerWethBefore)
        expect(await client.getBalance({ address: pools.router })).toBe(routerEthBefore)
      } finally {
        await fork.revert({ id: snapshot })
        expect(await client.getBlockNumber({ cacheTime: 0 })).toBe(blockBefore)
      }
    })
  }

  test('confirmation failure locks both panels and retries the receipt without resubmitting', async ({ page }) => {
    const snapshot = await fork.snapshot()
    try {
      const key = generatePrivateKey()
      const account = privateKeyToAccount(key)
      await fork.setBalance({ address: account.address, value: parseUnits('10', 18) })
      const methods: string[] = []
      await installInjectedWallet(page, { privateKey: key, onRequest: request => methods.push(request.method) })
      await page.goto('/staking', { waitUntil: 'domcontentloaded' })
      await page.evaluate(() => {
        type Request = { method: string }
        const state = window as unknown as { ethereum: { request: (args: Request) => Promise<unknown> }; restoreConfirmation?: () => void }
        const original = state.ethereum.request.bind(state.ethereum)
        let sent = false
        let failConfirmation = true
        state.restoreConfirmation = () => { failConfirmation = false }
        state.ethereum.request = async args => {
          if (sent && failConfirmation && args.method === 'eth_chainId') throw new Error('Confirmation provider unavailable')
          const result = await original(args)
          if (args.method === 'eth_sendTransaction') sent = true
          return result
        }
      })
      await connectInjectedWallet(page)
      await page.getByTestId('staking-swap-base-amount-input').fill('0.000001')
      const action = page.getByTestId('staking-swap-base-action')
      await expect(action).toHaveText('Swap via base pool', { timeout: 60_000 })
      await expect(action).toBeEnabled()
      await action.click()
      const check = page.getByRole('button', { name: 'Check confirmation', exact: true })
      await expect(check).toBeVisible({ timeout: 60_000 })
      await expect(page.getByTestId('staking-swap-base-action')).toBeDisabled()
      await expect(page.getByTestId('staking-swap-reserve-action')).toBeDisabled()
      await expect(page.getByTestId('staking-swap-base-amount-input')).toBeDisabled()
      expect(methods.filter(method => method === 'eth_sendTransaction')).toHaveLength(1)
      await page.evaluate(() => (window as unknown as { restoreConfirmation: () => void }).restoreConfirmation())
      await check.click()
      await expect(page.getByTestId('staking-swap-base-status')).toHaveText('Base pool swap confirmed.', { timeout: 60_000 })
      expect(methods.filter(method => method === 'eth_sendTransaction')).toHaveLength(1)
    } finally {
      await fork.revert({ id: snapshot })
    }
  })
})
