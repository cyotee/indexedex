/**
 * Shared approval-need gates for multi-leg CTAs.
 * Unknown (loading) allowance must be treated as needs-approval so Execute
 * never enables before on-chain state is known (matches Swap money path).
 */

/**
 * @param effectiveAmount - amount user intends to spend
 * @param allowance - ERC20 or Permit2 amount; undefined/null = still loading
 */
export function needsApprovalFromAllowance(
  effectiveAmount: bigint | undefined | null,
  allowance: bigint | undefined | null,
): boolean {
  if (effectiveAmount == null || effectiveAmount <= BigInt(0)) return false
  if (allowance === undefined || allowance === null) return true
  return allowance < effectiveAmount
}
