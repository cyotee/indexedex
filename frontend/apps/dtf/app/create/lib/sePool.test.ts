import { getAddress } from 'viem'
import { describe, expect, it } from 'vitest'

import {
  SQRT_PRICE_1_1,
  isPoolAlreadyExistsError,
  isPoolInitWalletRevert,
  parseV3PoolAddressInput,
  parseV4PoolKeyInput,
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
    expect(isPoolAlreadyExistsError({ data: '0x7983c051' })).toBe(true)
    expect(isPoolAlreadyExistsError({ cause: { data: { errorName: 'PoolAlreadyInitialized' } } })).toBe(true)
    expect(isPoolAlreadyExistsError(new Error('insufficient funds'))).toBe(false)
  })

  it('parses a JSON Uniswap V4 pool key and sorts currencies', () => {
    const dtf = '0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01'
    const hooks = '0xe5E702641EA86f4ae6cC3cdaED2B886F976Be044'
    const got = parseV4PoolKeyInput(
      JSON.stringify({
        currency0: dtf,
        currency1: '0x0000000000000000000000000000000000000000',
        fee: 0,
        tickSpacing: 200,
        hooks,
      }),
    )
    expect('error' in got).toBe(false)
    if ('error' in got) return
    expect(got.currency0).toBe('0x0000000000000000000000000000000000000000')
    expect(got.currency1.toLowerCase()).toBe(dtf.toLowerCase())
    expect(got.fee).toBe(0)
    expect(got.tickSpacing).toBe(200)
    expect(got.hooks.toLowerCase()).toBe(hooks.toLowerCase())
  })

  it('checksums lowercase pool key addresses', () => {
    const token = '0xee5576fa1bcaa380e591d01245f406f3f384eb01'
    const hooks = '0xe5e702641ea86f4ae6cc3cdaed2b886f976be044'
    const got = parseV4PoolKeyInput(
      JSON.stringify({
        currency0: '0x0000000000000000000000000000000000000000',
        currency1: token,
        fee: 0,
        tickSpacing: 200,
        hooks,
      }),
    )
    expect('error' in got).toBe(false)
    if ('error' in got) return
    expect(got.currency1).toBe(getAddress(token))
    expect(got.hooks).toBe(getAddress(hooks))
  })

  it('parses a JSON array pool key', () => {
    const got = parseV4PoolKeyInput(
      JSON.stringify([
        '0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01',
        '0x0000000000000000000000000000000000000000',
        0,
        200,
        '0xe5E702641EA86f4ae6cC3cdaED2B886F976Be044',
      ]),
    )
    expect('error' in got).toBe(false)
    if ('error' in got) return
    expect(got.currency0).toBe('0x0000000000000000000000000000000000000000')
    expect(got.fee).toBe(0)
    expect(got.tickSpacing).toBe(200)
  })

  it('parses five comma-separated pool key fields', () => {
    const got = parseV4PoolKeyInput(
      '0x0000000000000000000000000000000000000000, 0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01, 0, 200, 0xe5E702641EA86f4ae6cC3cdaED2B886F976Be044',
    )
    expect('error' in got).toBe(false)
    if ('error' in got) return
    expect(got.fee).toBe(0)
    expect(got.tickSpacing).toBe(200)
  })

  it('parses a Uniswap V3 pool address and rejects blanks or zero', () => {
    const pool = '0x926bb22101269ece5a3c49a47b7cdbc0dcff05f2'
    const got = parseV3PoolAddressInput(pool)
    expect(typeof got).toBe('string')
    if (typeof got !== 'string') return
    expect(got).toBe(getAddress(pool))
    expect(parseV3PoolAddressInput('  ')).toEqual({ error: 'Paste a pool address first.' })
    expect(parseV3PoolAddressInput('0x1234')).toEqual({ error: 'Need a 20-byte pool address.' })
    expect(parseV3PoolAddressInput('0x0000000000000000000000000000000000000000')).toEqual({
      error: 'Pool address cannot be the zero address.',
    })
  })

  it('rejects a blank paste and a same-token pair', () => {
    expect(parseV4PoolKeyInput('  ')).toEqual({ error: 'Paste a pool key first.' })
    const same = parseV4PoolKeyInput(
      '0x0000000000000000000000000000000000000001, 0x0000000000000000000000000000000000000001, 3000, 60, 0x0000000000000000000000000000000000000000',
    )
    expect(same).toEqual({ error: 'The two pool tokens must be different.' })
  })

  it('treats wallet insufficient-gas initialize as the pool already existing', () => {
    expect(isPoolInitWalletRevert(new Error('insufficient gas'))).toBe(true)
    expect(isPoolInitWalletRevert(new Error('intrinsic gas too low'))).toBe(true)
    expect(isPoolInitWalletRevert(new Error('insufficient funds for gas'))).toBe(false)
    expect(isPoolInitWalletRevert(new Error('Internal JSON-RPC error.'))).toBe(true)
  })
})
