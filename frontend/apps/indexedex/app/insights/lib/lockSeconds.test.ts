import { describe, expect, it } from 'vitest'

import { lockSecondsFromDays } from './lockSeconds'

describe('lockSecondsFromDays', () => {
  it('accepts 1 day', () => {
    expect(lockSecondsFromDays('1')).toBe(BigInt(86400))
  })

  it('rejects 0 and 181', () => {
    expect(lockSecondsFromDays('0')).toBeNull()
    expect(lockSecondsFromDays('181')).toBeNull()
  })
})
