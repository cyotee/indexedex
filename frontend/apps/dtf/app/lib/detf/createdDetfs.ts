import type { Address } from 'viem'

import type { TokenListEntry } from '@indexedex/protocol/tokenlists'

export const CREATED_DETFS_STORAGE_KEY = 'indexedex.createdDetfs.v1'

export type CreatedDetf = {
  chainId: number
  address: Address
  name: string
  symbol: string
  decimals: number
}

function isAddress(value: unknown): value is Address {
  return typeof value === 'string' && /^0x[0-9a-fA-F]{40}$/.test(value)
}

function asCreated(raw: unknown): CreatedDetf | null {
  if (!raw || typeof raw !== 'object') return null
  const row = raw as Partial<CreatedDetf>
  if (typeof row.chainId !== 'number' || !isAddress(row.address)) return null
  const name = typeof row.name === 'string' && row.name.trim() ? row.name.trim() : 'DETF'
  const symbol = typeof row.symbol === 'string' && row.symbol.trim() ? row.symbol.trim() : 'DETF'
  const decimals = typeof row.decimals === 'number' && Number.isFinite(row.decimals) ? row.decimals : 18
  return { chainId: row.chainId, address: row.address, name, symbol, decimals }
}

function readAll(): CreatedDetf[] {
  if (typeof window === 'undefined') return []
  try {
    const raw = window.localStorage.getItem(CREATED_DETFS_STORAGE_KEY)
    if (!raw) return []
    const parsed = JSON.parse(raw) as unknown
    if (!Array.isArray(parsed)) return []
    return parsed.map(asCreated).filter((row): row is CreatedDetf => row !== null)
  } catch {
    return []
  }
}

export function rememberCreatedDetf(entry: CreatedDetf): void {
  if (typeof window === 'undefined') return
  const next = asCreated(entry)
  if (!next) return
  const rest = readAll().filter(
    (row) => !(row.chainId === next.chainId && row.address.toLowerCase() === next.address.toLowerCase()),
  )
  try {
    window.localStorage.setItem(CREATED_DETFS_STORAGE_KEY, JSON.stringify([next, ...rest].slice(0, 64)))
  } catch {
    /* quota / private mode */
  }
}

export function toDetfEntry(entry: CreatedDetf): TokenListEntry {
  return {
    chainId: entry.chainId,
    address: entry.address,
    name: entry.name,
    symbol: entry.symbol,
    decimals: entry.decimals,
    tags: ['vault', 'detf', 'created'],
  }
}

export function loadCreatedDetfs(chainId: number): TokenListEntry[] {
  return readAll().filter((row) => row.chainId === chainId).map(toDetfEntry)
}

export function parseDetfQueryAddress(raw: string | null | undefined): Address | null {
  if (!raw) return null
  const value = raw.trim()
  if (!/^0x[0-9a-fA-F]{40}$/.test(value)) return null
  return value as Address
}

export function entryFromAddress(chainId: number, address: Address, symbol = 'DETF'): TokenListEntry {
  return {
    chainId,
    address,
    name: symbol,
    symbol,
    decimals: 18,
    tags: ['vault', 'detf'],
  }
}

export function mergeDetfEntries(...lists: TokenListEntry[][]): TokenListEntry[] {
  const seen = new Set<string>()
  const out: TokenListEntry[] = []
  for (const list of lists) {
    for (const entry of list) {
      const key = entry.address.toLowerCase()
      if (seen.has(key)) continue
      seen.add(key)
      out.push(entry)
    }
  }
  return out
}
