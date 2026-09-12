import type { TokenListEntry } from '@indexedex/protocol/tokenlists'
import { displayTokenSymbol } from '../../lib/customerSymbols'

export function indexTokens(lists: TokenListEntry[][]): Map<string, TokenListEntry> {
  const m = new Map<string, TokenListEntry>()
  for (let i = 0; i < lists.length; i++) {
    const list = lists[i] ?? []
    for (let j = 0; j < list.length; j++) {
      const t = list[j]
      if (!t) continue
      m.set(t.address.toLowerCase(), t)
    }
  }
  return m
}

export function shortAddr(addr: string): string {
  if (addr.length < 10) return addr
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`
}

export function isZero(addr: string | undefined): boolean {
  if (!addr) return true
  return /^0x0+$/i.test(addr)
}

export function labelFor(
  index: Map<string, TokenListEntry>,
  addr: string | undefined,
): { symbol: string; name: string } | null {
  if (!addr || isZero(addr)) return null
  const t = index.get(addr.toLowerCase())
  if (t) return { symbol: displayTokenSymbol(t.symbol) || t.symbol, name: t.name }
  return { symbol: shortAddr(addr), name: 'Not in the local list' }
}
