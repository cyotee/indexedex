import type { TokenListEntry } from '@indexedex/protocol/tokenlists'

import { isRetiredRichEntry, relabelChirEntry } from '../../lib/customerSymbols'

export type InsightDetf = TokenListEntry & { protocolFee: boolean }

export function mergeDetfs(
  featured: TokenListEntry[],
  protocol: TokenListEntry[],
  registry: TokenListEntry[],
  created: TokenListEntry[],
  featuredSet: (addr: string) => boolean,
): InsightDetf[] {
  const out: InsightDetf[] = []
  const seen = new Set<string>()
  const add = (t: TokenListEntry, protocolFee: boolean) => {
    if (isRetiredRichEntry(t)) return
    const k = t.address.toLowerCase()
    if (seen.has(k)) return
    seen.add(k)
    out.push({ ...relabelChirEntry(t), protocolFee })
  }
  for (let i = 0; i < featured.length; i++) add(featured[i]!, true)
  for (let i = 0; i < protocol.length; i++) {
    const t = protocol[i]!
    add(t, featuredSet(t.address))
  }
  for (let i = 0; i < created.length; i++) {
    const t = created[i]!
    add(t, featuredSet(t.address))
  }
  for (let i = 0; i < registry.length; i++) {
    const t = registry[i]!
    add(t, featuredSet(t.address))
  }
  return out
}
