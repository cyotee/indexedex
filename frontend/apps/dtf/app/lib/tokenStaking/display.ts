import { formatUnits } from 'viem'

import { TOKEN_STAKING_PHASE } from './abi'

export function formatTokenAmount(amount: bigint, decimals = 18, maxFrac = 4): string {
  const raw = formatUnits(amount, decimals)
  const [whole, frac = ''] = raw.split('.')
  const trimmed = frac.slice(0, maxFrac).replace(/0+$/, '')
  return trimmed.length > 0 ? `${whole}.${trimmed}` : whole
}

export function migrationPending(phase: number | undefined): boolean {
  return phase !== TOKEN_STAKING_PHASE.Wrapped
}

export function migrationLabel(phase: number | undefined): string {
  if (phase === TOKEN_STAKING_PHASE.Wrapped) return 'Done'
  if (phase === TOKEN_STAKING_PHASE.Migrating) return 'Wrapping'
  return 'Pending'
}

/** Claimable rebasing token. "-" until the wrap is done. */
export function claimAfterWrapDisplay(
  phase: number | undefined,
  preview: bigint | undefined,
  decimals = 18,
): string {
  if (phase !== TOKEN_STAKING_PHASE.Wrapped) return '-'
  if (preview === undefined) return '-'
  return formatTokenAmount(preview, decimals)
}
