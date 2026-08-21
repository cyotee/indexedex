import {
  CHAIN_ID_ROBINHOOD_TESTNET,
  getDefaultDeploymentEnvironment,
  type DeploymentEnvironment,
} from '@indexedex/protocol/addressArtifacts'
import {
  getFeaturedFeeDetfsForChain,
  getProtocolDetfsForChain,
  getStrategyVaultTokensForChain,
  isFeaturedFeeDetfAddress,
  type TokenListEntry,
} from '@indexedex/protocol/tokenlists'
import { assembleEarnProducts, filterEarnProducts, resolveFeaturedProducts, parseFeaturedAddressList } from './assembleEarnProducts'
import type { EarnFilterOptions, EarnProduct, EarnProductInput } from '@indexedex/protocol/earn/types'

function toInput(entry: TokenListEntry): EarnProductInput {
  return {
    address: entry.address,
    chainId: entry.chainId,
    name: entry.name,
    symbol: entry.symbol,
    decimals: entry.decimals,
    display: entry.display,
    ...(entry.tags?.length ? { tags: entry.tags } : {}),
    ...(entry.extensions ? { extensions: entry.extensions } : {}),
  }
}

function isClaimEntry(entry: TokenListEntry): boolean {
  return (entry.tags ?? []).map((tag) => tag.toLowerCase()).includes('claim')
}

/**
 * Earn catalog: strategy vaults plus DETF instances from the chain tokenlists.
 * Claim tokens are not vaults. On Robinhood testnet, keep deployed DETFs on this
 * list (including TTCHIR). Other chains still hide featured-fee DETFs (Wave 2).
 */
export function loadEarnProductsForChain(
  chainId: number,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment(),
): EarnProduct[] {
  const catalog = assembleEarnProducts({
    strategy: getStrategyVaultTokensForChain(chainId, environment)
      .filter((t) => !isClaimEntry(t))
      .map(toInput),
    protocolDetf: getProtocolDetfsForChain(chainId, environment)
      .filter((t) => !isClaimEntry(t))
      .map(toInput),
  })
  if (chainId === CHAIN_ID_ROBINHOOD_TESTNET) return catalog
  const feeExcluded = new Set(
    getFeaturedFeeDetfsForChain(chainId, environment).map((t) => t.address.toLowerCase()),
  )
  if (feeExcluded.size === 0) return catalog
  return catalog.filter((p) => !feeExcluded.has(p.address.toLowerCase()))
}

export function loadFilteredEarnProducts(
  chainId: number,
  options: EarnFilterOptions = {},
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment(),
): EarnProduct[] {
  return filterEarnProducts(loadEarnProductsForChain(chainId, environment), options)
}

export function findEarnProduct(
  chainId: number,
  address: string,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment(),
): EarnProduct | undefined {
  const key = address.trim().toLowerCase()
  return loadEarnProductsForChain(chainId, environment).find((p) => p.address.toLowerCase() === key)
}

/**
 * Featured products for landing/Earn banner: env address list ∩ live catalog.
 * Legacy helper — strategy-focused. Prefer {@link loadFeaturedFeeDetfs} for Wave 2 fee DETF marketing.
 */
export function loadFeaturedEarnProducts(
  chainId: number,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment(),
  featuredRaw: string | undefined = process.env.NEXT_PUBLIC_FEATURED_EARN_ADDRESSES,
): EarnProduct[] {
  const catalog = loadEarnProductsForChain(chainId, environment)
  const candidates = parseFeaturedAddressList(featuredRaw)
  if (candidates.length > 0) {
    return resolveFeaturedProducts(candidates, catalog)
  }
  // Default: first up to 3 strategy vaults, else first products of any kind.
  const strategies = catalog.filter((p) => p.productType === 'strategy')
  const pool = strategies.length > 0 ? strategies : catalog
  return pool.slice(0, 3)
}

/**
 * Wave 2 featured Protocol DETFs from the dedicated tokenlist.
 * Max 3 cards; order follows the list. Not mixed into Earn catalog.
 */
export function loadFeaturedFeeDetfs(
  chainId: number,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment(),
  max = 3,
): TokenListEntry[] {
  return getFeaturedFeeDetfsForChain(chainId, environment).slice(0, Math.max(0, max))
}

export {
  assembleEarnProducts,
  filterEarnProducts,
  resolveFeaturedProducts,
  parseFeaturedAddressList,
  isFeaturedFeeDetfAddress,
}
