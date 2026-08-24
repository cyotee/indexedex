import { describe, expect, it } from 'vitest'

import { toPoolId } from './v4PoolId'
import type { Address } from './v4Types'
import { ZERO_ADDRESS } from './v4Types'

describe('toPoolId', () => {
  it('is stable for the same PoolKey', () => {
    const key = {
      currency0: '0x0000000000000000000000000000000000000001' as Address,
      currency1: '0x0000000000000000000000000000000000000002' as Address,
      fee: 3000,
      tickSpacing: 60,
      hooks: ZERO_ADDRESS,
    }
    const a = toPoolId(key)
    const b = toPoolId({ ...key })
    expect(a).toBe(b)
    expect(a).toMatch(/^0x[0-9a-f]{64}$/)
  })

  it('changes when the hook changes', () => {
    const base = {
      currency0: '0x0000000000000000000000000000000000000001' as Address,
      currency1: '0x0000000000000000000000000000000000000002' as Address,
      fee: 3000,
      tickSpacing: 60,
      hooks: ZERO_ADDRESS,
    }
    const hooked = {
      ...base,
      hooks: '0x0000000000000000000000000000000000000abc' as Address,
    }
    expect(toPoolId(base)).not.toBe(toPoolId(hooked))
  })

  it('matches the TTMETA/TTGOOGL 0.3% vanilla pool id', () => {
    expect(
      toPoolId({
        currency0: '0x8dd9bc588C94B28BBf123588031aD755008c9F10',
        currency1: '0xFD50B27b0Bc6a9D01263d4B56c085D18cA9f67B9',
        fee: 3000,
        tickSpacing: 60,
        hooks: ZERO_ADDRESS,
      }),
    ).toBe('0x82920394ab9b39f723cce69047d83b2e92170c0ad6287e7d049bf86fa26ac901')
  })

  it('matches the TTMSFT/TTAAPL 0.3% vanilla pool id', () => {
    expect(
      toPoolId({
        currency0: '0x4C3b5854a05b6F9bC52c650Df6754dEa80F686d5',
        currency1: '0x4e4f4038f004473dcFCA70C9936C23B2644cd12e',
        fee: 3000,
        tickSpacing: 60,
        hooks: ZERO_ADDRESS,
      }),
    ).toBe('0x7335aabde881aeefbd3ebfd064f33798f2f17b6a31446821977c7eb7098cfb85')
  })
})
