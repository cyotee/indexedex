import {
  getDefaultDeploymentEnvironment,
  type DeploymentEnvironment,
} from '../addressArtifacts'
import {
  getProtocolDetfsForChain,
  getSeigniorageDetfsForChain,
  getStrategyVaultTokensForChain,
  type TokenListEntry,
} from '../tokenlists'
import { assembleEarnProducts, filterEarnProducts, resolveFeaturedProducts, parseFeaturedAddressList } from './assembleEarnProducts'
import type { EarnFilterOptions, EarnProduct, EarnProductInput } from './types'

function toInput(entry: TokenListEntry): EarnProductInput {
  return {
    address: entry.address,
    chainId: entry.chainId,
    name: entry.name,
    symbol: entry.symbol,
    decimals: entry.decimals,
    display: entry.display,
  }
}

/**
 * Build the Earn catalog for a chain from live tokenlists (strategy + DETFs).
 */
export function loadEarnProductsForChain(
  chainId: number,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment(),
): EarnProduct[] {
  return assembleEarnProducts({
    strategy: getStrategyVaultTokensForChain(chainId, environment).map(toInput),
    protocolDetf: getProtocolDetfsForChain(chainId, environment).map(toInput),
    seigniorageDetf: getSeigniorageDetfsForChain(chainId, environment).map(toInput),
  })
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

export { assembleEarnProducts, filterEarnProducts, resolveFeaturedProducts, parseFeaturedAddressList }
