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
})
