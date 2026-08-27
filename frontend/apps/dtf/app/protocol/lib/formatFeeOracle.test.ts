import { describe, expect, it } from 'vitest'

import {
  formatLockDuration,
  formatWadPercent,
  parseDaysToSeconds,
  parsePercentToWad,
  parseTypeId,
  uniqueTypeIds,
} from './formatFeeOracle'

describe('formatWadPercent', () => {
  it('maps WAD percents to human percents', () => {
    expect(formatWadPercent(10n ** 18n)).toBe('100%')
    expect(formatWadPercent(5n * 10n ** 16n)).toBe('5%')
    expect(formatWadPercent(10n ** 15n)).toBe('0.1%')
    expect(formatWadPercent(0n)).toBe('Unset')
    expect(formatWadPercent(0n, { zeroMeansZero: true })).toBe('0%')
    expect(formatWadPercent(undefined)).toBe('—')
  })
})

describe('parsePercentToWad', () => {
  it('parses human percents back to WAD', () => {
    expect(parsePercentToWad('100')).toBe(10n ** 18n)
    expect(parsePercentToWad('5')).toBe(5n * 10n ** 16n)
    expect(parsePercentToWad('0.1')).toBe(10n ** 15n)
    expect(parsePercentToWad('0')).toBe(0n)
    expect(parsePercentToWad('')).toBeNull()
    expect(parsePercentToWad('101')).toBeNull()
  })
})

describe('lock duration', () => {
  it('formats whole days and parses them back', () => {
    expect(formatLockDuration(30n * 86_400n)).toBe('30 days')
    expect(formatLockDuration(86_400n)).toBe('1 day')
    expect(formatLockDuration(0n)).toBe('Unset')
    expect(parseDaysToSeconds('30')).toBe(30n * 86_400n)
    expect(parseDaysToSeconds('-1')).toBeNull()
  })
})

describe('parseTypeId', () => {
  it('accepts 4-byte hex', () => {
    expect(parseTypeId('0x1234abcd')).toBe('0x1234abcd')
    expect(parseTypeId('0x1234')).toBeNull()
  })
})

describe('uniqueTypeIds', () => {
  it('dedupes lists case-insensitively', () => {
    expect(
      uniqueTypeIds([
        ['0x11111111', '0x22222222', '0x00000000'],
        ['0x11111111', '0x33333333'],
      ]),
    ).toEqual(['0x11111111', '0x22222222', '0x33333333'])
  })
})
