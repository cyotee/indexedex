import { encodeAbiParameters, keccak256 } from 'viem'

import type { V4PoolKey } from './v4Types'

const POOL_KEY_ABI = [
  { type: 'address' },
  { type: 'address' },
  { type: 'uint24' },
  { type: 'int24' },
  { type: 'address' },
] as const

/** PoolId = keccak256(abi.encode(PoolKey)) — 5 memory words, matching PoolIdLibrary.toId. */
export function toPoolId(key: V4PoolKey): `0x${string}` {
  return keccak256(
    encodeAbiParameters(POOL_KEY_ABI, [
      key.currency0,
      key.currency1,
      key.fee,
      key.tickSpacing,
      key.hooks,
    ]),
  )
}
