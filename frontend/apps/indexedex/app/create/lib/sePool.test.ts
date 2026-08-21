import { describe, expect, it } from 'vitest'

import {
  SQRT_PRICE_1_1,
  isPoolAlreadyExistsError,
  poolActionLabel,
  poolReadyState,
  poolStatusCopy,
  sortPoolTokens,
  sqrtPriceX96FromHuman,
  tickSpacingForV3Fee,
} from './sePool'

describe('sePool', () => {
  it('sorts tokens by address', () => {
    const a = '0x0000000000000000000000000000000000000002' as const
    const b = '0x0000000000000000000000000000000000000001' as const
    expect(sortPoolTokens(a, b)).toEqual([b, a])
  })

  it('maps 1.0 to the 1:1 sqrt price', () => {
    expect(sqrtPriceX96FromHuman('1')).toBe(SQRT_PRICE_1_1)
  })

  it('maps V3 0.3% fee to tick spacing 60', () => {
    expect(tickSpacingForV3Fee(3000)).toBe(60)
  })

  it('labels V3 uninitialized vs missing vs ready', () => {
    expect(
      poolReadyState({ version: 'v3', v3PoolExists: false, v3Initialized: false, v4Exists: false }),
    ).toBe('missing')
    expect(
      poolReadyState({ version: 'v3', v3PoolExists: true, v3Initialized: false, v4Exists: false }),
    ).toBe('uninitialized')
    expect(
      poolReadyState({ version: 'v3', v3PoolExists: true, v3Initialized: true, v4Exists: false }),
    ).toBe('ready')
    expect(poolStatusCopy('uninitialized')).toMatch(/not initialized/)
    expect(poolActionLabel('uninitialized')).toBe('Initialize pool')
    expect(poolActionLabel('missing')).toBe('Create pool')
  })

  it('treats V4 with a slot0 price as ready', () => {
    expect(
      poolReadyState({ version: 'v4', v3PoolExists: false, v3Initialized: false, v4Exists: true }),
    ).toBe('ready')
    expect(
      poolReadyState({ version: 'v4', v3PoolExists: false, v3Initialized: false, v4Exists: false }),
    ).toBe('missing')
  })

  it('detects an already-initialized pool error', () => {
    expect(isPoolAlreadyExistsError(new Error('PoolAlreadyInitialized()'))).toBe(true)
    expect(isPoolAlreadyExistsError({ shortMessage: 'Pool already initialized' })).toBe(true)
    expect(isPoolAlreadyExistsError(new Error('insufficient funds'))).toBe(false)
  })
})
