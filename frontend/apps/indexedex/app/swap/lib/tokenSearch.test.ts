import { describe, expect, it } from 'vitest'

import { filterTokens, isImportableAddress, type SearchToken } from './tokenSearch'
import { ZERO_ADDRESS } from './v4Types'

const tokens: SearchToken[] = [
  {
    value: 'ETH',
    label: 'ETH',
    symbol: 'ETH',
    name: 'Ether',
    address: ZERO_ADDRESS,
    decimals: 18,
  },
  {
    value: '0x00a7413b2d28BAfe10d9182299Ad6d58F90E2665',
    label: 'TTUSDE',
    symbol: 'TTUSDE',
    name: 'Test Token USDE',
    address: '0x00a7413b2d28BAfe10d9182299Ad6d58F90E2665',
    decimals: 18,
  },
  {
    value: '0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E',
    label: 'TSLA',
    symbol: 'TSLA',
    name: 'Faucet TSLA',
    address: '0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E',
    decimals: 18,
  },
]

describe('filterTokens (Uniswap TokenSelector)', () => {
  it('returns all tokens for an empty query', () => {
    expect(filterTokens(tokens, '')).toHaveLength(3)
  })

  it('matches symbol case-insensitively', () => {
    expect(filterTokens(tokens, 'tsla').map((t) => t.symbol)).toEqual(['TSLA'])
  })

  it('matches name', () => {
    expect(filterTokens(tokens, 'usde').map((t) => t.symbol)).toEqual(['TTUSDE'])
  })

  it('ranks an exact address first', () => {
    const q = '0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E'
    expect(filterTokens(tokens, q)[0]?.symbol).toBe('TSLA')
  })
})

describe('isImportableAddress', () => {
  it('accepts a 40-hex address', () => {
    expect(isImportableAddress('0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E')).toBe(true)
  })

  it('rejects short or empty strings', () => {
    expect(isImportableAddress('TSLA')).toBe(false)
    expect(isImportableAddress('0x123')).toBe(false)
  })
})
