import type { Address } from './v4Types'
import { ZERO_ADDRESS } from './v4Types'

export type SearchToken = {
  value: Address | 'ETH'
  label: string
  symbol: string
  name: string
  address: Address
  decimals: number
}

const ETH_TOKEN: SearchToken = {
  value: 'ETH',
  label: 'ETH',
  symbol: 'ETH',
  name: 'Ether',
  address: ZERO_ADDRESS,
  decimals: 18,
}

export function ethSearchToken(): SearchToken {
  return ETH_TOKEN
}

function norm(s: string): string {
  return s.trim().toLowerCase()
}

/**
 * Uniswap TokenSelector filter: query matches symbol, name, or address.
 * Exact address match is first. Harvested from Uniswap interface TokenSelector behavior.
 */
export function filterTokens(tokens: SearchToken[], query: string): SearchToken[] {
  const q = norm(query)
  if (!q) return tokens
  const exact: SearchToken[] = []
  const rest: SearchToken[] = []
  for (let i = 0; i < tokens.length; i++) {
    const t = tokens[i]!
    const addr = t.address.toLowerCase()
    if (addr === q || (q.startsWith('0x') && addr === q)) {
      exact.push(t)
      continue
    }
    if (
      norm(t.symbol).includes(q) ||
      norm(t.name).includes(q) ||
      norm(t.label).includes(q) ||
      addr.includes(q.replace(/^0x/, ''))
    ) {
      rest.push(t)
    }
  }
  return exact.concat(rest)
}

export function isImportableAddress(query: string): query is Address {
  return /^0x[0-9a-fA-F]{40}$/.test(query.trim())
}

export const ERC20_IMPORT_ABI = [
  { type: 'function', name: 'symbol', stateMutability: 'view', inputs: [], outputs: [{ type: 'string' }] },
  { type: 'function', name: 'name', stateMutability: 'view', inputs: [], outputs: [{ type: 'string' }] },
  { type: 'function', name: 'decimals', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint8' }] },
] as const
