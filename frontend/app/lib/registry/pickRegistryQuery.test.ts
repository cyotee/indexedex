import { describe, expect, it } from 'vitest'
import {
  filtersFromParsedEntry,
  parseUserSearchEntry,
  pickRegistryQuery,
} from './pickRegistryQuery'

const TOKEN = '0x1111111111111111111111111111111111111111' as const
const PKG = '0x2222222222222222222222222222222222222222' as const
const TYPE = '0x12345678' as const

describe('pickRegistryQuery', () => {
  it('returns none when no filters (UI should show preferred tokenlist)', () => {
    expect(pickRegistryQuery({})).toEqual({ kind: 'none' })
  })

  it('prefers package+token over token-only', () => {
    expect(pickRegistryQuery({ token: TOKEN, pkg: PKG })).toEqual({
      kind: 'vaultsOfPkgOfToken',
      pkg: PKG,
      token: TOKEN,
    })
  })

  it('picks vaultsOfTypeOfToken when type and token set', () => {
    expect(pickRegistryQuery({ token: TOKEN, typeId: TYPE })).toEqual({
      kind: 'vaultsOfTypeOfToken',
      typeId: TYPE,
      token: TOKEN,
    })
  })

  it('picks vaultsOfToken for token-only search', () => {
    expect(pickRegistryQuery({ token: TOKEN })).toEqual({
      kind: 'vaultsOfToken',
      token: TOKEN,
    })
  })

  it('falls back to isVault when only maybeVault is set', () => {
    expect(pickRegistryQuery({ maybeVault: TOKEN })).toEqual({
      kind: 'isVault',
      vault: TOKEN,
    })
  })
})

describe('parseUserSearchEntry', () => {
  const known = [
    { address: TOKEN, symbol: 'WETH', name: 'Wrapped Ether' },
    { address: PKG, symbol: 'USDC', name: 'USD Coin' },
  ]

  it('empty → preferred list mode', () => {
    expect(parseUserSearchEntry('  ')).toEqual({ mode: 'empty' })
  })

  it('hex address → registry address mode', () => {
    const p = parseUserSearchEntry(TOKEN)
    expect(p).toEqual({ mode: 'address', address: TOKEN })
    expect(filtersFromParsedEntry(p)).toEqual({ token: TOKEN, maybeVault: TOKEN })
  })

  it('known symbol → registry token mode', () => {
    const p = parseUserSearchEntry('weth', known)
    expect(p.mode).toBe('known-token')
    if (p.mode === 'known-token') {
      expect(p.token.toLowerCase()).toBe(TOKEN.toLowerCase())
    }
  })

  it('unknown text → client tokenlist filter mode', () => {
    expect(parseUserSearchEntry('alpha vault')).toEqual({ mode: 'text', text: 'alpha vault' })
    expect(filtersFromParsedEntry({ mode: 'text', text: 'x' })).toEqual({})
  })
})
