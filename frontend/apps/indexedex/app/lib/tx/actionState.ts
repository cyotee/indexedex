/**
 * Multi-leg wallet gate resolution for ethskills four-state CTA.
 *
 * States (one primary action at a time):
 *   disconnected → wrong-network → approve (token→Permit2) → approve (permit2→router) → execute
 *
 * Consumers MUST wire split handlers:
 *   handleIssuePermit2Approval / handleIssueRouterApproval
 * Do NOT use one-shot handleApproval for sequential multi-leg UI (K17).
 */

export type ApproveLeg = 'token-permit2' | 'permit2-router'

export type WalletGateKind =
  | 'disconnected'
  | 'wrong-network'
  | 'approve'
  | 'execute'
  | 'disabled'

export type WalletGate =
  | { kind: 'disconnected'; label: string }
  | { kind: 'wrong-network'; label: string }
  | { kind: 'approve'; leg: ApproveLeg; label: string }
  | { kind: 'execute'; label: string }
  | { kind: 'disabled'; label: string; reason: 'no-preview' | 'invalid-amount' | 'other' }

export type PendingLeg =
  | null
  | 'connect'
  | 'switch'
  | 'approve-token-permit2'
  | 'approve-permit2-router'
  | 'execute'

export type ResolveWalletGateInput = {
  isConnected: boolean
  isWrongNetwork: boolean
  /** Valid positive amount parsed */
  amountValid: boolean
  /** Preview quote available (non-null minOut path ready) */
  hasPreview: boolean
  /** Token → Permit2 allowance insufficient */
  needsTokenApproval: boolean
  /** Permit2 → router allowance insufficient (explicit mode only) */
  needsPermit2Approval: boolean
  /** Label when ready to execute (Deposit / Withdraw / Swap) */
  executeLabel?: string
  /**
   * Signed mode only needs token→Permit2 before sign path.
   * When true, permit2→router leg is skipped.
   */
  signedMode?: boolean
}

const DEFAULT_EXECUTE = 'Continue'

/**
 * Pure gate resolver. Never returns a state that would show Approve and Execute together.
 */
export function resolveWalletGate(input: ResolveWalletGateInput): WalletGate {
  if (!input.isConnected) {
    return { kind: 'disconnected', label: 'Connect wallet' }
  }
  if (input.isWrongNetwork) {
    return { kind: 'wrong-network', label: 'Switch network' }
  }
  if (!input.amountValid) {
    return {
      kind: 'disabled',
      label: input.executeLabel ?? DEFAULT_EXECUTE,
      reason: 'invalid-amount',
    }
  }
  if (!input.hasPreview) {
    return {
      kind: 'disabled',
      label: input.executeLabel ?? DEFAULT_EXECUTE,
      reason: 'no-preview',
    }
  }
  if (input.needsTokenApproval) {
    return {
      kind: 'approve',
      leg: 'token-permit2',
      label: 'Approve token for Permit2',
    }
  }
  if (!input.signedMode && input.needsPermit2Approval) {
    return {
      kind: 'approve',
      leg: 'permit2-router',
      label: 'Approve Permit2 for router',
    }
  }
  return {
    kind: 'execute',
    label: input.executeLabel ?? DEFAULT_EXECUTE,
  }
}

/** Loading label for the active pending leg (never shared isLoading across legs). */
export function pendingLabelForLeg(
  pending: PendingLeg,
  idleLabel: string,
): string {
  switch (pending) {
    case 'connect':
      return 'Connecting…'
    case 'switch':
      return 'Switching…'
    case 'approve-token-permit2':
      return 'Approving token…'
    case 'approve-permit2-router':
      return 'Approving Permit2…'
    case 'execute':
      return 'Submitting…'
    default:
      return idleLabel
  }
}

/**
 * Map gate + pending to the single pending leg key for ActionCta.
 * Used so only the active button shows a loading state.
 */
export function gateToPendingLeg(
  gate: WalletGate,
  isPending: boolean,
): PendingLeg {
  if (!isPending) return null
  switch (gate.kind) {
    case 'disconnected':
      return 'connect'
    case 'wrong-network':
      return 'switch'
    case 'approve':
      return gate.leg === 'token-permit2'
        ? 'approve-token-permit2'
        : 'approve-permit2-router'
    case 'execute':
      return 'execute'
    default:
      return null
  }
}
