'use client'

import { useMemo, useState } from 'react'
import { formatUnits, parseUnits } from 'viem'

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
  onBondWithWeth: (amount: bigint, lockSeconds: bigint, wethAsEth: boolean) => Promise<void>
  onBondWithRich: (amount: bigint, lockSeconds: bigint) => Promise<void>
}

export default function BondSection({
  isConnected,
  walletMatchesDataChain,
  isWritePending,
  wethDecimals,
  richDecimals,
  wethBalance,
  richBalance,
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
    <div className="rounded-lg border border-gray-700 bg-gray-800 p-4">
      <div className="text-sm font-medium text-gray-100">Bond Positions</div>
      <div className="mt-1 text-xs text-gray-400">Lock duration is shared across both bond actions.</div>

      <label className="mt-3 block text-xs text-gray-400">Lock (days)</label>
      <input
        value={lockDays}
        onChange={(event) => setLockDays(event.target.value)}
        className="mt-1 w-full rounded-md border border-gray-700 bg-gray-950 px-3 py-2 text-sm text-gray-100"
        placeholder="30"
      />

      <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div className="rounded-md border border-gray-700 bg-gray-900 p-3">
          <div className="text-sm font-medium text-gray-100">Bond with WETH</div>
          <label className="mt-2 block text-xs text-gray-400">WETH amount</label>
          <input
            value={bondWethAmount}
            onChange={(event) => setBondWethAmount(event.target.value)}
            className="mt-1 w-full rounded-md border border-gray-700 bg-gray-950 px-3 py-2 text-sm text-gray-100"
            placeholder="0.5"
          />
          <label className="mt-2 flex items-center gap-2 text-xs text-gray-400">
            <input
              type="checkbox"
              checked={bondWethAsEth}
              onChange={(event) => setBondWethAsEth(event.target.checked)}
              className="rounded border-gray-600 bg-gray-950"
            />
            Wrap native ETH into WETH before bonding
          </label>
          {wethBalance !== undefined ? <div className="mt-1 text-xs text-gray-400">Balance: {formatUnits(wethBalance, wethDecimals)} WETH</div> : null}
          {parsedBondWeth !== undefined ? <div className="mt-1 text-xs text-gray-500">Parsed: {formatUnits(parsedBondWeth, wethDecimals)} WETH</div> : null}
          <button
            type="button"
            onClick={() => parsedBondWeth !== undefined ? void onBondWithWeth(parsedBondWeth, lockSeconds, bondWethAsEth) : undefined}
            disabled={!isConnected || !walletMatchesDataChain || isWritePending || !parsedBondWeth}
            className="mt-3 w-full rounded-md bg-blue-600 px-3 py-2 text-sm font-medium text-white hover:bg-blue-500 disabled:opacity-50"
          >
            {bondWethAsEth ? 'Bond ETH' : 'Bond WETH'}
          </button>
        </div>

        <div className="rounded-md border border-gray-700 bg-gray-900 p-3">
          <div className="text-sm font-medium text-gray-100">Bond with RICH</div>
          <label className="mt-2 block text-xs text-gray-400">RICH amount</label>
          <input
            value={bondRichAmount}
            onChange={(event) => setBondRichAmount(event.target.value)}
            className="mt-1 w-full rounded-md border border-gray-700 bg-gray-950 px-3 py-2 text-sm text-gray-100"
            placeholder="100"
          />
          {richBalance !== undefined ? <div className="mt-1 text-xs text-gray-400">Balance: {formatUnits(richBalance, richDecimals)} RICH</div> : null}
          {parsedBondRich !== undefined ? <div className="mt-1 text-xs text-gray-500">Parsed: {formatUnits(parsedBondRich, richDecimals)} RICH</div> : null}
          <button
            type="button"
            onClick={() => parsedBondRich !== undefined ? void onBondWithRich(parsedBondRich, lockSeconds) : undefined}
            disabled={!isConnected || !walletMatchesDataChain || isWritePending || !parsedBondRich}
            className="mt-3 w-full rounded-md bg-purple-600 px-3 py-2 text-sm font-medium text-white hover:bg-purple-500 disabled:opacity-50"
          >
            Bond RICH
          </button>
        </div>
      </div>
    </div>
  )
}