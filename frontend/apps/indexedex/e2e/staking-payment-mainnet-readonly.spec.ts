import { test, expect } from '@playwright/test'
import { createPublicClient, decodeFunctionData, encodeAbiParameters, erc20Abi, getAddress, http, keccak256, parseAbi, toHex, type Address } from 'viem'
import { installInjectedWallet } from './wallet/injectWallet'
import { connectInjectedWallet, selectByValue, waitForOption } from './helpers/connect'
import { loadPlatform } from './helpers/chainArtifacts'
import { stakingExchangeRoute } from '../app/insights/lib/claimMint'

const wallet = getAddress(process.env.E2E_MAINNET_WALLET ?? '0xec8c4eb216cbfc5b7f49b83cfbe6e34212863ae8')
const rpcUrl = process.env.E2E_MAINNET_RPC_URL ?? 'https://rpc.mainnet.chain.robinhood.com'
const exchangeAbi = parseAbi(['function exchangeIn(address,uint256,address,uint256,address,bool,uint256) returns(uint256)'])

test('10 DTF acquires wallet-held DETF before a separately reviewed stake', async ({ page }) => {
  test.skip(process.env.E2E_MAINNET_READONLY !== '1', 'Read-only mainnet verification is opt-in')
  test.setTimeout(180_000)
  const requests: { method: string; params?: unknown[] }[] = []
  await installInjectedWallet(page, { rpcUrl, chainId: 4663, readOnlyAddress: wallet, onRequest: (request) => requests.push(request) })
  await page.goto('/staking?tab=stake', { waitUntil: 'domcontentloaded' })
  await connectInjectedWallet(page)
  const detf = await page.getByTestId('staking-detf').getAttribute('data-detf') as Address
  const client = createPublicClient({ transport: http(rpcUrl) })
  const dtf = { address: await client.readContract({ address: loadPlatform().tokenStaking as Address, abi: parseAbi(['function stakingToken() view returns(address)']), functionName: 'stakingToken' }) }
  await waitForOption(page, 'detf-stake-token', dtf.address)
  await selectByValue(page, 'detf-stake-token', dtf.address)
  await page.getByTestId('detf-stake-amount-input').fill('10')
  await expect(page.getByTestId('detf-stake-steps')).toContainText('Each step requires a separate transaction')
  const acquire = page.getByTestId('detf-stake')
  await expect(acquire).toContainText('Step 1: acquire')
  await expect(acquire).toBeEnabled()
  await acquire.click()
  // The fixture rejects submission. Reaching it proves the preceding real eth_call succeeded.
  await expect.poll(() => requests.filter((request) => request.method === 'eth_sendTransaction').length).toBe(1)
  const sent = requests.filter((request) => request.method === 'eth_sendTransaction')
  expect(sent).toHaveLength(1)
  const tx = sent[0]!.params![0] as { to: Address; data: `0x${string}` }
  expect(tx.to.toLowerCase()).toBe(detf.toLowerCase())
  const decoded = decodeFunctionData({ abi: exchangeAbi, data: tx.data })
  expect(decoded.args[0].toLowerCase()).toBe(dtf.address.toLowerCase())
  expect(decoded.args[1]).toBe(10n ** 19n)
  expect(decoded.args[2].toLowerCase()).toBe(detf.toLowerCase())
  expect(decoded.args[3]).toBeGreaterThan(0n)
  expect(decoded.args[4].toLowerCase()).toBe(wallet.toLowerCase())
  expect(decoded.args[5]).toBe(false)
  expect(requests.some((request) => request.method === 'eth_call' && (request.params?.[0] as { data?: string })?.data === tx.data)).toBe(true)

  // Independently verify direct staking against deployed code. Only eth_call uses
  // temporary storage overrides for the acquired balance and approval; nothing is
  // persisted or sent. This is not a completed onchain two-transaction lifecycle.
  const block = await client.getBlock()
  const staking = await client.readContract({ address: detf, abi: parseAbi(['function rebasingClaimToken() view returns(address)']), functionName: 'rebasingClaimToken', blockNumber: block.number })
  const amount = await client.simulateContract({ account: wallet, address: detf, abi: exchangeAbi, functionName: 'exchangeIn',
    args: [dtf.address, 10n ** 19n, detf, 1n, wallet, false, block.timestamp + 1200n], blockNumber: block.number }).then((result) => result.result)
  // ERC20Repo: keccak256(abi.encode("eip.erc.20")) - 1; balances +4, allowances +5.
  const base = BigInt(keccak256(encodeAbiParameters([{ type: 'string' }], ['eip.erc.20']))) - 1n
  const slot = (owner: Address, at: bigint) => keccak256(encodeAbiParameters([{ type: 'address' }, { type: 'uint256' }], [owner, at]))
  const balanceSlot = slot(wallet, base + 4n)
  const approvalSlot = slot(staking, BigInt(slot(wallet, base + 5n)))
  const stateOverride = [{ address: detf, stateDiff: [
    { slot: balanceSlot, value: toHex(amount, { size: 32 }) },
    { slot: approvalSlot, value: toHex(amount, { size: 32 }) },
  ] }]
  expect(await client.readContract({ address: detf, abi: erc20Abi, functionName: 'balanceOf', args: [wallet], stateOverride })).toBe(amount)
  const route = stakingExchangeRoute({ detf, stakingToken: staking, tokenIn: detf, unstake: false })!
  const result = await client.simulateContract({ account: wallet, address: route.target, abi: exchangeAbi, functionName: 'exchangeIn',
    args: [route.tokenIn, amount, route.tokenOut, amount, wallet, false, block.timestamp + 1200n], stateOverride, blockNumber: block.number })
  expect(result.result).toBe(amount)
})
