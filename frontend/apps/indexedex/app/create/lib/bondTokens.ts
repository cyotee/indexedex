export const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000' as const

export function sameAddress(a: string, b: string): boolean {
  return a.toLowerCase() === b.toLowerCase()
}

export function isNonZeroAddress(value: unknown): value is `0x${string}` {
  if (typeof value !== 'string') return false
  if (!/^0x[0-9a-fA-F]{40}$/.test(value)) return false
  return value.toLowerCase() !== ZERO_ADDRESS
}

/** PkgArgs may pass share as address(0); the live DETF then uses the SE diamond as the share. */
export function resolveVaultShare(seVault: unknown, vaultShare: unknown): `0x${string}` | null {
  if (isNonZeroAddress(vaultShare)) return vaultShare
  if (isNonZeroAddress(seVault)) return seVault
  return null
}

/**
 * Tokens `bond()` accepts on a one-strategy SE DETF: the vault token (share)
 * plus every token the underlying SE lists on `vaultTokens()`. DETF itself is excluded.
 */
export function firstBondTokenAddresses(args: {
  seVault: unknown
  vaultShare: unknown
  seVaultTokens: unknown
  detf: unknown
}): `0x${string}`[] {
  const share = resolveVaultShare(args.seVault, args.vaultShare)
  const detf = isNonZeroAddress(args.detf) ? args.detf : null
  const seen = new Set<string>()
  const out: `0x${string}`[] = []

  const push = (addr: `0x${string}` | null) => {
    if (!addr) return
    const key = addr.toLowerCase()
    if (seen.has(key)) return
    if (detf && sameAddress(addr, detf)) return
    seen.add(key)
    out.push(addr)
  }

  push(share)
  const raw = Array.isArray(args.seVaultTokens) ? args.seVaultTokens : []
  for (const token of raw) {
    if (isNonZeroAddress(token)) push(token)
  }
  return out
}

export function defaultFirstBondToken(
  tokens: readonly `0x${string}`[],
  pairToken: unknown,
): `0x${string}` | '' {
  if (isNonZeroAddress(pairToken)) {
    const found = tokens.find((t) => sameAddress(t, pairToken))
    if (found) return found
  }
  return tokens[0] ?? ''
}

export function firstBondTokenOptionLabel(args: {
  address: string
  symbol?: string
  vaultShare: string | null
}): string {
  const symbol =
    args.symbol?.trim() || `${args.address.slice(0, 6)}…${args.address.slice(-4)}`
  if (args.vaultShare && sameAddress(args.address, args.vaultShare)) {
    return `${symbol} (vault token)`
  }
  return symbol
}
