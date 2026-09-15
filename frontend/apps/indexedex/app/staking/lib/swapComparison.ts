import { encodeAbiParameters, erc20Abi, keccak256, parseAbi, parseUnits, toHex, type Address, type PublicClient, type StateOverride } from 'viem'
import { readSePoolKey } from '../../swap/lib/v4Discover'
import { resolveV4Platform } from '../../swap/lib/v4Addresses'
import { quoteBestRoute } from '../../swap/lib/v4Quote'
import { ZERO_ADDRESS, sameAddress, sortCurrencies, type SwapRoute, type V4PoolKey } from '../../swap/lib/v4Types'
import { tokenStakingAbi } from '../../lib/tokenStaking/abi'
import { V4_QUOTER_ABI } from '../../swap/lib/v4Abis'

export type SwapPool = 'base' | 'reserve' | 'detf'
export type SwapDirection = 'buy' | 'sell'
export type ReserveSettlement = 'eth' | 'dtf'
export const MAX_SWAP_AMOUNT = (1n << 128n) - 1n
export function isSwapQuoteFresh(updatedAt: number, now = Date.now()): boolean {
  return updatedAt > 0 && now >= updatedAt && now - updatedAt <= 60_000
}
export function swapDeadline(chainTimestamp: bigint, now = Date.now()): bigint {
  const wallClock = BigInt(Math.floor(now / 1000))
  return (chainTimestamp > wallClock ? chainTimestamp : wallClock) + 1200n
}
export const permitAllowanceAbi = parseAbi([
  'function allowance(address owner,address token,address spender) view returns(uint160 amount,uint48 expiration,uint48 nonce)',
  'function approve(address token,address spender,uint160 amount,uint48 expiration)',
])
const bindingAbi = parseAbi([
  'function hook() view returns(address)',
  'function tokens() view returns(address[])',
  'function standardExchange(uint256 index) view returns(address)',
  'function poolManager() view returns(address)',
])

export function parseSwapAmount(value: string, decimals: number): bigint | undefined {
  const text = value.trim()
  if (text.length > 80) return
  if (!/^(?:\d+(?:\.\d*)?|\.\d+)$/.test(text) || !Number.isInteger(decimals) || decimals < 0 || decimals > 36) return
  if ((text.split('.')[1]?.length ?? 0) > decimals) return
  const amount = parseUnits(text, decimals)
  return amount > 0n && amount <= MAX_SWAP_AMOUNT ? amount : undefined
}

export async function loadSwapComparison(client: PublicClient, staking: Address, detf: Address, platform: Record<string, unknown>) {
  const addresses = resolveV4Platform(platform)
  const { weth, universalRouter: router, permit2, poolManager, quoter } = addresses
  if (!weth || !router || !permit2 || !poolManager || !quoter) throw new Error('Swap contracts are not configured on this network.')
  const blockNumber = await client.getBlockNumber({ cacheTime: 0 })
  const [dtf, hook] = await Promise.all([
    client.readContract({ address: staking, abi: tokenStakingAbi, functionName: 'stakingToken', blockNumber }),
    client.readContract({ address: detf, abi: bindingAbi, functionName: 'hook', blockNumber }),
  ])
  const [tokens, manager, decimals, detfDecimals, codes] = await Promise.all([
    client.readContract({ address: hook, abi: bindingAbi, functionName: 'tokens', blockNumber }),
    client.readContract({ address: hook, abi: bindingAbi, functionName: 'poolManager', blockNumber }),
    client.readContract({ address: dtf, abi: erc20Abi, functionName: 'decimals', blockNumber }),
    client.readContract({ address: detf, abi: erc20Abi, functionName: 'decimals', blockNumber }),
    Promise.all([router, permit2, quoter].map(address => client.getCode({ address, blockNumber }))),
  ])
  const wethIndex = tokens.findIndex(token => sameAddress(token, weth))
  if (wethIndex < 0 || !tokens.some(token => sameAddress(token, dtf)) || !tokens.some(token => sameAddress(token, detf)) || !sameAddress(manager, poolManager) || codes.some(code => !code || code === '0x')) {
    throw new Error('The deployed reserve or swap contracts do not match this network.')
  }
  const liquidityVault = await client.readContract({ address: hook, abi: bindingAbi, functionName: 'standardExchange', args: [BigInt(wethIndex)], blockNumber })
  const base = await readSePoolKey(client, liquidityVault, blockNumber)
  if (!base || !sameAddress(base.currency0, ZERO_ADDRESS) || !sameAddress(base.currency1, dtf)) {
    throw new Error('The base DTF/ETH pool could not be verified from the reserve.')
  }
  const reserve = reservePairKey(weth, dtf, hook)
  return { dtf, weth, decimals, detf, detfDecimals, router, permit2, poolManager, quoter, base, reserve }
}

function reservePairKey(tokenA: Address, tokenB: Address, hook: Address): V4PoolKey {
  const [currency0, currency1] = sortCurrencies(tokenA, tokenB)
  // Weighted pair doors use DYNAMIC_FEE_FLAG and tick spacing 1; validated by the quoter.
  // See UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.pairKey / TICK_SPACING.
  return { currency0, currency1, fee: 0x800000, tickSpacing: 1, hooks: hook }
}

export type SwapComparison = Awaited<ReturnType<typeof loadSwapComparison>>

export function getSwapMarket(pools: SwapComparison, pool: SwapPool, direction: SwapDirection, settlement: ReserveSettlement = 'eth') {
  const asset = pool === 'detf'
    ? { address: pools.detf, symbol: 'DTF-DETF', decimals: pools.detfDecimals }
    : { address: pools.dtf, symbol: 'DTF', decimals: pools.decimals }
  const counterIsNative = pool !== 'detf' || settlement === 'eth'
  const counter = counterIsNative
    ? { address: pool === 'base' ? ZERO_ADDRESS : pools.weth, symbol: 'ETH', decimals: 18 }
    : { address: pools.dtf, symbol: 'DTF', decimals: pools.decimals }
  const input = direction === 'buy' ? counter : asset
  const output = direction === 'buy' ? asset : counter
  const nativeIn = direction === 'buy' && counterIsNative
  const nativeOut = direction === 'sell' && counterIsNative
  return {
    poolKey: pool === 'detf' ? reservePairKey(asset.address, counter.address, pools.reserve.hooks) : pools[pool],
    tokenIn: input.address, tokenOut: output.address,
    payToken: nativeIn ? null : input.address,
    paySymbol: input.symbol, receiveSymbol: output.symbol,
    inDecimals: input.decimals, outDecimals: output.decimals,
    nativeIn, nativeOut,
  }
}

export async function quoteComparisonPool(client: PublicClient, pools: SwapComparison, pool: SwapPool, direction: SwapDirection, amountIn: bigint, account?: Address, settlement: ReserveSettlement = 'eth'): Promise<SwapRoute> {
  const { poolKey, tokenIn, tokenOut } = getSwapMarket(pools, pool, direction, settlement)
  if (pool === 'detf') {
    // Quotes must run inside PoolManager.unlock: the underlying SE's rate differs
    // outside an active swap. A direct hook preview can overstate executable output.
    let stateOverride: StateOverride | undefined
    if (sameAddress(tokenIn, pools.detf)) {
      // This Crane DETF uses ERC20Repo.Storage.balanceOf at STORAGE_SLOT + 4.
      // Fund only the quoter's eth_call; never donate input or override a real swap.
      const root = BigInt(keccak256(encodeAbiParameters([{ type: 'string' }], ['eip.erc.20']))) - 1n
      const slot = keccak256(encodeAbiParameters([{ type: 'address' }, { type: 'uint256' }], [pools.poolManager, root + 4n]))
      // MetaMask's block cache omits params after the block tag from its key,
      // conflating ordinary balance reads with overridden ones. Pending bypasses
      // that cache while keeping every request on the selected wallet provider.
      const balance = await client.readContract({ address: pools.detf, abi: erc20Abi, functionName: 'balanceOf', args: [pools.poolManager], blockTag: 'pending' })
      const fundedBalance = balance + amountIn
      stateOverride = [{ address: pools.detf, stateDiff: [{ slot, value: toHex(fundedBalance, { size: 32 }) }] }]
      // Fail closed if the deployment uses another layout or the RPC ignores overrides.
      const probe = await client.readContract({ address: pools.detf, abi: erc20Abi, functionName: 'balanceOf', args: [pools.poolManager], stateOverride, blockTag: 'pending' })
      if (probe !== fundedBalance) throw new Error('This RPC could not simulate reserve input funding. A swap quote is unavailable.')
    }
    const zeroForOne = sameAddress(tokenIn, poolKey.currency0)
    const { result } = await client.simulateContract({
      address: pools.quoter, abi: V4_QUOTER_ABI, functionName: 'quoteExactInputSingle',
      args: [{ poolKey, zeroForOne, exactAmount: amountIn, hookData: '0x' }],
      account, stateOverride, blockTag: stateOverride ? 'pending' : 'latest',
    })
    const amountOut = result[0]
    if (amountOut <= 0n) throw new Error('No quote from the reserve pool for this amount.')
    return { amountIn, amountOut, hops: [{ pool: poolKey, tokenIn, tokenOut, zeroForOne }] }
  }
  const route = await quoteBestRoute({ client, quoter: pools.quoter, pools: [poolKey], tokenIn, tokenOut, amountIn, account, maxHops: 1 })
  if (!route) throw new Error('No quote from this pool. Try a smaller amount or refresh.')
  return route
}

export type ApprovalStep = 'token' | 'permit' | 'swap'
export async function readSwapAllowance(client: PublicClient, pools: SwapComparison, account: Address, payToken: Address | null, amount: bigint): Promise<{ step: ApprovalStep; balance: bigint }> {
  if (payToken === null) return { step: 'swap', balance: await client.getBalance({ address: account }) }
  const [balance, tokenAllowance, [permitAmount, expiration], block] = await Promise.all([
    client.readContract({ address: payToken, abi: erc20Abi, functionName: 'balanceOf', args: [account] }),
    client.readContract({ address: payToken, abi: erc20Abi, functionName: 'allowance', args: [account, pools.permit2] }),
    client.readContract({ address: pools.permit2, abi: permitAllowanceAbi, functionName: 'allowance', args: [account, payToken, pools.router] }),
    client.getBlock(),
  ])
  const step = tokenAllowance < amount ? 'token' : permitAmount < amount || BigInt(expiration) <= swapDeadline(block.timestamp) - 1140n ? 'permit' : 'swap'
  return { step, balance }
}
