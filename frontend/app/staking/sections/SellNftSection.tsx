'use client'

import { useState } from 'react'

interface SellNftSectionProps {
  isConnected: boolean
  walletMatchesDataChain: boolean
  isWritePending: boolean
  onSell: (tokenId: bigint) => Promise<void>
}

export default function SellNftSection({ isConnected, walletMatchesDataChain, isWritePending, onSell }: SellNftSectionProps) {
  const [tokenIdInput, setTokenIdInput] = useState('')

  return (
    <div className="rounded-md border border-gray-700 bg-gray-900 p-3">
      <div className="text-sm font-medium text-gray-100">Sell NFT for RICHIR</div>
      <label className="mt-2 block text-xs text-gray-400">Token ID</label>
      <input
        value={tokenIdInput}
        onChange={(event) => setTokenIdInput(event.target.value)}
        className="mt-1 w-full rounded-md border border-gray-700 bg-gray-950 px-3 py-2 text-sm text-gray-100"
        placeholder="1"
      />
      <button
        type="button"
        onClick={() => {
          try {
            void onSell(BigInt(tokenIdInput || '0'))
          } catch {
            // invalid input stays blocked by disabled state
          }
        }}
        disabled={!isConnected || !walletMatchesDataChain || isWritePending || !tokenIdInput.trim()}
        className="mt-3 w-full rounded-md bg-orange-600 px-3 py-2 text-sm font-medium text-white hover:bg-orange-500 disabled:opacity-50"
      >
        Sell NFT
      </button>
    </div>
  )
}