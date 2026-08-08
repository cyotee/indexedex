'use client'

import { useState } from 'react'
import { Button } from '../../components/ui/Button'

interface SellNftSectionProps {
  isConnected: boolean
  walletMatchesDataChain: boolean
  isWritePending: boolean
  onSell: (tokenId: bigint) => Promise<void>
}

const inputClass =
  'mt-1 w-full rounded-md border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm text-[var(--text-primary,#EDEDED)]'

export default function SellNftSection({
  isConnected,
  walletMatchesDataChain,
  isWritePending,
  onSell,
}: SellNftSectionProps) {
  const [tokenIdInput, setTokenIdInput] = useState('')

  return (
    <div className="rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] p-4">
      <div className="text-sm font-medium text-[var(--text-primary,#EDEDED)]">Sell bond NFT</div>
      <p className="mt-0.5 text-xs text-[var(--text-muted,#9aa3b2)]">
        Receive rebasing claim token (claim token)
      </p>
      <label className="mt-2 block text-xs text-[var(--text-muted,#9aa3b2)]">Token ID</label>
      <input
        value={tokenIdInput}
        onChange={(event) => setTokenIdInput(event.target.value)}
        className={inputClass}
        placeholder="1"
      />
      <Button
        type="button"
        variant="primary"
        className="mt-3 w-full"
        onClick={() => {
          try {
            void onSell(BigInt(tokenIdInput || '0'))
          } catch {
            // invalid input stays blocked by disabled state
          }
        }}
        disabled={!isConnected || !walletMatchesDataChain || isWritePending || !tokenIdInput.trim()}
        loading={isWritePending}
      >
        Sell NFT
      </Button>
    </div>
  )
}
