import { getAddress } from 'viem'
import { describe, expect, it } from 'vitest'

import {
  ARCHIVED_DETF_ADDRESSES,
  isArchivedDetf,
  splitInsightDetfs,
} from './archivedDetfs'
import type { InsightDetf } from './mergeInsightDetfs'

const entry = (
  symbol: string,
  address: `0x${string}`,
  name = symbol,
): InsightDetf => ({
  chainId: 4663,
  address,
  name,
  symbol,
  decimals: 18,
  protocolFee: false,
})

describe('isArchivedDetf', () => {
  it('matches listed addresses case-insensitively', () => {
    expect(isArchivedDetf(ARCHIVED_DETF_ADDRESSES[0])).toBe(true)
    expect(isArchivedDetf(ARCHIVED_DETF_ADDRESSES[0].toLowerCase())).toBe(true)
    expect(isArchivedDetf(getAddress(ARCHIVED_DETF_ADDRESSES[1]))).toBe(true)
    expect(isArchivedDetf('0x1111111111111111111111111111111111111111')).toBe(false)
    expect(isArchivedDetf('not-an-address')).toBe(false)
    expect(isArchivedDetf(null)).toBe(false)
  })
})

describe('splitInsightDetfs', () => {
  it('moves listed addresses out of the live list on Robinhood and keeps list order', () => {
    const liveAddr = '0x1111111111111111111111111111111111111111' as `0x${string}`
    const archivedAddr = ARCHIVED_DETF_ADDRESSES[0]
    const fromRegistry: InsightDetf[] = [
      entry('KEEP', liveAddr, 'Keep DETF'),
      entry('OLD', archivedAddr, 'WETH-DTF-V4-DETF'),
    ]
    const { live, archived } = splitInsightDetfs(fromRegistry, 4663)
    expect(live.map((d) => d.symbol)).toEqual(['KEEP'])
    expect(archived).toHaveLength(ARCHIVED_DETF_ADDRESSES.length)
    expect(archived[0]?.address.toLowerCase()).toBe(archivedAddr.toLowerCase())
    expect(archived[0]?.name).toBe('WETH-DTF-V4-DETF')
    expect(archived.map((d) => d.address.toLowerCase())).toEqual(
      ARCHIVED_DETF_ADDRESSES.map((a) => a.toLowerCase()),
    )
  })

  it('still lists the six archived DETFs when the registry has none of them', () => {
    const { live, archived } = splitInsightDetfs([], 4663)
    expect(live).toEqual([])
    expect(archived).toHaveLength(6)
    expect(archived.every((d) => d.name === 'Archived DETF')).toBe(true)
  })

  it('does not inject Robinhood archives onto other chains', () => {
    const { live, archived } = splitInsightDetfs(
      [entry('FOO', '0x1111111111111111111111111111111111111111', 'Foo')],
      11155111,
    )
    expect(live).toHaveLength(1)
    expect(archived).toEqual([])
  })
})

describe('ARCHIVED_DETF_ADDRESSES', () => {
  it('is six checksummed DETF tokens', () => {
    expect(ARCHIVED_DETF_ADDRESSES).toHaveLength(6)
    for (const address of ARCHIVED_DETF_ADDRESSES) {
      expect(getAddress(address)).toBe(address)
    }
  })
})
