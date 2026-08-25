import { describe, expect, it } from 'vitest'

import type { TokenListEntry } from '@indexedex/protocol/tokenlists'

import { mergeDetfs } from './mergeInsightDetfs'

const entry = (symbol: string, address: `0x${string}`, name = symbol): TokenListEntry => ({
  chainId: 4663,
  address,
  name,
  symbol,
  decimals: 18,
})

describe('mergeDetfs', () => {
  it('omits RICH-labeled rows from the Insights DETF picker', () => {
    const featured = [entry('RICH', '0x1111111111111111111111111111111111111111')]
    const protocol = [entry('DTF-DETF', '0x2222222222222222222222222222222222222222', 'Protocol DETF')]
    const created = [entry('RICH', '0x3333333333333333333333333333333333333333', 'Rich Token')]
    const registry = [
      entry('FOO', '0x4444444444444444444444444444444444444444', 'Foo DETF'),
      entry('TTRICH', '0x5555555555555555555555555555555555555555'),
    ]
    const out = mergeDetfs(featured, protocol, registry, created, () => false)
    expect(out.map((row) => row.symbol)).toEqual(['DTF-DETF', 'FOO'])
  })
})
