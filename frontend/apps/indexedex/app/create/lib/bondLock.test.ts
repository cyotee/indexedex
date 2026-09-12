import { describe, expect, it } from 'vitest'

import {
  asBondLockTerms,
  clampLockDays,
  daysFromLockSeconds,
  FALLBACK_MAX_LOCK_DAYS,
  FALLBACK_MIN_LOCK_DAYS,
  lockRangeFromBondTerms,
  lockSecondsFromDays,
} from './bondLock'

describe('daysFromLockSeconds', () => {
  it('maps 30 days of seconds to 30', () => {
    expect(daysFromLockSeconds(lockSecondsFromDays(30))).toBe(30)
  })
})

describe('lockRangeFromBondTerms', () => {
  it('uses 30 to 180 when terms are missing', () => {
    expect(lockRangeFromBondTerms(undefined)).toEqual({
      minDays: FALLBACK_MIN_LOCK_DAYS,
      maxDays: FALLBACK_MAX_LOCK_DAYS,
    })
    expect(
      lockRangeFromBondTerms({ minLockDuration: 0n, maxLockDuration: 0n }),
    ).toEqual({
      minDays: FALLBACK_MIN_LOCK_DAYS,
      maxDays: FALLBACK_MAX_LOCK_DAYS,
    })
  })

  it('reads oracle seconds as whole days', () => {
    expect(
      lockRangeFromBondTerms({
        minLockDuration: lockSecondsFromDays(30),
        maxLockDuration: lockSecondsFromDays(180),
      }),
    ).toEqual({ minDays: 30, maxDays: 180 })
  })
})

describe('asBondLockTerms', () => {
  it('reads a tuple or a struct', () => {
    expect(asBondLockTerms([30n * 86400n, 180n * 86400n, 0n, 0n])).toEqual({
      minLockDuration: 30n * 86400n,
      maxLockDuration: 180n * 86400n,
    })
    expect(
      asBondLockTerms({ minLockDuration: 10n, maxLockDuration: 20n }),
    ).toEqual({ minLockDuration: 10n, maxLockDuration: 20n })
  })
})

describe('clampLockDays', () => {
  it('rejects values outside the oracle range', () => {
    expect(clampLockDays('29', 30, 180)).toBeNull()
    expect(clampLockDays('181', 30, 180)).toBeNull()
    expect(clampLockDays('90', 30, 180)).toBe(90)
  })
})
