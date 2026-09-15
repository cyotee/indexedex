import { describe, expect, it } from 'vitest'
import { decodeAbiParameters, parseAbiParameters, type Address } from 'viem'
import { getSwapMarket, isSwapQuoteFresh, MAX_SWAP_AMOUNT, parseSwapAmount, swapDeadline, type SwapComparison } from './swapComparison'
import { encodeUniversalSwap } from '../../swap/lib/v4Encode'
import { ZERO_ADDRESS, type SwapRoute } from '../../swap/lib/v4Types'

const weth: Address = '0x0000000000000000000000000000000000000010'
const dtf: Address = '0x0000000000000000000000000000000000000020'
const hook: Address = '0x0000000000000000000000000000000000000030'
const detf: Address = '0x0000000000000000000000000000000000000040'
const routerRecipient = '0x0000000000000000000000000000000000000002'
const senderRecipient = '0x0000000000000000000000000000000000000001'
function route(tokenIn: Address, tokenOut: Address): SwapRoute {
  return { amountIn: 100n, amountOut: 200n, hops: [{
    tokenIn, tokenOut, zeroForOne: tokenIn.toLowerCase() < tokenOut.toLowerCase(),
    pool: { currency0: tokenIn < tokenOut ? tokenIn : tokenOut, currency1: tokenIn < tokenOut ? tokenOut : tokenIn, fee: 0x800000, tickSpacing: 1, hooks: hook },
  }] }
}

describe('staking swap comparison amounts and native settlement', () => {
  const pools: SwapComparison = { dtf, weth, detf, decimals: 18, detfDecimals: 9, router: hook, permit2: hook, poolManager: hook, quoter: hook, base: route(ZERO_ADDRESS, dtf).hops[0].pool, reserve: route(weth, dtf).hops[0].pool }
  it('sells 9-decimal DTF-DETF for native ETH through its WETH reserve pair', () => {
    expect(getSwapMarket(pools, 'detf', 'sell', 'eth')).toMatchObject({ tokenIn: detf, tokenOut: weth, payToken: detf, paySymbol: 'DTF-DETF', receiveSymbol: 'ETH', inDecimals: 9, outDecimals: 18, nativeIn: false, nativeOut: true })
    expect(getSwapMarket(pools, 'detf', 'sell', 'eth').poolKey).toEqual({ currency0: weth, currency1: detf, fee: 0x800000, tickSpacing: 1, hooks: hook })
  })
  it('sells DTF-DETF for DTF without native wrapping or unwrapping', () => {
    expect(getSwapMarket(pools, 'detf', 'sell', 'dtf')).toMatchObject({ tokenIn: detf, tokenOut: dtf, payToken: detf, inDecimals: 9, outDecimals: 18, nativeIn: false, nativeOut: false })
    expect(getSwapMarket(pools, 'detf', 'sell', 'dtf').poolKey.currency0).toBe(dtf)
  })
  it('reverses to buy DTF-DETF with either ETH or ERC20 DTF', () => {
    expect(getSwapMarket(pools, 'detf', 'buy', 'eth')).toMatchObject({ tokenIn: weth, tokenOut: detf, payToken: null, nativeIn: true, nativeOut: false, inDecimals: 18, outDecimals: 9 })
    expect(getSwapMarket(pools, 'detf', 'buy', 'dtf')).toMatchObject({ tokenIn: dtf, tokenOut: detf, payToken: dtf, nativeIn: false, nativeOut: false, inDecimals: 18, outDecimals: 9 })
  })
  it('does not apply DTF decimal precision to DTF-DETF inputs', () => {
    expect(parseSwapAmount('0.000000001', getSwapMarket(pools, 'detf', 'sell').inDecimals)).toBe(1n)
    expect(parseSwapAmount('0.0000000001', getSwapMarket(pools, 'detf', 'sell').inDecimals)).toBeUndefined()
  })
  it.each(['', '0', '-1', '1e3', 'NaN', 'Infinity', '0.0000000000000000001', '1,000'])('rejects invalid input %s', value => {
    expect(parseSwapAmount(value, 18)).toBeUndefined()
  })
  it('preserves exact units and uint128 bounds', () => {
    expect(parseSwapAmount('.5', 18)).toBe(500000000000000000n)
    expect(parseSwapAmount('1.234567', 6)).toBe(1234567n)
    expect(parseSwapAmount('1.2345678', 6)).toBeUndefined()
    expect(parseSwapAmount(String(MAX_SWAP_AMOUNT), 0)).toBe(MAX_SWAP_AMOUNT)
    expect(parseSwapAmount(String(MAX_SWAP_AMOUNT + 1n), 0)).toBeUndefined()
  })
  it('keeps deadlines valid for idle and time-shifted forks', () => {
    expect(swapDeadline(1000n, 1000000)).toBe(2200n)
    expect(swapDeadline(1000n, 2000000)).toBe(3200n)
    expect(swapDeadline(3000n, 2000000)).toBe(4200n)
  })
  it('rejects expired, missing and future-dated quote timestamps', () => {
    expect(isSwapQuoteFresh(1000, 61000)).toBe(true)
    expect(isSwapQuoteFresh(1000, 61001)).toBe(false)
    expect(isSwapQuoteFresh(0, 1000)).toBe(false)
    expect(isSwapQuoteFresh(2000, 1000)).toBe(false)
  })
  it('keeps native base swaps unchanged', () => {
    const encoded = encodeUniversalSwap({ route: route(ZERO_ADDRESS, dtf), amountOutMinimum: 190n, nativeIn: true })
    expect(encoded.commands).toBe('0x10')
    expect(encoded.value).toBe(100n)
    expect(decodeAbiParameters([{ type: 'bytes' }, { type: 'bytes[]' }], encoded.inputs[0])[0]).toBe('0x060c0f')
  })
  it('wraps ETH into router custody and settles WETH without user allowance', () => {
    const encoded = encodeUniversalSwap({ route: route(weth, dtf), amountOutMinimum: 190n, nativeIn: true, wrappedNative: weth })
    expect(encoded.commands).toBe('0x0b10')
    expect(encoded.value).toBe(100n)
    expect(decodeAbiParameters([{ type: 'address' }, { type: 'uint256' }], encoded.inputs[0])).toEqual([routerRecipient, 100n])
    const [actions, params] = decodeAbiParameters([{ type: 'bytes' }, { type: 'bytes[]' }], encoded.inputs[1])
    expect(actions).toBe('0x060b0f')
    const [swap] = decodeAbiParameters(parseAbiParameters('((address currency0,address currency1,uint24 fee,int24 tickSpacing,address hooks) poolKey,bool zeroForOne,uint128 amountIn,uint128 amountOutMinimum,uint256 minHopPriceX36,bytes hookData)'), params[0])
    expect(swap).toMatchObject({ amountIn: 100n, amountOutMinimum: 190n, minHopPriceX36: 0n, hookData: '0x' })
    expect(decodeAbiParameters([{ type: 'address' }, { type: 'uint256' }, { type: 'bool' }], params[1])).toEqual([weth, 100n, false])
  })
  it('takes reserve WETH to router then unwraps to the caller with a minimum', () => {
    const encoded = encodeUniversalSwap({ route: route(dtf, weth), amountOutMinimum: 190n, nativeIn: false, nativeOut: true, wrappedNative: weth })
    expect(encoded.commands).toBe('0x100c')
    expect(encoded.value).toBe(0n)
    const [actions, params] = decodeAbiParameters([{ type: 'bytes' }, { type: 'bytes[]' }], encoded.inputs[0])
    expect(actions).toBe('0x060c0e')
    expect(decodeAbiParameters([{ type: 'address' }, { type: 'address' }, { type: 'uint256' }], params[2])).toEqual([weth, routerRecipient, 0n])
    expect(decodeAbiParameters([{ type: 'address' }, { type: 'uint256' }], encoded.inputs[1])).toEqual([senderRecipient, 190n])
  })
  it('rejects wrapping an unrelated ERC20', () => {
    expect(() => encodeUniversalSwap({ route: route(dtf, weth), amountOutMinimum: 1n, nativeIn: true, wrappedNative: weth })).toThrow('Native settlement')
  })
  it('pre-settles exact DTF-DETF input via the caller before swapping and unwrapping', () => {
    const encoded = encodeUniversalSwap({ route: route(detf, weth), amountOutMinimum: 190n, nativeIn: false, nativeOut: true, wrappedNative: weth, prepayInput: true })
    expect(encoded.commands).toBe('0x100c')
    const [actions, params] = decodeAbiParameters([{ type: 'bytes' }, { type: 'bytes[]' }], encoded.inputs[0])
    expect(actions).toBe('0x0b060e')
    expect(decodeAbiParameters([{ type: 'address' }, { type: 'uint256' }, { type: 'bool' }], params[0])).toEqual([detf, 100n, true])
  })
  it('pre-settles wrapped ETH from the router when buying DTF-DETF', () => {
    const encoded = encodeUniversalSwap({ route: route(weth, detf), amountOutMinimum: 190n, nativeIn: true, wrappedNative: weth, prepayInput: true })
    expect(encoded.commands).toBe('0x0b10')
    const [actions, params] = decodeAbiParameters([{ type: 'bytes' }, { type: 'bytes[]' }], encoded.inputs[1])
    expect(actions).toBe('0x0b060f')
    expect(decodeAbiParameters([{ type: 'address' }, { type: 'uint256' }, { type: 'bool' }], params[0])).toEqual([weth, 100n, false])
  })
})
