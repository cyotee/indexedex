'use client'

interface ApprovalSettingsPanelProps {
  approvalMode: 'explicit' | 'signed'
  onModeChange: (mode: 'explicit' | 'signed') => void
  showSettings: boolean
  onToggleSettings: () => void
  permit2SpendingLimit: string
  onSpendingLimitChange: (value: string) => void
  onIssuePermit2Approval: (limit?: bigint) => void | Promise<void>
  onIssueRouterApproval: (limit?: bigint) => void | Promise<void>
  onEnsureApprovals: () => void | Promise<void>
  disableActions?: boolean
  signedDisabled?: boolean
  signedDisabledReason?: string
  explicitDescription?: string
  signedDescription?: string
  className?: string
}

function parseOptionalLimit(value: string): bigint | undefined {
  if (!value.trim()) return undefined
  try {
    return BigInt(value)
  } catch {
    return undefined
  }
}

export default function ApprovalSettingsPanel({
  approvalMode,
  onModeChange,
  showSettings,
  onToggleSettings,
  permit2SpendingLimit,
  onSpendingLimitChange,
  onIssuePermit2Approval,
  onIssueRouterApproval,
  onEnsureApprovals,
  disableActions = false,
  signedDisabled = false,
  signedDisabledReason,
  explicitDescription = 'Two-step: approve Token → Permit2, then Permit2 → Router. Best for repeated swaps.',
  signedDescription = 'EIP-712 signature per swap. Only Token → Permit2 approval is needed ahead of time.',
  className = '',
}: ApprovalSettingsPanelProps) {
  const parsedLimit = parseOptionalLimit(permit2SpendingLimit)

  return (
    <div className={className}>
      <button
        onClick={onToggleSettings}
        className="flex w-full items-center justify-between rounded-lg border border-slate-600 bg-slate-700/50 px-4 py-2 transition-colors hover:bg-slate-700"
        type="button"
      >
        <div className="flex items-center gap-2">
          <svg className="h-5 w-5 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
          </svg>
          <span className="text-sm font-medium text-gray-200">Approval Settings</span>
        </div>
        <svg className={`h-4 w-4 text-gray-400 transition-transform ${showSettings ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {showSettings ? (
        <div className="mt-2 rounded-lg border border-slate-600 bg-slate-700/30 p-4">
          <div className="mb-3 text-xs text-gray-400">Choose how token transfers are authorized for router-based staking actions.</div>

          <label className={`flex cursor-pointer items-start gap-3 rounded-lg border p-3 transition-all ${approvalMode === 'explicit' ? 'border-blue-500 bg-blue-600/20' : 'border-slate-600 bg-slate-700/30 hover:border-slate-500'}`}>
            <input
              type="radio"
              name="approvalMode"
              value="explicit"
              checked={approvalMode === 'explicit'}
              onChange={() => onModeChange('explicit')}
              className="mt-1"
            />
            <div className="flex-1">
              <div className="flex items-center gap-2">
                <span className={`text-sm font-medium ${approvalMode === 'explicit' ? 'text-blue-300' : 'text-gray-200'}`}>Explicit Approvals</span>
                <span className="rounded bg-slate-600 px-2 py-0.5 text-xs text-gray-300">Default</span>
              </div>
              <div className="mt-1 text-xs text-gray-400">{explicitDescription}</div>
            </div>
          </label>

          <label className={`mt-2 flex cursor-pointer items-start gap-3 rounded-lg border p-3 transition-all ${approvalMode === 'signed' ? 'border-purple-500 bg-purple-600/20' : 'border-slate-600 bg-slate-700/30 hover:border-slate-500'}`}>
            <input
              type="radio"
              name="approvalMode"
              value="signed"
              checked={approvalMode === 'signed'}
              disabled={signedDisabled}
              onChange={() => onModeChange('signed')}
              className="mt-1"
            />
            <div className="flex-1">
              <div className="flex items-center gap-2">
                <span className={`text-sm font-medium ${approvalMode === 'signed' ? 'text-purple-300' : 'text-gray-200'}`}>Signed Permit2</span>
                <span className="rounded bg-purple-600/30 px-2 py-0.5 text-xs text-purple-300">Gasless</span>
              </div>
              <div className="mt-1 text-xs text-gray-400">{signedDescription}</div>
              {signedDisabled && signedDisabledReason ? <div className="mt-1 text-xs text-amber-300">{signedDisabledReason}</div> : null}
            </div>
          </label>

          <label className="mt-4 block text-xs text-gray-400">Permit2 spending limit (optional, raw wei)</label>
          <input
            value={permit2SpendingLimit}
            onChange={(event) => onSpendingLimitChange(event.target.value)}
            className="mt-1 w-full rounded-md border border-gray-700 bg-gray-950 px-3 py-2 text-sm text-gray-100"
            placeholder="Leave empty to use the default limit"
          />

          <div className="mt-3 flex flex-wrap gap-2">
            <button
              type="button"
              onClick={() => void onIssuePermit2Approval(parsedLimit)}
              disabled={disableActions}
              className="rounded-md bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
            >
              Issue Token → Permit2
            </button>
            <button
              type="button"
              onClick={() => void onIssueRouterApproval(parsedLimit)}
              disabled={disableActions}
              className="rounded-md bg-indigo-500 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-400 disabled:opacity-50"
            >
              Issue Permit2 → Router
            </button>
            <button
              type="button"
              onClick={() => void onEnsureApprovals()}
              disabled={disableActions}
              className="rounded-md bg-indigo-700 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-600 disabled:opacity-50"
            >
              Ensure Approvals
            </button>
          </div>
        </div>
      ) : null}
    </div>
  )
}