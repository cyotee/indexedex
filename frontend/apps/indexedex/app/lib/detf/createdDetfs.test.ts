import { beforeEach, describe, expect, it } from 'vitest'

import {
  CREATED_DETFS_STORAGE_KEY,
  entryFromAddress,
  loadCreatedDetfs,
  mergeDetfEntries,
  parseDetfQueryAddress,
  rememberCreatedDetf,
} from './createdDetfs'

const A = '0x1111111111111111111111111111111111111111' as const
const B = '0x2222222222222222222222222222222222222222' as const

const memory = new Map<string, string>()
const localStorage = {
  getItem: (key: string) => memory.get(key) ?? null,
  setItem: (key: string, value: string) => {
    memory.set(key, value)
  },
  clear: () => memory.clear(),
}
Object.assign(globalThis, { window: { localStorage } })

describe('createdDetfs', () => {
  beforeEach(() => {
    memory.clear()
  })

  it('stores and loads per chain', () => {
    rememberCreatedDetf({ chainId: 46630, address: A, name: 'Alpha', symbol: 'ALP', decimals: 18 })
    rememberCreatedDetf({ chainId: 1, address: B, name: 'Beta', symbol: 'BET', decimals: 18 })
    expect(loadCreatedDetfs(46630).map((row) => row.symbol)).toEqual(['ALP'])
    expect(window.localStorage.getItem(CREATED_DETFS_STORAGE_KEY)).toContain(A)
  })

  it('moves a repeated address to the front', () => {
    rememberCreatedDetf({ chainId: 46630, address: A, name: 'A1', symbol: 'A1', decimals: 18 })
    rememberCreatedDetf({ chainId: 46630, address: B, name: 'B1', symbol: 'B1', decimals: 18 })
    rememberCreatedDetf({ chainId: 46630, address: A, name: 'A2', symbol: 'A2', decimals: 18 })
    expect(loadCreatedDetfs(46630).map((row) => row.symbol)).toEqual(['A2', 'B1'])
  })

  it('parses query addresses', () => {
    expect(parseDetfQueryAddress(A)).toBe(A)
    expect(parseDetfQueryAddress('nope')).toBeNull()
  })

  it('merges lists without duplicate addresses', () => {
    const first = [entryFromAddress(46630, A, 'ONE')]
    const second = [entryFromAddress(46630, A, 'TWO'), entryFromAddress(46630, B, 'TWO')]
    expect(mergeDetfEntries(first, second).map((row) => row.symbol)).toEqual(['ONE', 'TWO'])
  })
})
