import { describe, expect, it } from 'vitest'

import { resolveTokenStakingAddress } from './resolveAddress'

describe('resolveTokenStakingAddress', () => {
  it('prefers a live env address over platform', () => {
    expect(
      resolveTokenStakingAddress(
        { tokenStaking: '0x1111111111111111111111111111111111111111' },
        '0x2222222222222222222222222222222222222222',
      ),
    ).toBe('0x2222222222222222222222222222222222222222')
  })

  it('uses platform.tokenStaking when env is empty', () => {
    expect(
      resolveTokenStakingAddress({ tokenStaking: '0x1111111111111111111111111111111111111111' }, ''),
    ).toBe('0x1111111111111111111111111111111111111111')
  })

  it('returns undefined for zero or missing addresses', () => {
    expect(resolveTokenStakingAddress({ tokenStaking: '0x0000000000000000000000000000000000000000' })).toBeUndefined()
    expect(resolveTokenStakingAddress({})).toBeUndefined()
    expect(resolveTokenStakingAddress(null, 'not-an-address')).toBeUndefined()
  })
})
