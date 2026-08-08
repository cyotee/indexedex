'use client'

import { formatUnits, parseUnits } from 'viem'
import { Button } from './Button'

export type AmountFieldProps = {
  label?: string
  value: string
  onChange: (value: string) => void
  decimals?: number
  balance?: bigint
  symbol?: string
  /**
   * Optional USD display. When null/undefined, no `$` is shown
   * (K13: hide USD when price source is none).
   */
  usdValue?: string | null
  disabled?: boolean
  placeholder?: string
  'data-testid'?: string
  className?: string
}

export function AmountField({
  label = 'Amount',
  value,
  onChange,
  decimals = 18,
  balance,
  symbol,
  usdValue = null,
  disabled = false,
  placeholder = '0.0',
  'data-testid': testId = 'amount-field',
  className = '',
}: AmountFieldProps) {
  const balanceDisplay =
    typeof balance === 'bigint' ? formatUnits(balance, decimals) : null

  const showUsd =
    usdValue != null && String(usdValue).trim() !== '' && !/^none$/i.test(String(usdValue))

  return (
    <div className={className} data-testid={testId}>
      <label className="block text-xs text-[var(--text-muted,#9aa3b2)]">
        {label}
        {symbol ? ` (${symbol})` : ''}
        <div className="mt-1 flex gap-2">
          <input
            data-testid={`${testId}-input`}
            value={value}
            onChange={(e) => onChange(e.target.value)}
            placeholder={placeholder}
            disabled={disabled}
            inputMode="decimal"
            className="flex-1 rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 font-mono text-sm tabular-nums text-[var(--text-primary,#EDEDED)] disabled:opacity-50"
          />
          {typeof balance === 'bigint' ? (
            <Button
              size="sm"
              variant="secondary"
              disabled={disabled}
              data-testid={`${testId}-max`}
              onClick={() => onChange(formatUnits(balance, decimals))}
            >
              Max
            </Button>
          ) : null}
        </div>
      </label>
      <div className="mt-1 flex flex-wrap items-center gap-x-3 gap-y-0.5 text-[11px] text-[var(--text-muted,#9aa3b2)]">
        {balanceDisplay != null ? (
          <span>
            Balance: <span className="font-mono tabular-nums">{balanceDisplay}</span>
            {symbol ? ` ${symbol}` : ''}
          </span>
        ) : null}
        {showUsd ? (
          <span data-testid={`${testId}-usd`} className="tabular-nums">
            ≈ ${usdValue}
          </span>
        ) : null}
      </div>
    </div>
  )
}

/** Parse amount string with decimals; returns undefined on invalid. */
export function parseAmountFieldValue(
  value: string,
  decimals: number,
): bigint | undefined {
  if (!value?.trim()) return undefined
  try {
    return parseUnits(value.trim(), decimals)
  } catch {
    return undefined
  }
}

export default AmountField
