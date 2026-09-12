import { formatUnits, type Address } from 'viem'

import { asAddr } from './actionTokens'
import { insightsDetfHref } from './insightsHref'

/** Directional SY discovery supplies payment routes; raw DETF always supports direct staking. */
export function collectStakeTokenAddresses(input: {
  detf?: unknown
  stakingToken?: unknown
  acceptedInputs?: readonly unknown[]
}): Address[] {
  const seen = new Set<string>()
  const out: Address[] = []
  const staking = asAddr(input.stakingToken)?.toLowerCase()
  for (const candidate of [input.detf, ...(input.acceptedInputs ?? [])]) {
    const address = asAddr(candidate)
    if (!address || address.toLowerCase() === staking || seen.has(address.toLowerCase())) continue
    seen.add(address.toLowerCase())
    out.push(address)
  }
  return out
}

/** Both previews and writes use this route, including its actual allowance spender. */
export function stakingExchangeRoute(input: {
  detf?: Address
  stakingToken?: Address
  tokenIn?: Address
  unstake: boolean
}) {
  const { detf, stakingToken, tokenIn, unstake } = input
  if (!detf || !stakingToken || (!unstake && !tokenIn)) return undefined
  const direct = unstake || tokenIn?.toLowerCase() === detf.toLowerCase()
  return {
    target: direct ? stakingToken : detf,
    tokenIn: unstake ? stakingToken : tokenIn!,
    tokenOut: unstake ? detf : stakingToken,
    needsAllowance: !unstake,
    requiresLiveReserve: !direct,
  }
}

export function formatTokenAmount(value: bigint | undefined, decimals = 9, maxFrac = 6): string {
  if (value == null) return '—'
  const raw = formatUnits(value, decimals)
  const [whole, frac] = raw.split('.')
  if (!frac) return whole ?? raw
  const trimmed = frac.slice(0, maxFrac).replace(/0+$/, '')
  return trimmed ? `${whole}.${trimmed}` : (whole ?? raw)
}

export function insightsStakingHref(detf: string): string {
  return insightsDetfHref(detf, 'stake')
}
