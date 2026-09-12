import { formatUnits } from 'viem'

/**
 * Human-readable preview out / minOut using the *output* token decimals
 * (vault shares on deposit, underlying on withdraw) — never hardcode 18.
 */
export function formatPreviewAmount(amount: bigint, decimals: number): string {
  const dec =
    Number.isFinite(decimals) && decimals >= 0 && decimals <= 255 ? decimals : 18
  return formatUnits(amount, dec)
}
