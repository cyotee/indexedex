import { formatUnits, toFunctionSelector } from 'viem'

import { asAddr } from './actionTokens'
import { isZero } from './tokenLabels'

export const DEPOSIT_CLAIM_SELECTOR = toFunctionSelector(
  'depositClaim(address,uint256,uint256,address,bool,uint256)',
)
export const BUY_CLAIM_SELECTOR = toFunctionSelector(
  'buyClaim(uint256,uint256,address,bool,uint256)',
)

export type ClaimMintPath = 'depositClaim' | 'buyClaim' | 'none'

export function hasFacet(addr: string | undefined | null): boolean {
  return !!addr && !isZero(addr)
}

export function claimMintPathFromFacets(input: {
  depositClaimFacet?: string | null
  buyClaimFacet?: string | null
}): ClaimMintPath {
  if (hasFacet(input.depositClaimFacet)) return 'depositClaim'
  if (hasFacet(input.buyClaimFacet)) return 'buyClaim'
  return 'none'
}

/** Prefer loupe facets. Weighted DETFs mint claim via depositClaim; one-vault via buyClaim. */
export function resolveClaimMintPath(input: {
  depositClaimFacet?: string | null
  buyClaimFacet?: string | null
  weighted?: boolean
}): ClaimMintPath {
  const fromFacets = claimMintPathFromFacets(input)
  if (fromFacets !== 'none') return fromFacets
  return input.weighted ? 'depositClaim' : 'buyClaim'
}

export function collectStakeTokenAddresses(input: {
  path: ClaimMintPath
  detf?: unknown
  actionTokens?: readonly unknown[]
}): `0x${string}`[] {
  const detf = asAddr(input.detf)
  if (input.path === 'buyClaim') return detf ? [detf] : []
  if (input.path === 'none') return detf ? [detf] : []

  const seen = new Set<string>()
  const out: `0x${string}`[] = []
  const push = (value: unknown) => {
    const addr = asAddr(value)
    if (!addr) return
    const key = addr.toLowerCase()
    if (seen.has(key)) return
    seen.add(key)
    out.push(addr)
  }
  for (const token of input.actionTokens ?? []) push(token)
  push(detf)
  return out
}

export function formatTokenAmount(value: bigint | undefined, decimals = 18, maxFrac = 6): string {
  if (value == null) return '—'
  const raw = formatUnits(value, decimals)
  const [whole, frac = ''] = raw.split('.')
  if (!frac) return whole ?? raw
  const trimmed = frac.slice(0, maxFrac).replace(/0+$/, '')
  return trimmed ? `${whole}.${trimmed}` : (whole ?? raw)
}

export function insightsStakingHref(detf: string): string {
  return `/insights?detf=${detf}&tab=stake`
}
