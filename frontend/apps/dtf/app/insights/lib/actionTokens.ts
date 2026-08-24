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

/** Addresses a user can mint or bond with: pair legs, SE shares, and SE vault tokens. */
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
}): `0x${string}`[] {
  const seen = new Set<string>()
  const out: `0x${string}`[] = []
  pushAll(out, seen, input.pairTokens)
  pushAll(out, seen, input.acceptedBondTokens)
  pushUnique(out, seen, input.pairToken)
  pushUnique(out, seen, input.pair0)
  pushUnique(out, seen, input.pair1)
  pushUnique(out, seen, input.pair2)
  pushAll(out, seen, input.vaultShares)
  pushAll(out, seen, input.standardExchanges)
  if (input.seVaultTokens) {
    for (const row of input.seVaultTokens) pushAll(out, seen, row)
  }
  return out
}
