'use client'

/**
 * Multi-leg primary action CTA.
 *
 * Presentational only — consumers wire onClick handlers.
 * Do NOT call useApprovalFlow from this component.
 *
 * K17: For sequential multi-leg explicit approvals, consumers must pass
 * separate onApproveTokenPermit2 / onApprovePermit2Router handlers
 * (handleIssuePermit2Approval / handleIssueRouterApproval).
 * Never use one-shot handleApproval for multi-leg sequential UI.
 */

import { Button } from './Button'
import {
  pendingLabelForLeg,
  type PendingLeg,
  type WalletGate,
} from '../../lib/tx/actionState'

export type ActionCtaProps = {
  gate: WalletGate
  /** Which leg is currently pending (null = idle). Never share one isLoading across legs. */
  pendingLeg?: PendingLeg
  onConnect?: () => void
  onSwitchNetwork?: () => void
  /** Explicit mode: token → Permit2 only */
  onApproveTokenPermit2?: () => void
  /** Explicit mode: permit2 → router only */
  onApprovePermit2Router?: () => void
  onExecute?: () => void
  className?: string
  'data-testid'?: string
}

export function ActionCta({
  gate,
  pendingLeg = null,
  onConnect,
  onSwitchNetwork,
  onApproveTokenPermit2,
  onApprovePermit2Router,
  onExecute,
  className = '',
  'data-testid': testId = 'action-cta',
}: ActionCtaProps) {
  const loading = pendingLeg != null
  const label = pendingLabelForLeg(pendingLeg, gate.label)

  if (gate.kind === 'disconnected') {
    return (
      <Button
        data-testid={testId}
        data-gate="disconnected"
        className={className}
        loading={pendingLeg === 'connect'}
        disabled={loading && pendingLeg !== 'connect'}
        onClick={() => onConnect?.()}
      >
        {pendingLeg === 'connect' ? label : gate.label}
      </Button>
    )
  }

  if (gate.kind === 'wrong-network') {
    return (
      <Button
        data-testid={testId}
        data-gate="wrong-network"
        className={className}
        loading={pendingLeg === 'switch'}
        disabled={loading && pendingLeg !== 'switch'}
        onClick={() => onSwitchNetwork?.()}
      >
        {pendingLeg === 'switch' ? label : gate.label}
      </Button>
    )
  }

  if (gate.kind === 'approve') {
    const isToken = gate.leg === 'token-permit2'
    const thisPending = isToken
      ? pendingLeg === 'approve-token-permit2'
      : pendingLeg === 'approve-permit2-router'
    return (
      <Button
        data-testid={testId}
        data-gate="approve"
        data-approve-leg={gate.leg}
        className={className}
        loading={thisPending}
        disabled={loading && !thisPending}
        onClick={() => {
          if (isToken) onApproveTokenPermit2?.()
          else onApprovePermit2Router?.()
        }}
      >
        {thisPending ? label : gate.label}
      </Button>
    )
  }

  if (gate.kind === 'execute') {
    return (
      <Button
        data-testid={testId}
        data-gate="execute"
        className={className}
        loading={pendingLeg === 'execute'}
        disabled={loading && pendingLeg !== 'execute'}
        onClick={() => onExecute?.()}
      >
        {pendingLeg === 'execute' ? label : gate.label}
      </Button>
    )
  }

  // disabled
  return (
    <Button
      data-testid={testId}
      data-gate="disabled"
      data-disabled-reason={gate.reason}
      className={className}
      disabled
    >
      {gate.label}
    </Button>
  )
}

export default ActionCta
