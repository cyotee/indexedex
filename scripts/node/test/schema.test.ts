import { describe, it, expect } from 'vitest'
import { validateTokenList } from '../src/schema.js'

describe('validateTokenList', () => {
  it('accepts a minimal valid token list', () => {
    const result = validateTokenList({
      name: 'Indexedex Test',
      timestamp: '2026-06-05T00:00:00.000Z',
      version: { major: 1, minor: 0, patch: 0 },
      tokens: [
        {
          chainId: 11155111,
          address: '0x1111111111111111111111111111111111111111',
          name: 'Test',
          symbol: 'TST',
          decimals: 18,
        },
      ],
    })
    expect(result.valid).toBe(true)
    expect(result.errors).toEqual([])
  })

  it('rejects a list missing version', () => {
    const result = validateTokenList({
      name: 'Indexedex Test',
      timestamp: '2026-06-05T00:00:00.000Z',
      tokens: [],
    } as any)
    expect(result.valid).toBe(false)
    expect(result.errors.length).toBeGreaterThan(0)
  })

  it('rejects a token with a malformed address', () => {
    const result = validateTokenList({
      name: 'Indexedex Test',
      timestamp: '2026-06-05T00:00:00.000Z',
      version: { major: 1, minor: 0, patch: 0 },
      tokens: [
        { chainId: 1, address: 'not-an-address', name: 'T', symbol: 'T', decimals: 18 },
      ],
    })
    expect(result.valid).toBe(false)
  })
})
