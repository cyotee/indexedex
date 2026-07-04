import { describe, expect, it } from 'vitest'
import type { EarnProduct } from '../earn/types'
import { mapRegistryAddressesToRows, preferredToRows } from './mapRegistryToRows'

const preferred: EarnProduct[] = [
  {
    address: '0x1111111111111111111111111111111111111111',
    chainId: 11155111,
    name: 'Alpha Vault',
    symbol: 'ALP',
    decimals: 18,
    productType: 'strategy',
  },
]

describe('mapRegistryAddressesToRows', () => {
  it('merges preferred metadata for known addresses', () => {
    const rows = mapRegistryAddressesToRows(
      ['0x1111111111111111111111111111111111111111', '0x2222222222222222222222222222222222222222'],
      11155111,
      preferred,
    )
    expect(rows).toHaveLength(2)
    expect(rows[0].symbol).toBe('ALP')
    expect(rows[0].source).toBe('registry')
    expect(rows[0].productType).toBe('strategy')
    expect(rows[1].productType).toBe('registry')
    expect(rows[1].source).toBe('registry')
  })
})

describe('preferredToRows', () => {
  it('marks source preferred', () => {
    const rows = preferredToRows(preferred)
    expect(rows[0].source).toBe('preferred')
    expect(rows[0].address).toBe(preferred[0].address)
  })
})
