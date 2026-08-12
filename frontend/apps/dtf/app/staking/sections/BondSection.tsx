'use client'

import { useMemo, useState } from 'react'
import { formatUnits, parseUnits } from 'viem'
import { Button } from '../../components/ui/Button'

function clampInt(value: string, fallback: number): number {
  const parsed = Number(value)
  if (!Number.isFinite(parsed)) return fallback
  return Math.max(0, Math.floor(parsed))
}

interface BondSectionProps {
  isConnected: boolean
  walletMatchesDataChain: boolean
  isWritePending: boolean
  wethDecimals: number
  richDecimals: number
  wethBalance: bigint | undefined
  richBalance: bigint | undefined
  /** Rate asset symbol when known (often WETH). */
  rateAssetSymbol?: string
  /** Pair token symbol when known. */
  pairTokenSymbol?: string
  onBondWithWeth: (amount: bigint, lockSeconds: bigint, wethAsEth: boolean) => Promise<void>
  onBondWithRich: (amount: bigint, lockSeconds: bigint) => Promise<void>
}

const inputClass =
  'mt-1 w-full rounded-md border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm text-[var(--text-primary,#EDEDED)]'
const panelClass =
  'rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] p-3'

export default function BondSection({
  isConnected,
  walletMatchesDataChain,
  isWritePending,
  wethDecimals,
  richDecimals,
  wethBalance,
  richBalance,
  rateAssetSymbol = 'WETH',
  pairTokenSymbol = 'pair token',
  onBondWithWeth,
  onBondWithRich,
}: BondSectionProps) {
  const [bondWethAmount, setBondWethAmount] = useState('')
  const [bondRichAmount, setBondRichAmount] = useState('')
  const [bondWethAsEth, setBondWethAsEth] = useState(false)
  const [lockDays, setLockDays] = useState('30')

  const lockSeconds = useMemo(() => BigInt(clampInt(lockDays, 30) * 24 * 60 * 60), [lockDays])

  const parsedBondWeth = useMemo(() => {
    if (!bondWethAmount) return undefined
    try {
      return parseUnits(bondWethAmount, wethDecimals)
    } catch {
      return undefined
    }
  }, [bondWethAmount, wethDecimals])

  const parsedBondRich = useMemo(() => {
    if (!bondRichAmount) return undefined
    try {
      return parseUnits(bondRichAmount, richDecimals)
    } catch {
      return undefined
    }
  }, [bondRichAmount, richDecimals])

  return (
    <div className="rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] p-4">
      <div className="text-sm font-medium text-[var(--text-primary,#EDEDED)]">Bond positions</div>
      <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
        Lock duration is shared across both bond actions.
      </div>

      <label className="mt-3 block text-xs text-[var(--text-muted,#9aa3b2)]">Lock (days)</label>
      <input
        data-testid="staking-bond-lock-days"
        value={lockDays}
        onChange={(event) => setLockDays(event.target.value)}
        className={inputClass}
        placeholder="30"
      />

      <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div className={panelClass} data-testid="staking-bond-rate-asset-panel">
          <div className="text-sm font-medium text-[var(--text-primary,#EDEDED)]">
            Bond with {rateAssetSymbol}
          </div>
          <p className="mt-0.5 text-xs text-[var(--text-muted,#9aa3b2)]">Rate asset · locks into bond NFT</p>
          <label className="mt-2 block text-xs text-[var(--text-muted,#9aa3b2)]">
            {bondWethAsEth ? 'ETH amount' : `${rateAssetSymbol} amount`}
          </label>
          <input
            data-testid="staking-bond-rate-asset-amount"
            value={bondWethAmount}
            onChange={(event) => setBondWethAmount(event.target.value)}
            className={inputClass}
            placeholder="0.5"
          />
          <label className="mt-2 flex items-center gap-2 text-xs text-[var(--text-muted,#9aa3b2)]">
            <input
              data-testid="staking-bond-wrap-eth"
              type="checkbox"
              checked={bondWethAsEth}
              onChange={(event) => setBondWethAsEth(event.target.checked)}
              className="rounded border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)]"
            />
            Wrap native ETH into WETH before bonding
          </label>
          {wethBalance !== undefined ? (
            <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]" data-testid="staking-bond-rate-asset-balance">
              Balance: {formatUnits(wethBalance, wethDecimals)} {rateAssetSymbol}
            </div>
          ) : null}
          {parsedBondWeth !== undefined ? (
            <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
              Parsed: {formatUnits(parsedBondWeth, wethDecimals)} {rateAssetSymbol}
            </div>
          ) : null}
          <Button
            type="button"
            variant="primary"
            className="mt-3 w-full"
            data-testid="staking-bond-rate-asset-submit"
            onClick={() =>
              parsedBondWeth !== undefined
                ? void onBondWithWeth(parsedBondWeth, lockSeconds, bondWethAsEth)
                : undefined
            }
            disabled={
              !isConnected || !walletMatchesDataChain || isWritePending || !parsedBondWeth
            }
            loading={isWritePending}
          >
            {bondWethAsEth ? 'Bond ETH' : `Bond ${rateAssetSymbol}`}
          </Button>
        </div>

        <div className={panelClass} data-testid="staking-bond-pair-token-panel">
          <div className="text-sm font-medium text-[var(--text-primary,#EDEDED)]">
            Bond with {pairTokenSymbol}
          </div>
          <p className="mt-0.5 text-xs text-[var(--text-muted,#9aa3b2)]">Pair token · locks into bond NFT</p>
          <label className="mt-2 block text-xs text-[var(--text-muted,#9aa3b2)]">
            {pairTokenSymbol} amount
          </label>
          <input
            data-testid="staking-bond-pair-token-amount"
            value={bondRichAmount}
            onChange={(event) => setBondRichAmount(event.target.value)}
            className={inputClass}
            placeholder="100"
          />
          {richBalance !== undefined ? (
            <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]" data-testid="staking-bond-pair-token-balance">
              Balance: {formatUnits(richBalance, richDecimals)} {pairTokenSymbol}
            </div>
          ) : null}
          {parsedBondRich !== undefined ? (
            <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
              Parsed: {formatUnits(parsedBondRich, richDecimals)} {pairTokenSymbol}
            </div>
          ) : null}
          <Button
            type="button"
            variant="secondary"
            className="mt-3 w-full"
            data-testid="staking-bond-pair-token-submit"
            onClick={() =>
              parsedBondRich !== undefined
                ? void onBondWithRich(parsedBondRich, lockSeconds)
                : undefined
            }
            disabled={
              !isConnected || !walletMatchesDataChain || isWritePending || !parsedBondRich
            }
            loading={isWritePending}
          >
            Bond {pairTokenSymbol}
          </Button>
        </div>
      </div>
    </div>
  )
}
