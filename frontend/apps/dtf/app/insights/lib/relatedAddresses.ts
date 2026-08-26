import { asAddr } from './actionTokens'

export type DetfRelatedRole =
  | 'DETF token'
  | 'Rate asset'
  | 'Pair token'
  | 'Vault share'
  | 'Underlying vault'
  | 'Vault token'
  | 'Claim token'
  | 'Reserve pool'
  | 'Bond NFT'
  | 'Protocol NFT'

export type DetfRelatedAddress = {
  role: DetfRelatedRole
  address: `0x${string}`
}

function push(
  out: DetfRelatedAddress[],
  seen: Set<string>,
  role: DetfRelatedRole,
  value: unknown,
) {
  const addr = asAddr(value)
  if (!addr) return
  const key = addr.toLowerCase()
  if (seen.has(key)) return
  seen.add(key)
  out.push({ role, address: addr })
}

function pushAll(
  out: DetfRelatedAddress[],
  seen: Set<string>,
  role: DetfRelatedRole,
  values: readonly unknown[] | undefined,
) {
  if (!values) return
  for (const value of values) push(out, seen, role, value)
}

/** Every instance address a DETF page should list. First role wins on duplicates. */
export function collectDetfRelatedAddresses(input: {
  detf?: unknown
  rateAsset?: unknown
  pairTokens?: readonly unknown[]
  pairToken?: unknown
  pair0?: unknown
  pair1?: unknown
  pair2?: unknown
  vaultShares?: readonly unknown[]
  standardExchangeVaultShare?: unknown
  underlyingVault?: unknown
  standardExchangeVault?: unknown
  standardExchanges?: readonly unknown[]
  seVaultTokens?: readonly (readonly unknown[] | undefined)[]
  claimToken?: unknown
  reservePool?: unknown
  bondNftVault?: unknown
  protocolNftVault?: unknown
}): DetfRelatedAddress[] {
  const seen = new Set<string>()
  const out: DetfRelatedAddress[] = []
  push(out, seen, 'DETF token', input.detf)
  push(out, seen, 'Rate asset', input.rateAsset)
  pushAll(out, seen, 'Pair token', input.pairTokens)
  push(out, seen, 'Pair token', input.pairToken)
  push(out, seen, 'Pair token', input.pair0)
  push(out, seen, 'Pair token', input.pair1)
  push(out, seen, 'Pair token', input.pair2)
  pushAll(out, seen, 'Vault share', input.vaultShares)
  push(out, seen, 'Vault share', input.standardExchangeVaultShare)
  push(out, seen, 'Underlying vault', input.underlyingVault)
  push(out, seen, 'Underlying vault', input.standardExchangeVault)
  pushAll(out, seen, 'Underlying vault', input.standardExchanges)
  if (input.seVaultTokens) {
    for (const row of input.seVaultTokens) pushAll(out, seen, 'Vault token', row)
  }
  push(out, seen, 'Claim token', input.claimToken)
  push(out, seen, 'Reserve pool', input.reservePool)
  push(out, seen, 'Bond NFT', input.bondNftVault)
  push(out, seen, 'Protocol NFT', input.protocolNftVault)
  return out
}
