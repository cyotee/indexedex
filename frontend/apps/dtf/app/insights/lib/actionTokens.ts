import { isZero } from './tokenLabels'

export type ActionToken = { address: `0x${string}`; symbol: string }

export function asAddr(value: unknown): `0x${string}` | null {
  if (typeof value !== 'string') return null
  if (!/^0x[0-9a-fA-F]{40}$/.test(value)) return null
  if (isZero(value)) return null
  return value as `0x${string}`
}

function pushUnique(out: `0x${string}`[], seen: Set<string>, value: unknown) {
  const addr = asAddr(value)
  if (!addr) return
  const key = addr.toLowerCase()
  if (seen.has(key)) return
  seen.add(key)
  out.push(addr)
}

function pushAll(out: `0x${string}`[], seen: Set<string>, values: readonly unknown[] | undefined) {
  if (!values) return
  for (const value of values) pushUnique(out, seen, value)
}

function excludeSet(values: readonly unknown[] | undefined): Set<string> {
  const out = new Set<string>()
  for (const value of values ?? []) {
    const addr = asAddr(value)
    if (addr) out.add(addr.toLowerCase())
  }
  return out
}

/** SE diamonds to read `vaultTokens()` from. One-vault uses `underlyingVault` / `standardExchangeVault`. */
export function collectSeVaultReadAddresses(input: {
  standardExchanges?: readonly unknown[]
  underlyingVault?: unknown
  standardExchangeVault?: unknown
}): `0x${string}`[] {
  const seen = new Set<string>()
  const out: `0x${string}`[] = []
  pushAll(out, seen, input.standardExchanges)
  pushUnique(out, seen, input.underlyingVault)
  pushUnique(out, seen, input.standardExchangeVault)
  return out
}

/**
 * Tokens mint and bond actually settle: pair legs, vault shares, and every token
 * the backing SE lists. `acceptedBondTokens` is a subset on some families.
 */
export function collectActionTokenAddresses(input: {
  pairTokens?: readonly unknown[]
  acceptedBondTokens?: readonly unknown[]
  vaultShares?: readonly unknown[]
  standardExchanges?: readonly unknown[]
  seVaultTokens?: readonly (readonly unknown[] | undefined)[]
  pairToken?: unknown
  pair0?: unknown
  pair1?: unknown
  pair2?: unknown
  rateAsset?: unknown
  underlyingVault?: unknown
  standardExchangeVault?: unknown
  standardExchangeVaultShare?: unknown
  exclude?: readonly unknown[]
}): `0x${string}`[] {
  const skip = excludeSet(input.exclude)
  const seen = new Set<string>()
  const raw: `0x${string}`[] = []
  pushAll(raw, seen, input.pairTokens)
  pushAll(raw, seen, input.acceptedBondTokens)
  pushUnique(raw, seen, input.pairToken)
  pushUnique(raw, seen, input.pair0)
  pushUnique(raw, seen, input.pair1)
  pushUnique(raw, seen, input.pair2)
  pushUnique(raw, seen, input.rateAsset)
  pushAll(raw, seen, input.vaultShares)
  pushUnique(raw, seen, input.standardExchangeVaultShare)
  pushAll(raw, seen, input.standardExchanges)
  pushUnique(raw, seen, input.underlyingVault)
  pushUnique(raw, seen, input.standardExchangeVault)
  if (input.seVaultTokens) {
    for (const row of input.seVaultTokens) pushAll(raw, seen, row)
  }
  if (skip.size === 0) return raw
  return raw.filter((addr) => !skip.has(addr.toLowerCase()))
}

export function actionTokenOptionLabel(token: ActionToken, vaultShare?: string | null): string {
  const symbol = token.symbol.trim() || `${token.address.slice(0, 6)}…${token.address.slice(-4)}`
  if (vaultShare && token.address.toLowerCase() === vaultShare.toLowerCase()) {
    return `${symbol} (vault token)`
  }
  return symbol
}
