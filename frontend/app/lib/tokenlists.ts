import {
  CHAIN_ID_SEPOLIA,
  getAddressArtifacts,
  getDefaultDeploymentEnvironment,
  resolveArtifactsChainId,
  type DeploymentEnvironment,
} from './addressArtifacts'

export type Address = `0x${string}`

export type TokenListEntry = {
  chainId: number
  address: Address
  name: string
  symbol: string
  decimals: number
  // Optional derived metadata for UI dropdowns.
  display?: string
}

function filterChain(list: TokenListEntry[], chainId: number): TokenListEntry[] {
  return list.filter((t) => t.chainId === chainId)
}

type TokenCache = {
  baseTokens: TokenListEntry[]
  erc4626Tokens: TokenListEntry[]
  seigniorageDetfs: TokenListEntry[]
  protocolDetfTokens: TokenListEntry[]
  strategyVaultTokens: TokenListEntry[]
  uniV2PoolTokens: TokenListEntry[]
  aerodromePoolTokens: TokenListEntry[]
  balancerPoolTokens: TokenListEntry[]
}

const EMPTY_CACHE: TokenCache = {
  baseTokens: [],
  erc4626Tokens: [],
  seigniorageDetfs: [],
  protocolDetfTokens: [],
  strategyVaultTokens: [],
  uniV2PoolTokens: [],
  aerodromePoolTokens: [],
  balancerPoolTokens: [],
}

function isHexAddress(value: unknown): value is Address {
  if (typeof value !== 'string') return false
  return /^0x[0-9a-fA-F]{40}$/.test(value)
}

function isZeroAddress(address: Address): boolean {
  return address.toLowerCase() === '0x0000000000000000000000000000000000000000'
}

function shortAddress(address: Address): string {
  const a = address
  if (a.length !== 42) return a
  return `${a.slice(0, 6)}...${a.slice(-4)}`
}

function buildDisplay(entry: TokenListEntry): string {
  const addr = shortAddress(entry.address)
  const name = (entry.name ?? '').trim()
  const symbol = (entry.symbol ?? '').trim()

  // Prefer symbol-first for regular tokens; name-first for pools/vault-like entries.
  const looksLikePoolOrVault = /pool|vault|erc4626|detf/i.test(name) || /pool|vault|erc4626|detf/i.test(symbol)
  const head = looksLikePoolOrVault
    ? [name || symbol, name && symbol && name !== symbol ? symbol : ''].filter(Boolean).join(' - ')
    : [symbol || name, symbol && name && symbol !== name ? name : ''].filter(Boolean).join(' - ')

  return head ? `${head} (${addr})` : `${addr}`
}

function withDisplay(list: TokenListEntry[]): TokenListEntry[] {
  return list.map((t) => ({ ...t, display: t.display || buildDisplay(t) }))
}

function humanizeKey(key: string): string {
  // e.g. uniV2VaultTTATTB -> uni V2 Vault TTA TTB
  return key
    .replace(/([a-z])([A-Z0-9])/g, '$1 $2')
    .replace(/([0-9])([A-Za-z])/g, '$1 $2')
    .replace(/\s+/g, ' ')
    .trim()
}

function mergeUniqueByAddress(a: TokenListEntry[], b: TokenListEntry[]): TokenListEntry[] {
  const out: TokenListEntry[] = [...a]
  const seen = new Set(a.map((t) => t.address.toLowerCase()))
  for (const t of b) {
    const addr = t.address.toLowerCase()
    if (seen.has(addr)) continue
    seen.add(addr)
    out.push(t)
  }
  return out
}

function mergeUniqueBySymbolPreferFirst(a: TokenListEntry[], b: TokenListEntry[]): TokenListEntry[] {
  const out: TokenListEntry[] = [...a]
  const seenSymbols = new Set(a.map((t) => t.symbol.trim().toLowerCase()))
  const seenAddresses = new Set(a.map((t) => t.address.toLowerCase()))

  for (const t of b) {
    const symbol = t.symbol.trim().toLowerCase()
    const address = t.address.toLowerCase()
    if (seenSymbols.has(symbol) || seenAddresses.has(address)) continue
    seenSymbols.add(symbol)
    seenAddresses.add(address)
    out.push(t)
  }

  return out
}

function buildStrategyVaultEntriesFromPlatform(platform: any, chainId: number): TokenListEntry[] {
  if (!platform || typeof platform !== 'object') return []

  const ignoreKeys = new Set([
    // Core infra addresses that contain the substring "vault" but are not strategy vaults
    'balancerV3Vault',
    'vaultRegistry',
    'vaultFeeOracle',
  ])

  const out: TokenListEntry[] = []
  for (const [key, value] of Object.entries(platform as Record<string, unknown>)) {
    if (ignoreKeys.has(key)) continue
    // Only include actual vault instances, not packages/facets/registries/etc.
    if (!/vault/i.test(key)) continue
    if (/pkg|dfpkg|facet|factory|oracle|registry|rateprovider/i.test(key)) continue
    if (!isHexAddress(value)) continue
    if (isZeroAddress(value)) continue

    out.push({
      chainId,
      address: value,
      name: humanizeKey(key),
      symbol: key,
      decimals: 18,
    })
  }
  return withDisplay(out)
}

function buildProtocolDetfEntriesFromPlatform(platform: unknown, chainId: number): TokenListEntry[] {
  if (!platform || typeof platform !== 'object') return []

  const record = platform as Record<string, unknown>
  const entries: TokenListEntry[] = []

  const protocolDetf = record.protocolDetf
  if (isHexAddress(protocolDetf) && !isZeroAddress(protocolDetf)) {
    entries.push({
      chainId,
      address: protocolDetf,
      name: 'Protocol DETF CHIR',
      symbol: 'CHIR',
      decimals: 18,
    })
  }

  const richToken = record.richToken
  if (isHexAddress(richToken) && !isZeroAddress(richToken)) {
    entries.push({
      chainId,
      address: richToken,
      name: 'Rich Token',
      symbol: 'RICH',
      decimals: 18,
    })
  }

  const richirToken = record.richirToken
  if (isHexAddress(richirToken) && !isZeroAddress(richirToken)) {
    entries.push({
      chainId,
      address: richirToken,
      name: 'RICHIR',
      symbol: 'RICHIR',
      decimals: 18,
    })
  }

  return withDisplay(entries)
}

  function resolvePlatformWethAddress(platform: unknown): Address | null {
    if (!platform || typeof platform !== 'object') return null
    const record = platform as Record<string, unknown>
    const candidate = record.weth9 ?? record.weth ?? null
    return isHexAddress(candidate) ? candidate : null
  }

const cacheByChainAndEnvironment: Record<string, TokenCache> = {}

function getCacheKey(chainId: number, environment: DeploymentEnvironment): string {
  return `${environment}:${chainId}`
}

function getArtifactsOrNull(
  chainId: number,
  environment: DeploymentEnvironment
) {
  const resolved = resolveArtifactsChainId(chainId, environment)
  if (resolved === null) return null

  try {
    return getAddressArtifacts(chainId, environment)
  } catch {
    return null
  }
}

function getCached(
  chainId: number = CHAIN_ID_SEPOLIA,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment()
): TokenCache {
  const cacheKey = getCacheKey(chainId, environment)
  const existing = cacheByChainAndEnvironment[cacheKey]
  if (existing) return existing

  const resolvedChainId = resolveArtifactsChainId(chainId, environment)
  const artifacts = getArtifactsOrNull(chainId, environment)
  if (!artifacts || resolvedChainId === null) {
    cacheByChainAndEnvironment[cacheKey] = EMPTY_CACHE
    return EMPTY_CACHE
  }

  const artifactsChainId = resolvedChainId

  const baseTokens = withDisplay(filterChain(artifacts.tokenlists.tokens as TokenListEntry[], artifactsChainId))
  const erc4626Tokens = withDisplay(filterChain(artifacts.tokenlists.erc4626 as TokenListEntry[], artifactsChainId))
  const seigniorageDetfs = withDisplay(
    filterChain(((artifacts.tokenlists as any).seigniorageDetfs ?? []) as TokenListEntry[], artifactsChainId)
  )
  const protocolDetfTokens = withDisplay(
    filterChain(((artifacts.tokenlists as any).protocolDetf ?? []) as TokenListEntry[], artifactsChainId)
  )
  const platformProtocolDetfTokens = buildProtocolDetfEntriesFromPlatform(artifacts.platform, artifactsChainId)
  const mergedProtocolDetfTokens = platformProtocolDetfTokens.length > 0
    ? mergeUniqueBySymbolPreferFirst(
        platformProtocolDetfTokens,
        protocolDetfTokens
      )
    : protocolDetfTokens
  let strategyVaultTokens = withDisplay(filterChain(artifacts.tokenlists.strategyVaults as TokenListEntry[], artifactsChainId))
  const uniV2PoolTokens = withDisplay(filterChain(artifacts.tokenlists.uniV2Pools as TokenListEntry[], artifactsChainId))
  const aerodromePoolTokens = withDisplay(
    filterChain(((artifacts.tokenlists as any).aerodromePools ?? []) as TokenListEntry[], artifactsChainId)
  )
  const balancerPoolTokens = withDisplay(filterChain(artifacts.tokenlists.balancerPools as TokenListEntry[], artifactsChainId))

  const aerodromeStrategyVaultTokens = filterChain(
    ((artifacts.tokenlists as any).aerodromeStrategyVaults ?? []) as TokenListEntry[],
    artifactsChainId
  )
  if (aerodromeStrategyVaultTokens.length > 0) {
    strategyVaultTokens = mergeUniqueByAddress(strategyVaultTokens, withDisplay(aerodromeStrategyVaultTokens))
  }

  // Anvil fork: the generated strategy-vaults tokenlist can be empty.
  // Fall back to any known vault addresses embedded in platform/base_deployments.json.
  // This keeps Swap/Batch-Swap pool dropdowns usable without additional script stages.
  if (strategyVaultTokens.length === 0) {
    const platformDerivedVaults = buildStrategyVaultEntriesFromPlatform(artifacts.platform, artifactsChainId)
    if (platformDerivedVaults.length > 0) {
      strategyVaultTokens = mergeUniqueByAddress(strategyVaultTokens, platformDerivedVaults)
    }
  }

  const cached: TokenCache = {
    baseTokens,
    erc4626Tokens,
    seigniorageDetfs,
    protocolDetfTokens: mergedProtocolDetfTokens,
    strategyVaultTokens,
    uniV2PoolTokens,
    aerodromePoolTokens,
    balancerPoolTokens,
  }

  cacheByChainAndEnvironment[cacheKey] = cached
  return cached
}

// Public getters
export function getBaseTokens(): TokenListEntry[] {
  return getCached().baseTokens
}

export function getErc4626Tokens(): TokenListEntry[] {
  return getCached().erc4626Tokens
}

export function getStrategyVaultTokens(): TokenListEntry[] {
  return getCached().strategyVaultTokens
}

export function getUniV2PoolTokens(): TokenListEntry[] {
  return getCached().uniV2PoolTokens
}

export function getAerodromePoolTokens(): TokenListEntry[] {
  return getCached().aerodromePoolTokens
}

export function getBalancerPoolTokens(): TokenListEntry[] {
  return getCached().balancerPoolTokens
}

export function getBaseTokensForChain(
  chainId: number,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment()
): TokenListEntry[] {
  return getCached(chainId, environment).baseTokens
}

function isTestTokenEntry(t: TokenListEntry): boolean {
  // Keep this intentionally strict: Mint page should only expose dev/test ERC20s.
  // Our canonical test tokens are named "Test Token X" with symbols like TTA/TTB/TTC.
  return /test token/i.test(t.name) || /^TT[A-Z0-9]+$/.test(t.symbol)
}

export function getErc4626TokensForChain(
  chainId: number,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment()
): TokenListEntry[] {
  return getCached(chainId, environment).erc4626Tokens
}

export function getSeigniorageDetfsForChain(
  chainId: number,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment()
): TokenListEntry[] {
  return getCached(chainId, environment).seigniorageDetfs
}

export function getProtocolDetfTokensForChain(
  chainId: number,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment()
): TokenListEntry[] {
  return getCached(chainId, environment).protocolDetfTokens
}

export function getProtocolDetfsForChain(
  chainId: number,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment()
): TokenListEntry[] {
  return getCached(chainId, environment).protocolDetfTokens.filter((t) => t.symbol === 'CHIR')
}

export function getStrategyVaultTokensForChain(
  chainId: number,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment()
): TokenListEntry[] {
  return getCached(chainId, environment).strategyVaultTokens
}

export function getUniV2PoolTokensForChain(
  chainId: number,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment()
): TokenListEntry[] {
  return getCached(chainId, environment).uniV2PoolTokens
}

export function getAerodromePoolTokensForChain(
  chainId: number,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment()
): TokenListEntry[] {
  return getCached(chainId, environment).aerodromePoolTokens
}

export function getBalancerPoolTokensForChain(
  chainId: number,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment()
): TokenListEntry[] {
  return getCached(chainId, environment).balancerPoolTokens
}

// Mint page helpers
export function getMintableTestTokensForChain(chainId: number): TokenListEntry[] {
  return getBaseTokensForChain(chainId).filter(isTestTokenEntry)
}

export function getAllTokens(): TokenListEntry[] {
  const {
    baseTokens,
    erc4626Tokens,
    seigniorageDetfs,
    protocolDetfTokens,
    uniV2PoolTokens,
    aerodromePoolTokens,
    strategyVaultTokens,
  } = getCached()
  return [
    ...baseTokens,
    ...erc4626Tokens,
    ...seigniorageDetfs,
    ...protocolDetfTokens,
    ...uniV2PoolTokens,
    ...aerodromePoolTokens,
    ...strategyVaultTokens,
  ]
}

export function getAllTokensForChain(
  chainId: number,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment()
): TokenListEntry[] {
  const {
    baseTokens,
    erc4626Tokens,
    seigniorageDetfs,
    protocolDetfTokens,
    uniV2PoolTokens,
    aerodromePoolTokens,
    strategyVaultTokens,
  } = getCached(chainId, environment)
  return [
    ...baseTokens,
    ...erc4626Tokens,
    ...seigniorageDetfs,
    ...protocolDetfTokens,
    ...uniV2PoolTokens,
    ...aerodromePoolTokens,
    ...strategyVaultTokens,
  ]
}

// Lookups
export function findTokenBySymbol(symbol: string): TokenListEntry | undefined {
  const s = symbol.trim()
  return getAllTokens().find((t) => t.symbol === s)
}

export function findTokenByAddress(address?: string | null): TokenListEntry | undefined {
  if (!address) return undefined
  const a = address.toLowerCase()
  return getAllTokens().find((t) => t.address.toLowerCase() === a)
}

export function findPoolBySymbol(symbol: string): TokenListEntry | undefined {
  const s = symbol.trim()
  // Balancer pools and vaults (strategy + ERC4626) can both appear as selectable pools depending on context
  const { balancerPoolTokens, strategyVaultTokens, erc4626Tokens, protocolDetfTokens } = getCached()
  return (
    balancerPoolTokens.find((p) => p.symbol === s) ||
    strategyVaultTokens.find((p) => p.symbol === s) ||
    erc4626Tokens.find((p) => p.symbol === s) ||
    protocolDetfTokens.find((p) => p.symbol === s)
  )
}

export function findPoolByAddress(address?: string | null): TokenListEntry | undefined {
  if (!address) return undefined
  const a = address.toLowerCase()
  const { balancerPoolTokens, strategyVaultTokens, erc4626Tokens, protocolDetfTokens } = getCached()
  return (
    balancerPoolTokens.find((p) => p.address.toLowerCase() === a) ||
    strategyVaultTokens.find((p) => p.address.toLowerCase() === a) ||
    erc4626Tokens.find((p) => p.address.toLowerCase() === a) ||
    protocolDetfTokens.find((p) => p.address.toLowerCase() === a)
  )
}

export function isStrategyVaultToken(address?: string | null): boolean {
  if (!address) return false
  const a = address.toLowerCase()
  return getCached().strategyVaultTokens.some((t) => t.address.toLowerCase() === a)
}

export function isStrategyVaultTokenForChain(chainId: number, address?: string | null): boolean {
  if (!address) return false
  const a = address.toLowerCase()
  return getCached(chainId).strategyVaultTokens.some((t) => t.address.toLowerCase() === a)
}

export function getTokenDecimalsByAddress(address?: string | null): number {
  if (!address) return 18
  const platform = getAddressArtifacts(CHAIN_ID_SEPOLIA).platform
  // WETH is always 18 decimals; use platform mapping for the current default chain.
  const weth = resolvePlatformWethAddress(platform)
  if (weth && address.toLowerCase() === weth.toLowerCase()) return 18
  const entry = findTokenByAddress(address)
  return entry?.decimals ?? 18
}

export function getTokenDecimalsByAddressForChain(
  chainId: number,
  address?: string | null,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment()
): number {
  if (!address) return 18
  const platform = getAddressArtifacts(chainId, environment).platform
  const weth = resolvePlatformWethAddress(platform)
  if (weth && address.toLowerCase() === weth.toLowerCase()) return 18
  const entry = getAllTokensForChain(chainId, environment).find((t) => t.address.toLowerCase() === address.toLowerCase())
  return entry?.decimals ?? 18
}

export type PoolOption = {
  value: Address
  label: string
  type: 'balancer' | 'vault'
}

export type TokenOptionType = 'token' | 'lp' | 'vault'

export type TokenOption = {
  value: Address | 'ETH' | 'WETH9'
  label: string
  chainId: number
  type: TokenOptionType
}

// UI option builders
export function buildPoolOptions(): PoolOption[] {
  const { balancerPoolTokens, strategyVaultTokens, erc4626Tokens, protocolDetfTokens } = getCached()
  const balancerOptions: PoolOption[] = balancerPoolTokens.map((p) => ({
    value: p.address,
    label: p.display || p.name || p.symbol,
    type: 'balancer'
  }))
  const vaultOptions: PoolOption[] = strategyVaultTokens.map((p) => ({
    value: p.address,
    label: `${p.display || p.name || p.symbol} (Vault)`,
    type: 'vault'
  }))
  const erc4626VaultOptions: PoolOption[] = erc4626Tokens.map((p) => ({
    value: p.address,
    label: `${p.display || p.name || p.symbol} (ERC4626)`,
    type: 'vault',
  }))
  const protocolDetfOptions: PoolOption[] = protocolDetfTokens.map((t) => ({
    value: t.address,
    label: `${t.display || t.name || t.symbol} (Protocol DETF)`,
    type: 'vault',
  }))
  return [...balancerOptions, ...vaultOptions, ...erc4626VaultOptions, ...protocolDetfOptions]
}

export function buildPoolOptionsForChain(
  chainId: number,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment()
): PoolOption[] {
  const { balancerPoolTokens, strategyVaultTokens, erc4626Tokens, protocolDetfTokens } = getCached(chainId, environment)
  const platform = getArtifactsOrNull(chainId, environment)?.platform
  const weth = resolvePlatformWethAddress(platform)

  const specialOptions: PoolOption[] = []
  // WETH sentinel pool: select this to do pure wrap/unwrap flows.
  if (weth && !isZeroAddress(weth)) {
    specialOptions.push({ value: weth, label: 'WETH (Wrap/Unwrap)', type: 'balancer' })
  }

  const balancerOptions: PoolOption[] = balancerPoolTokens.map((p) => ({
    value: p.address,
    label: p.display || p.name || p.symbol,
    type: 'balancer',
  }))
  const vaultOptions: PoolOption[] = strategyVaultTokens.map((p) => ({
    value: p.address,
    label: `${p.display || p.name || p.symbol} (Vault)`,
    type: 'vault',
  }))
  const erc4626VaultOptions: PoolOption[] = erc4626Tokens.map((p) => ({
    value: p.address,
    label: `${p.display || p.name || p.symbol} (ERC4626)`,
    type: 'vault',
  }))
  const protocolDetfOptions: PoolOption[] = protocolDetfTokens.map((t) => ({
    value: t.address,
    label: `${t.display || t.name || t.symbol} (Protocol DETF)`,
    type: 'vault',
  }))
  return [...specialOptions, ...balancerOptions, ...vaultOptions, ...erc4626VaultOptions, ...protocolDetfOptions]
}

export function buildTokenOptions(includeVaultShares: boolean = true, includeLpTokens: boolean = true): TokenOption[] {
  const opts: TokenOption[] = []
  const {
    baseTokens,
    erc4626Tokens,
    seigniorageDetfs,
    protocolDetfTokens,
    uniV2PoolTokens,
    aerodromePoolTokens,
    strategyVaultTokens,
  } = getCached()
  const platform = getAddressArtifacts(CHAIN_ID_SEPOLIA).platform
  // ETH and WETH
  opts.push({ value: 'ETH', label: 'ETH', chainId: CHAIN_ID_SEPOLIA, type: 'token' })
  if (resolvePlatformWethAddress(platform)) {
    opts.push({ value: 'WETH9', label: 'WETH9', chainId: CHAIN_ID_SEPOLIA, type: 'token' })
  }

  for (const t of baseTokens) opts.push({ value: t.address, label: t.display || t.symbol, chainId: CHAIN_ID_SEPOLIA, type: 'token' })
  for (const t of erc4626Tokens) opts.push({ value: t.address, label: t.display || t.symbol, chainId: CHAIN_ID_SEPOLIA, type: 'vault' })
  for (const t of seigniorageDetfs) opts.push({ value: t.address, label: t.display || t.symbol, chainId: CHAIN_ID_SEPOLIA, type: 'vault' })
  for (const t of protocolDetfTokens) opts.push({ value: t.address, label: t.display || t.symbol, chainId: CHAIN_ID_SEPOLIA, type: 'vault' })
  if (includeLpTokens) for (const t of uniV2PoolTokens) opts.push({ value: t.address, label: t.display || t.symbol, chainId: CHAIN_ID_SEPOLIA, type: 'lp' })
  if (includeLpTokens) for (const t of aerodromePoolTokens) opts.push({ value: t.address, label: t.display || t.symbol, chainId: CHAIN_ID_SEPOLIA, type: 'lp' })
  if (includeVaultShares) for (const t of strategyVaultTokens) opts.push({ value: t.address, label: t.display || t.symbol, chainId: CHAIN_ID_SEPOLIA, type: 'vault' })

  return opts
}

export function buildTokenOptionsForChain(
  chainId: number,
  includeVaultShares: boolean = true,
  includeLpTokens: boolean = true,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment()
): TokenOption[] {
  const opts: TokenOption[] = []
  const {
    baseTokens,
    erc4626Tokens,
    seigniorageDetfs,
    protocolDetfTokens,
    uniV2PoolTokens,
    aerodromePoolTokens,
    strategyVaultTokens,
  } = getCached(chainId, environment)
  const platform = getArtifactsOrNull(chainId, environment)?.platform

  opts.push({ value: 'ETH', label: 'ETH', chainId, type: 'token' })
  if (resolvePlatformWethAddress(platform)) {
    opts.push({ value: 'WETH9', label: 'WETH9', chainId, type: 'token' })
  }

  for (const t of baseTokens) opts.push({ value: t.address, label: t.display || t.symbol, chainId, type: 'token' })
  for (const t of erc4626Tokens) opts.push({ value: t.address, label: t.display || t.symbol, chainId, type: 'vault' })
  for (const t of seigniorageDetfs) opts.push({ value: t.address, label: t.display || t.symbol, chainId, type: 'vault' })
  for (const t of protocolDetfTokens) opts.push({ value: t.address, label: t.display || t.symbol, chainId, type: 'vault' })
  if (includeLpTokens) for (const t of uniV2PoolTokens) opts.push({ value: t.address, label: t.display || t.symbol, chainId, type: 'lp' })
  if (includeLpTokens) for (const t of aerodromePoolTokens) opts.push({ value: t.address, label: t.display || t.symbol, chainId, type: 'lp' })
  if (includeVaultShares) for (const t of strategyVaultTokens) opts.push({ value: t.address, label: t.display || t.symbol, chainId, type: 'vault' })

  return opts
}

export function resolveTokenAddressFromOption(value: TokenOption['value']): Address | null {
  if (value === 'ETH') return null
  if (value === 'WETH9') {
    const platform = getAddressArtifacts(CHAIN_ID_SEPOLIA).platform
    return resolvePlatformWethAddress(platform)
  }
  return value as Address
}

export function resolveTokenAddressFromOptionForChain(
  chainId: number,
  value: TokenOption['value'],
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment()
): Address | null {
  if (value === 'ETH') return null
  if (value === 'WETH9') {
    const platform = getArtifactsOrNull(chainId, environment)?.platform
    return resolvePlatformWethAddress(platform)
  }
  return value as Address
}

export function resolvePoolType(address?: string | null): PoolOption['type'] | undefined {
  if (!address) return undefined
  const pool = findPoolByAddress(address)
  if (!pool) return undefined
  const { balancerPoolTokens } = getCached()
  return balancerPoolTokens.some((p) => p.address.toLowerCase() === pool.address.toLowerCase()) ? 'balancer' : 'vault'
}

export function resolvePoolTypeForChain(
  chainId: number,
  address?: string | null,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment()
): PoolOption['type'] | undefined {
  if (!address) return undefined
  const { balancerPoolTokens, strategyVaultTokens, erc4626Tokens, protocolDetfTokens } = getCached(chainId, environment)
  const a = address.toLowerCase()
  const platform = getArtifactsOrNull(chainId, environment)?.platform
  const weth = resolvePlatformWethAddress(platform)
  if (weth && a === weth.toLowerCase()) return 'balancer'
  if (balancerPoolTokens.some((p) => p.address.toLowerCase() === a)) return 'balancer'
  if (strategyVaultTokens.some((p) => p.address.toLowerCase() === a)) return 'vault'
  if (erc4626Tokens.some((p) => p.address.toLowerCase() === a)) return 'vault'
  if (protocolDetfTokens.some((p) => p.address.toLowerCase() === a)) return 'vault'
  return undefined
}
