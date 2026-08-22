import { keccak256, stringToBytes, type PublicClient } from 'viem'

import { indexPoolsFromInitialize } from './v4Index'

import { STATE_VIEW_ABI, VAULT_TOKENS_ABI } from './v4Abis'
import { toPoolId } from './v4PoolId'
import {
  type Address,
  type V4PoolKey,
  ZERO_ADDRESS,
  poolKeyId,
  sortCurrencies,
  V4_FEE_TIERS,
} from './v4Types'

export type DiscoverReader = Pick<
  PublicClient,
  'readContract' | 'getStorageAt' | 'multicall' | 'getLogs' | 'getBlockNumber'
>

const SE_POOL_KEY_SLOT = keccak256(stringToBytes('indexedex.protocols.dexes.uniswap.v4.pool.key.aware'))

function wordToAddress(word: `0x${string}`): Address {
  return (`0x${word.slice(-40)}`) as Address
}

function addHex(slot: `0x${string}`, n: number): `0x${string}` {
  const next = BigInt(slot) + BigInt(n)
  return (`0x${next.toString(16).padStart(64, '0')}`) as `0x${string}`
}

function decodeInt24(raw: number): number {
  return raw >= 0x800000 ? raw - 0x1000000 : raw
}

function decodePackedFeeTickHooks(word: `0x${string}`): { fee: number; tickSpacing: number; hooks: Address } {
  const v = BigInt(word)
  const mask24 = BigInt(0xffffff)
  const fee = Number(v & mask24)
  const tickSpacing = decodeInt24(Number((v >> BigInt(24)) & mask24))
  const hookBits = (v >> BigInt(48)) & ((BigInt(1) << BigInt(160)) - BigInt(1))
  const hooks = (`0x${hookBits.toString(16).padStart(40, '0')}`) as Address
  return { fee, tickSpacing, hooks }
}

function isPlausibleKey(key: V4PoolKey): boolean {
  if (key.currency0.toLowerCase() >= key.currency1.toLowerCase()) return false
  if (key.tickSpacing <= 0 || key.tickSpacing > 16_384) return false
  if (key.fee > 1_000_000 && key.fee !== 0x800000) return false
  return true
}

async function readSePoolKey(client: DiscoverReader, vault: Address): Promise<V4PoolKey | null> {
  try {
    const [s0, s1, s2] = await Promise.all([
      client.getStorageAt({ address: vault, slot: SE_POOL_KEY_SLOT }),
      client.getStorageAt({ address: vault, slot: addHex(SE_POOL_KEY_SLOT, 1) }),
      client.getStorageAt({ address: vault, slot: addHex(SE_POOL_KEY_SLOT, 2) }),
    ])
    if (!s0 || !s1 || !s2) return null
    const currency0 = wordToAddress(s0)
    const currency1 = wordToAddress(s1)
    if (currency0 === ZERO_ADDRESS && currency1 === ZERO_ADDRESS) return null
    const packed = decodePackedFeeTickHooks(s2)
    const key: V4PoolKey = {
      currency0,
      currency1,
      fee: packed.fee,
      tickSpacing: packed.tickSpacing,
      hooks: packed.hooks,
    }
    return isPlausibleKey(key) ? key : null
  } catch {
    return null
  }
}

async function readVaultPair(client: DiscoverReader, vault: Address): Promise<[Address, Address] | null> {
  for (const fn of ['vaultTokens', 'tokens'] as const) {
    try {
      const tokens = (await client.readContract({
        address: vault,
        abi: VAULT_TOKENS_ABI,
        functionName: fn,
      })) as Address[]
      if (Array.isArray(tokens) && tokens.length >= 2) {
        return sortCurrencies(tokens[0]!, tokens[1]!)
      }
    } catch {
      /* try next */
    }
  }
  return null
}

async function isPoolLive(client: DiscoverReader, stateView: Address, key: V4PoolKey): Promise<boolean> {
  try {
    const poolId = toPoolId(key)
    const slot0 = (await client.readContract({
      address: stateView,
      abi: STATE_VIEW_ABI,
      functionName: 'getSlot0',
      args: [poolId],
    })) as readonly [bigint, number, number, number]
    return slot0[0] > BigInt(0)
  } catch {
    return false
  }
}

function candidateKeys(
  tokenA: Address,
  tokenB: Address,
  hooks: Address[],
): V4PoolKey[] {
  const [currency0, currency1] = sortCurrencies(tokenA, tokenB)
  const out: V4PoolKey[] = []
  const hookSet = new Set(hooks.map((h) => h.toLowerCase()))
  if (!hookSet.has(ZERO_ADDRESS)) hookSet.add(ZERO_ADDRESS)
  const hookList = Array.from(hookSet)
  for (let hi = 0; hi < hookList.length; hi++) {
    const hook = hookList[hi]!
    for (const tier of V4_FEE_TIERS) {
      out.push({
        currency0,
        currency1,
        fee: tier.fee,
        tickSpacing: tier.tickSpacing,
        hooks: hook as Address,
      })
    }
  }
  return out
}

/**
 * Discover live Uniswap v4 pools for listed tokens.
 * Includes vanilla (hooks = 0) and any hook we know from SE storage or extraHooks.
 * Does not filter by Uniswap's frontend hook allowlist.
 */
export async function discoverV4Pools(args: {
  client: DiscoverReader
  stateView: Address
  tokens: Address[]
  seVaults?: Address[]
  extraHooks?: Address[]
  poolManager?: Address | null
}): Promise<V4PoolKey[]> {
  const { client, stateView, tokens, seVaults = [], extraHooks = [], poolManager } = args
  const found = new Map<string, V4PoolKey>()
  const add = (key: V4PoolKey) => {
    found.set(poolKeyId(key), key)
  }

  const hookBag: Address[] = extraHooks.slice()
  if (poolManager) {
    const fromLogs = await indexPoolsFromInitialize({ client, poolManager })
    for (let i = 0; i < fromLogs.length; i++) {
      const key = fromLogs[i]!
      add(key)
      if (key.hooks.toLowerCase() !== ZERO_ADDRESS) hookBag.push(key.hooks)
    }
  }

  for (const vault of seVaults) {
    const stored = await readSePoolKey(client, vault)
    if (stored) {
      add(stored)
      if (stored.hooks.toLowerCase() !== ZERO_ADDRESS) hookBag.push(stored.hooks)
    }
    const pair = await readVaultPair(client, vault)
    if (pair) {
      for (const key of candidateKeys(pair[0], pair[1], hookBag)) add(key)
    }
  }

  const uniqTokens = Array.from(new Set(tokens.map((t) => t.toLowerCase()))) as Address[]
  for (let i = 0; i < uniqTokens.length; i++) {
    for (let j = i + 1; j < uniqTokens.length; j++) {
      for (const key of candidateKeys(uniqTokens[i]!, uniqTokens[j]!, hookBag)) {
        add(key)
      }
    }
  }

  const live: V4PoolKey[] = []
  const keys = Array.from(found.values())
  const chunk = 40
  for (let i = 0; i < keys.length; i += chunk) {
    const slice = keys.slice(i, i + chunk)
    const checks = await Promise.all(slice.map((key) => isPoolLive(client, stateView, key)))
    slice.forEach((key, idx) => {
      if (checks[idx]) live.push(key)
    })
  }
  return live
}
