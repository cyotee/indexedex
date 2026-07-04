export type Address = `0x${string}`
export type Bytes4 = `0x${string}`

export type RegistryQuerySpec =
  | { kind: 'none' }
  | { kind: 'isVault'; vault: Address }
  | { kind: 'vaultsOfToken'; token: Address }
  | { kind: 'vaultsOfType'; typeId: Bytes4 }
  | { kind: 'vaultsOfTypeOfToken'; typeId: Bytes4; token: Address }
  | { kind: 'vaultsOfPackage'; pkg: Address }
  | { kind: 'vaultsOfPkgOfToken'; pkg: Address; token: Address }

export type RegistrySearchFilters = {
  /** Underlying token to search vaults for. */
  token?: Address | null
  /** Vault type id (bytes4). */
  typeId?: Bytes4 | null
  /** DFPkg address. */
  pkg?: Address | null
  /**
   * When the user pasted an address that might be a vault (not only a token).
   * Caller should also run vaultsOfToken when appropriate.
   */
  maybeVault?: Address | null
}

function isAddress(value: string | null | undefined): value is Address {
  return typeof value === 'string' && /^0x[0-9a-fA-F]{40}$/.test(value)
}

function isBytes4(value: string | null | undefined): value is Bytes4 {
  return typeof value === 'string' && /^0x[0-9a-fA-F]{8}$/.test(value)
}

/**
 * Choose the most specific registry view for the active filters.
 * Does not call `vaults()` — empty filters → `none` (UI should show preferred tokenlist).
 */
export function pickRegistryQuery(filters: RegistrySearchFilters): RegistryQuerySpec {
  const token = filters.token && isAddress(filters.token) ? filters.token : null
  const typeId = filters.typeId && isBytes4(filters.typeId) ? filters.typeId : null
  const pkg = filters.pkg && isAddress(filters.pkg) ? filters.pkg : null

  if (pkg && token) return { kind: 'vaultsOfPkgOfToken', pkg, token }
  if (pkg) return { kind: 'vaultsOfPackage', pkg }
  if (typeId && token) return { kind: 'vaultsOfTypeOfToken', typeId, token }
  if (typeId) return { kind: 'vaultsOfType', typeId }
  if (token) return { kind: 'vaultsOfToken', token }

  if (filters.maybeVault && isAddress(filters.maybeVault)) {
    return { kind: 'isVault', vault: filters.maybeVault }
  }

  return { kind: 'none' }
}

export type ParsedUserEntry =
  | { mode: 'empty' }
  /** Free text — filter preferred tokenlist client-side only. */
  | { mode: 'text'; text: string }
  /** Hex address — registry query by token (+ optional isVault). */
  | { mode: 'address'; address: Address }
  /** Matched a known token symbol/name from preferred lists. */
  | { mode: 'known-token'; token: Address; label: string }

export type KnownTokenHint = {
  address: string
  symbol: string
  name?: string
  display?: string
}

/**
 * Parse the search box. Empty → preferred tokenlist.
 * Address → registry views. Otherwise match known tokens, else text filter.
 */
export function parseUserSearchEntry(
  raw: string,
  knownTokens: readonly KnownTokenHint[] = [],
): ParsedUserEntry {
  const text = raw.trim()
  if (!text) return { mode: 'empty' }

  if (/^0x[0-9a-fA-F]{40}$/.test(text)) {
    return { mode: 'address', address: text as Address }
  }

  const q = text.toLowerCase()
  const hit = knownTokens.find((t) => {
    const symbol = (t.symbol ?? '').toLowerCase()
    const name = (t.name ?? '').toLowerCase()
    const display = (t.display ?? '').toLowerCase()
    return symbol === q || name === q || display === q || symbol.includes(q) || name.includes(q)
  })
  if (hit && isAddress(hit.address)) {
    return {
      mode: 'known-token',
      token: hit.address as Address,
      label: hit.display || hit.symbol || hit.address,
    }
  }

  return { mode: 'text', text }
}

/** Build filters for pickRegistryQuery from a parsed entry. */
export function filtersFromParsedEntry(parsed: ParsedUserEntry): RegistrySearchFilters {
  if (parsed.mode === 'address') {
    return { token: parsed.address, maybeVault: parsed.address }
  }
  if (parsed.mode === 'known-token') {
    return { token: parsed.token }
  }
  return {}
}
