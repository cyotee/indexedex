import type { BumpResult, TokenInfo, Address } from './types.js'

export interface PreviousList {
  major: number
  minor: number
  patch: number
  tokens: TokenInfo[]
}

export function computeBump(previous: PreviousList | null, current: TokenInfo[]): BumpResult {
  if (previous === null) {
    return {
      bump: 'major',
      previous: null,
      next: { major: 1, minor: 0, patch: 0 },
      changes: {
        added: current.map((t) => t.address as Address),
        removed: [],
        modified: [],
      },
    }
  }

  const prevByAddr = new Map(previous.tokens.map((t) => [t.address.toLowerCase(), t]))
  const currByAddr = new Map(current.map((t) => [t.address.toLowerCase(), t]))

  const added: Address[] = []
  const removed: Address[] = []
  const modified: Address[] = []

  for (const [addr, token] of currByAddr) {
    const prev = prevByAddr.get(addr)
    if (!prev) {
      added.push(token.address as Address)
    } else if (!tokenInfoEquals(prev, token)) {
      modified.push(token.address as Address)
    }
  }

  for (const [addr, token] of prevByAddr) {
    if (!currByAddr.has(addr)) removed.push(token.address as Address)
  }

  const { major, minor, patch } = previous
  let next = { major, minor, patch }
  let bump: BumpResult['bump'] = 'none'

  if (removed.length > 0) {
    next = { major: major + 1, minor: 0, patch: 0 }
    bump = 'major'
  } else if (added.length > 0) {
    next = { major, minor: minor + 1, patch: 0 }
    bump = 'minor'
  } else if (modified.length > 0) {
    next = { major, minor, patch: patch + 1 }
    bump = 'patch'
  }

  return {
    bump,
    previous: { major, minor, patch },
    next,
    changes: { added, removed, modified },
  }
}

function tokenInfoEquals(a: TokenInfo, b: TokenInfo): boolean {
  return JSON.stringify(canonical(a)) === JSON.stringify(canonical(b))
}

function canonical(t: TokenInfo): unknown {
  return {
    chainId: t.chainId,
    address: t.address.toLowerCase(),
    name: t.name,
    symbol: t.symbol,
    decimals: t.decimals,
    logoURI: t.logoURI ?? null,
    tags: [...(t.tags ?? [])].sort(),
    extensions: t.extensions ?? null,
  }
}
