import { encodeAbiParameters, getContractAddress, keccak256, type Address, type Hex } from 'viem'

/** Uniswap v4 Hooks.ALL_HOOK_MASK — bottom 14 bits. */
export const HOOK_FLAG_MASK = (1n << 14n) - 1n

/** Peer of UniswapV4HookDiamondCreate2Lib.MAX_LOOP. */
export const HOOK_MINE_MAX_LOOP = 160_444

export const CP_HOOK_REQUIRED_FLAGS =
  (1n << 13n) | // BEFORE_INITIALIZE
  (1n << 11n) | // BEFORE_ADD_LIQUIDITY
  (1n << 7n) | // BEFORE_SWAP
  (1n << 3n) // BEFORE_SWAP_RETURNS_DELTA

/** Weighted SE buffer hook flags (DFPkg.requiredHookFlags). */
export const WEIGHTED_HOOK_REQUIRED_FLAGS =
  (1n << 13n) | // BEFORE_INITIALIZE
  (1n << 11n) | // BEFORE_ADD_LIQUIDITY
  (1n << 9n) | // BEFORE_REMOVE_LIQUIDITY
  (1n << 7n) | // BEFORE_SWAP
  (1n << 5n) | // BEFORE_DONATE
  (1n << 3n) // BEFORE_SWAP_RETURNS_DELTA

export function previewFinalSalt(packageSalt: Hex, mineNonce: bigint): Hex {
  return keccak256(
    encodeAbiParameters(
      [{ type: 'bytes32' }, { type: 'uint256' }],
      [packageSalt, mineNonce],
    ),
  )
}

export function predictHookAddress(
  factory: Address,
  initCodeHash: Hex,
  packageSalt: Hex,
  mineNonce: bigint,
): Address {
  return getContractAddress({
    opcode: 'CREATE2',
    from: factory,
    bytecodeHash: initCodeHash,
    salt: previewFinalSalt(packageSalt, mineNonce),
  })
}

export function flagsMatch(predicted: Address, requiredFlags: bigint): boolean {
  return (BigInt(predicted) & HOOK_FLAG_MASK) === (requiredFlags & HOOK_FLAG_MASK)
}

export function findMineNonce(
  factory: Address,
  initCodeHash: Hex,
  packageSalt: Hex,
  requiredFlags: bigint,
  maxLoop = HOOK_MINE_MAX_LOOP,
): bigint {
  const want = requiredFlags & HOOK_FLAG_MASK
  for (let n = 0n; n < BigInt(maxLoop); n++) {
    const predicted = predictHookAddress(factory, initCodeHash, packageSalt, n)
    if ((BigInt(predicted) & HOOK_FLAG_MASK) === want) return n
  }
  throw new Error('Hook mine exhausted. Try again or change the DETF name.')
}
