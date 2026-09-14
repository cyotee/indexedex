import { erc20Abi, formatUnits, parseEventLogs, type Address, type TransactionReceipt } from 'viem'

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

/** Payment tokens acquire wallet-held DETF first; a separate direct stake follows.
 * The deployed combined route sweeps its held DETF before it can stake it.
 * Both previews and writes use the same output and allowance spender.
 */
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
    tokenOut: unstake || !direct ? detf : stakingToken,
    needsAllowance: !unstake,
    requiresLiveReserve: !direct,
  }
}

/** Only this receipt's net DETF delivery becomes the next staking amount. */
export function receivedDetfAmount(logs: TransactionReceipt['logs'], detf: Address, recipient: Address): bigint {
  const transfers = parseEventLogs({
    abi: erc20Abi, eventName: 'Transfer',
    logs: logs.filter((log) => log.address.toLowerCase() === detf.toLowerCase()),
  })
  let received = 0n
  for (const { args } of transfers) {
    if (args.to.toLowerCase() === recipient.toLowerCase()) received += args.value
    if (args.from.toLowerCase() === recipient.toLowerCase()) received -= args.value
  }
  if (received <= 0n) throw new Error('Could not identify the received DETF amount. Check your wallet balance before staking.')
  return received
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
