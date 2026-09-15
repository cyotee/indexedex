import { concatHex, encodeAbiParameters, numberToHex } from 'viem'

import type { Address, SwapRoute, V4PathKey, V4PoolKey } from './v4Types'
import { isNativeCurrency, sameAddress } from './v4Types'

/** Universal Router Commands.V4_SWAP */
export const CMD_V4_SWAP = 0x10
/** Actions.SWAP_EXACT_IN_SINGLE / SWAP_EXACT_IN / SETTLE_ALL / TAKE_ALL */
export const ACTION_SWAP_EXACT_IN_SINGLE = 0x06
export const ACTION_SWAP_EXACT_IN = 0x07
export const ACTION_SETTLE_ALL = 0x0c
export const ACTION_TAKE_ALL = 0x0f

const POOL_KEY_COMPONENTS = [
  { name: 'currency0', type: 'address' },
  { name: 'currency1', type: 'address' },
  { name: 'fee', type: 'uint24' },
  { name: 'tickSpacing', type: 'int24' },
  { name: 'hooks', type: 'address' },
] as const

const PATH_KEY_COMPONENTS = [
  { name: 'intermediateCurrency', type: 'address' },
  { name: 'fee', type: 'uint24' },
  { name: 'tickSpacing', type: 'int24' },
  { name: 'hooks', type: 'address' },
  { name: 'hookData', type: 'bytes' },
] as const

export const UNIVERSAL_ROUTER_EXECUTE_ABI = [
  {
    type: 'function',
    name: 'execute',
    stateMutability: 'payable',
    inputs: [
      { name: 'commands', type: 'bytes' },
      { name: 'inputs', type: 'bytes[]' },
      { name: 'deadline', type: 'uint256' },
    ],
    outputs: [],
  },
] as const

function packedBytes(values: number[]): `0x${string}` {
  return concatHex(values.map((v) => numberToHex(v, { size: 1 })))
}

function encodeActionsAndParams(actions: number[], params: `0x${string}`[]): `0x${string}` {
  return encodeAbiParameters(
    [{ type: 'bytes' }, { type: 'bytes[]' }],
    [packedBytes(actions), params],
  )
}

function encodeExactInSingle(args: {
  poolKey: V4PoolKey
  zeroForOne: boolean
  amountIn: bigint
  amountOutMinimum: bigint
  hookData?: `0x${string}`
}): `0x${string}` {
  return encodeAbiParameters(
    [
      {
        type: 'tuple',
        components: [
          { name: 'poolKey', type: 'tuple', components: POOL_KEY_COMPONENTS },
          { name: 'zeroForOne', type: 'bool' },
          { name: 'amountIn', type: 'uint128' },
          { name: 'amountOutMinimum', type: 'uint128' },
          { name: 'minHopPriceX36', type: 'uint256' },
          { name: 'hookData', type: 'bytes' },
        ],
      },
    ],
    [
      {
        poolKey: args.poolKey,
        zeroForOne: args.zeroForOne,
        amountIn: args.amountIn,
        amountOutMinimum: args.amountOutMinimum,
        // Current Universal Router single-hop layout; absolute minimum remains enforced.
        minHopPriceX36: 0n,
        hookData: args.hookData ?? '0x',
      },
    ],
  )
}

function encodeExactIn(args: {
  currencyIn: Address
  path: V4PathKey[]
  amountIn: bigint
  amountOutMinimum: bigint
}): `0x${string}` {
  return encodeAbiParameters(
    [
      {
        type: 'tuple',
        components: [
          { name: 'currencyIn', type: 'address' },
          {
            name: 'path',
            type: 'tuple[]',
            components: PATH_KEY_COMPONENTS,
          },
          { name: 'maxHopSlippage', type: 'uint256[]' },
          { name: 'amountIn', type: 'uint128' },
          { name: 'amountOutMinimum', type: 'uint128' },
        ],
      },
    ],
    [
      {
        currencyIn: args.currencyIn,
        path: args.path,
        maxHopSlippage: [],
        amountIn: args.amountIn,
        amountOutMinimum: args.amountOutMinimum,
      },
    ],
  )
}

function encodeCurrencyAndAmount(currency: Address, amount: bigint): `0x${string}` {
  return encodeAbiParameters(
    [{ type: 'address' }, { type: 'uint256' }],
    [currency, amount],
  )
}

export type EncodedExecute = {
  commands: `0x${string}`
  inputs: `0x${string}`[]
  value: bigint
}

/**
 * EOA swap: V4_SWAP with SWAP_EXACT_IN(_SINGLE) → SETTLE_ALL (payer = user via Permit2)
 * → TAKE_ALL (recipient = user). Native ETH input goes in msg.value.
 */
export function encodeUniversalSwap(args: {
  route: SwapRoute
  amountOutMinimum: bigint
  nativeIn: boolean
  /** Wrap/unwrap WETH atomically when presenting a wrapped-native pool as ETH. */
  wrappedNative?: Address
  nativeOut?: boolean
  /** Pre-settle exact input for hooks that take input tokens during beforeSwap. */
  prepayInput?: boolean
}): EncodedExecute {
  const { route, amountOutMinimum, nativeIn } = args
  const hops = route.hops
  if (hops.length === 0) {
    throw new Error('No hops to encode')
  }

  const currencyIn = hops[0]!.tokenIn
  const currencyOut = hops[hops.length - 1]!.tokenOut
  const wrap = nativeIn && !isNativeCurrency(currencyIn)
  const unwrap = !!args.nativeOut && !isNativeCurrency(currencyOut)
  if ((wrap && (!args.wrappedNative || !sameAddress(currencyIn, args.wrappedNative))) ||
      (unwrap && (!args.wrappedNative || !sameAddress(currencyOut, args.wrappedNative)))) {
    throw new Error('Native settlement does not match the wrapped-native token')
  }
  const routerRecipient: Address = '0x0000000000000000000000000000000000000002'
  const senderRecipient: Address = '0x0000000000000000000000000000000000000001'
  let swapParam: `0x${string}`
  let swapAction: number

  if (hops.length === 1) {
    const hop = hops[0]!
    swapAction = ACTION_SWAP_EXACT_IN_SINGLE
    swapParam = encodeExactInSingle({
      poolKey: hop.pool,
      zeroForOne: hop.zeroForOne,
      amountIn: route.amountIn,
      amountOutMinimum,
    })
  } else {
    swapAction = ACTION_SWAP_EXACT_IN
    const path: V4PathKey[] = hops.map((hop) => ({
      intermediateCurrency: hop.tokenOut,
      fee: hop.pool.fee,
      tickSpacing: hop.pool.tickSpacing,
      hooks: hop.pool.hooks,
      hookData: '0x',
    }))
    swapParam = encodeExactIn({
      currencyIn,
      path,
      amountIn: route.amountIn,
      amountOutMinimum,
    })
  }

  const settleParam = wrap
      ? encodeAbiParameters([{ type: 'address' }, { type: 'uint256' }, { type: 'bool' }], [currencyIn, route.amountIn, false])
      : encodeCurrencyAndAmount(currencyIn, route.amountIn)
  const prepayParam = encodeAbiParameters([{ type: 'address' }, { type: 'uint256' }, { type: 'bool' }], [currencyIn, route.amountIn, !wrap])
  const takeParam = unwrap
      ? encodeAbiParameters([{ type: 'address' }, { type: 'address' }, { type: 'uint256' }], [currencyOut, routerRecipient, 0n])
      : encodeCurrencyAndAmount(currencyOut, amountOutMinimum)
  const actions = args.prepayInput
    ? [0x0b, swapAction, unwrap ? 0x0e : ACTION_TAKE_ALL]
    : [swapAction, wrap ? 0x0b : ACTION_SETTLE_ALL, unwrap ? 0x0e : ACTION_TAKE_ALL]
  const params = args.prepayInput ? [prepayParam, swapParam, takeParam] : [swapParam, settleParam, takeParam]
  const input = encodeActionsAndParams(actions, params)
  const commands = [CMD_V4_SWAP]
  const inputs = [input]
  if (wrap) {
    commands.unshift(0x0b) // Universal Router WRAP_ETH to itself; V4 SETTLE pays from its WETH.
    inputs.unshift(encodeCurrencyAndAmount(routerRecipient, route.amountIn))
  }
  if (unwrap) {
    commands.push(0x0c) // Universal Router UNWRAP_WETH to the original caller.
    inputs.push(encodeCurrencyAndAmount(senderRecipient, amountOutMinimum))
  }

  return {
    commands: packedBytes(commands),
    inputs,
    value: nativeIn ? route.amountIn : BigInt(0),
  }
}

export function pathFromRoute(route: SwapRoute): V4PathKey[] {
  return route.hops.map((hop) => ({
    intermediateCurrency: hop.tokenOut,
    fee: hop.pool.fee,
    tickSpacing: hop.pool.tickSpacing,
    hooks: hop.pool.hooks,
    hookData: '0x' as `0x${string}`,
  }))
}
