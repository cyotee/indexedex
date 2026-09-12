import { formatUnits } from 'viem'

/**
 * Format bond share / reward amounts for UI and certificate SVG.
 * Never return raw wei `.toString()` for user-visible amounts.
 */
export function formatBondAmount(
  amount: bigint | undefined | null,
  decimals: number = 18,
): string {
  if (amount === undefined || amount === null) return '—'
  return formatUnits(amount, decimals)
}
