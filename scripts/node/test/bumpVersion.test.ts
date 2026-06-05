import { describe, it, expect } from 'vitest'
import { computeBump } from '../src/bumpVersion.js'
import type { TokenInfo } from '../src/types.js'

const T = (address: string, decimals = 18, extras: Partial<TokenInfo> = {}): TokenInfo => ({
  chainId: 1,
  address,
  name: 'X',
  symbol: 'X',
  decimals,
  ...extras,
})

describe('computeBump', () => {
  it('starts at 1.0.0 when there is no previous list', () => {
    const result = computeBump(null, [T('0x1')])
    expect(result.bump).toBe('major')
    expect(result.next).toEqual({ major: 1, minor: 0, patch: 0 })
  })

  it('patches when only metadata changed for the same address set', () => {
    const prev = { major: 2, minor: 3, patch: 4, tokens: [T('0x1', 18, { name: 'old' })] }
    const result = computeBump(prev, [T('0x1', 18, { name: 'new' })])
    expect(result.bump).toBe('patch')
    expect(result.next).toEqual({ major: 2, minor: 3, patch: 5 })
    expect(result.changes.modified).toEqual(['0x1'])
  })

  it('minor bumps when an address is added', () => {
    const prev = { major: 2, minor: 3, patch: 4, tokens: [T('0x1')] }
    const result = computeBump(prev, [T('0x1'), T('0x2')])
    expect(result.bump).toBe('minor')
    expect(result.next).toEqual({ major: 2, minor: 4, patch: 0 })
    expect(result.changes.added).toEqual(['0x2'])
  })

  it('major bumps when an address is removed', () => {
    const prev = { major: 2, minor: 3, patch: 4, tokens: [T('0x1'), T('0x2')] }
    const result = computeBump(prev, [T('0x1')])
    expect(result.bump).toBe('major')
    expect(result.next).toEqual({ major: 3, minor: 0, patch: 0 })
    expect(result.changes.removed).toEqual(['0x2'])
  })

  it('reports none when nothing changed', () => {
    const prev = { major: 1, minor: 0, patch: 0, tokens: [T('0x1')] }
    const result = computeBump(prev, [T('0x1')])
    expect(result.bump).toBe('none')
    expect(result.next).toEqual({ major: 1, minor: 0, patch: 0 })
  })

  it('compares addresses case-insensitively', () => {
    const prev = { major: 1, minor: 0, patch: 0, tokens: [T('0xABCDEF')] }
    const result = computeBump(prev, [T('0xabcdef')])
    expect(result.bump).toBe('none')
  })
})
