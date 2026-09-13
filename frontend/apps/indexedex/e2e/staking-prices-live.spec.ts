import { createPublicClient, http, erc20Abi, parseAbi, formatUnits, type Address } from 'viem'
import { test, expect, DEFAULT_E2E_RPC } from './wallet/fixture'
import { connectInjectedWallet, prepareLocalChain } from './helpers/connect'
import { readProtocolDetf } from '../app/lib/tokenStaking/migration'
import platform from '../../../packages/protocol/src/addresses/chain/4663/platform.json'

/** Read-only verification against the existing deployment. No transactions or node resets. */
test('both synthetic prices match their onchain legs and remain visible together', async ({ walletPage: page }) => {
  test.skip(process.env.E2E_LIVE_PRICES !== '1', 'Opt in against the existing local deployment.')
  const client = createPublicClient({ transport: http(DEFAULT_E2E_RPC) })
  const detf = (await readProtocolDetf(client, platform.tokenStaking as Address))!
  expect(detf).toBeTruthy()
  const bindingAbi = parseAbi(['function hook() view returns (address)', 'function bondNftVault() view returns (address)'])
  const hook = await client.readContract({ address: detf, abi: bindingAbi, functionName: 'hook' })
  const bondNftVault = await client.readContract({ address: detf, abi: bindingAbi, functionName: 'bondNftVault' })
  const abi = parseAbi([
    'function syntheticPrice() view returns (uint256)',
    'function creationPairPerDetfWad() view returns (uint256[])',
    'function syntheticNumeraires() view returns (address[])',
    'function previewBurnToToken(uint256 shares, address token) view returns (uint256)',
    'function isMintingAllowed(address token) view returns (bool)',
    'function isBurningAllowed(address token) view returns (bool)',
    'function mintThreshold() view returns (uint256)',
    'function burnThreshold() view returns (uint256)',
  ])
  const blockNumber = await client.getBlockNumber({ cacheTime: 0 })
  const [pairs, creation, supply, held, bonded, mint, burn, firstPrice] = await Promise.all([
    client.readContract({ address: hook, abi, functionName: 'syntheticNumeraires', blockNumber }),
    client.readContract({ address: detf, abi, functionName: 'creationPairPerDetfWad', blockNumber }),
    client.readContract({ address: detf, abi: erc20Abi, functionName: 'totalSupply', blockNumber }),
    client.readContract({ address: hook, abi: erc20Abi, functionName: 'balanceOf', args: [detf], blockNumber }),
    client.readContract({ address: hook, abi: erc20Abi, functionName: 'balanceOf', args: [bondNftVault], blockNumber }),
    client.readContract({ address: detf, abi, functionName: 'mintThreshold', blockNumber }),
    client.readContract({ address: detf, abi, functionName: 'burnThreshold', blockNumber }),
    client.readContract({ address: detf, abi, functionName: 'syntheticPrice', blockNumber }),
  ])
  expect(pairs).toHaveLength(2)
  const prices = await Promise.all(pairs.map(async (pair, index) => {
    const [payout, decimals, mintAllowed, burnAllowed] = await Promise.all([
      client.readContract({ address: hook, abi, functionName: 'previewBurnToToken', args: [held + bonded, pair], blockNumber }),
      client.readContract({ address: pair, abi: erc20Abi, functionName: 'decimals', blockNumber }),
      client.readContract({ address: detf, abi, functionName: 'isMintingAllowed', args: [pair], blockNumber }),
      client.readContract({ address: detf, abi, functionName: 'isBurningAllowed', args: [pair], blockNumber }),
    ])
    // Independent check from the quoted liquidation value and creation benchmark.
    const payoutWad = decimals <= 18 ? payout * 10n ** BigInt(18 - decimals) : payout / 10n ** BigInt(decimals - 18)
    const price = ((payoutWad * 10n ** 18n) / (supply * 10n ** 9n)) * 10n ** 18n / creation[index]
    expect(mintAllowed).toBe(price > mint)
    expect(burnAllowed).toBe(price < burn)
    return price
  }))
  expect(prices[0]).toBe(firstPrice)
  expect(prices[1]).not.toBe(firstPrice)

  await prepareLocalChain(page)
  await connectInjectedWallet(page)
  await page.goto('/staking')
  const section = page.getByTestId('detf-synthetic-prices')
  await expect(section.getByTestId('detf-synthetic-price')).toHaveCount(2)
  await expect(section.getByText('WETH synthetic price', { exact: true })).toBeVisible()
  await expect(section.getByText('DTF synthetic price', { exact: true })).toBeVisible()
  for (let i = 0; i < pairs.length; i++) {
    await expect(section.locator(`[data-pair="${pairs[i]}"]`).getByTestId('synthetic-price-value')).toHaveText(formatUnits(prices[i], 18))
  }
  await section.scrollIntoViewIfNeeded()
  await page.screenshot({ path: '/tmp/dtf-two-prices-desktop.png' })
  await page.setViewportSize({ width: 390, height: 844 })
  await section.scrollIntoViewIfNeeded()
  for (const label of ['WETH synthetic price', 'DTF synthetic price']) {
    await expect(section.getByText(label, { exact: true })).toBeInViewport()
  }
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  await page.screenshot({ path: '/tmp/dtf-two-prices-mobile.png' })
})
