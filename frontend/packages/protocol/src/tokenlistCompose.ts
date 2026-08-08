export interface TokenInfo {
  chainId: number
  address: string
  name: string
  symbol: string
  decimals: number
  logoURI?: string
  tags?: string[]
  extensions?: { [key: string]: unknown }
}

export interface TokenListTags {
  [tagId: string]: { name: string; description: string }
}

export interface TokenList {
  name: string
  timestamp: string
  version: { major: number; minor: number; patch: number }
  keywords?: string[]
  tags?: TokenListTags
  tokens: TokenInfo[]
}

export type Address = `0x${string}`

export interface TokenListRef {
  id: string
  priority: number
  list: TokenList
}

export interface ComposedStore {
  // key: `${chainId}-${addressLower}`
  entries: Map<string, TokenInfo>
}

export function composeLists(refs: TokenListRef[]): ComposedStore {
  const sorted = refs.slice().sort((a, b) => a.priority - b.priority)
  const entries = new Map<string, TokenInfo>()
  sorted.forEach((ref) => {
    ref.list.tokens.forEach((t) => {
      entries.set(key(t.chainId, t.address), t)
    })
  })
  return { entries }
}

export function byTag(store: ComposedStore, tags: string[], chainId: number): TokenInfo[] {
  const want: Record<string, true> = {}
  for (const tag of tags) want[tag] = true
  const out: TokenInfo[] = []
  store.entries.forEach((t) => {
    if (t.chainId !== chainId) return
    if (!t.tags) return
    if (t.tags.some((tag: string) => want[tag] === true)) out.push(t)
  })
  return out
}

export function byAddress(store: ComposedStore, address: string, chainId: number): TokenInfo | undefined {
  return store.entries.get(key(chainId, address))
}

export function resolveLabel(t: TokenInfo): string {
  const display = (t.extensions as { display?: unknown } | undefined)?.display
  if (typeof display === 'string' && display.length > 0) return display
  if (t.name && t.name.length > 0) return t.name
  return t.symbol
}

function key(chainId: number, address: string): string {
  return `${chainId}-${address.toLowerCase()}`
}
