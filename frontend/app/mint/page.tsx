'use client'

import { useCallback, useEffect, useMemo, useState } from 'react'
import { useAccount } from 'wagmi'
import { useReadContract } from 'wagmi'
import { useWriteContract } from 'wagmi'
import { erc20Abi } from 'viem'
import { formatUnits, parseUnits } from 'viem'
import DebugPanel from '../components/DebugPanel'

import { getAddressArtifacts } from '../lib/addressArtifacts'
import {
  getMintableTestTokensForChain,
  type TokenOption
} from '../lib/tokenlists'
import { resolveAppChain } from '../lib/runtimeChains'
import { useSelectedNetwork } from '../lib/networkSelection'

const erc20MinterFacadeAbi = [
  {
    type: 'function',
    name: 'mintToken',
    inputs: [
      { name: 'token', type: 'address' },
      { name: 'amount', type: 'uint256' },
      { name: 'recipient', type: 'address' }
    ],
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'nonpayable'
  }
] as const

export default function MintPage() {
  const { address, isConnected } = useAccount()
  const { selectedChainId } = useSelectedNetwork()
  const resolvedChainId = selectedChainId || 11155111
  const { writeContract } = useWriteContract()

  const chain = useMemo(() => {
    return resolveAppChain(resolvedChainId)
  }, [resolvedChainId])

  const { platform } = useMemo(() => getAddressArtifacts(resolvedChainId), [resolvedChainId])

  // State
  const [amount, setAmount] = useState('')
  const [selectedToken, setSelectedToken] = useState<TokenOption['value'] | ''>('')
  const [mintPending, setMintPending] = useState(false)

  // Only base ERC20s for mint page (no vault shares, no LP tokens, no DETFs)
  const tokenOptions: TokenOption[] = useMemo(() => {
    const mintableTestTokens = getMintableTestTokensForChain(resolvedChainId)
    return mintableTestTokens.map((t) => ({
      value: t.address,
      label: t.symbol,
      chainId: resolvedChainId,
      type: 'token',
    }))
  }, [resolvedChainId])

  const selectedTokenAddress = useMemo(() => {
    if (!selectedToken) return null
    // Mint page selects addresses directly.
    return selectedToken as `0x${string}`
  }, [selectedToken])

  // Generic hooks for token operations
  const { data: tokenName, refetch: refetchName } = useReadContract({
    address: selectedTokenAddress as `0x${string}`,
    abi: erc20Abi,
    functionName: 'name',
    query: { enabled: !!selectedTokenAddress }
  })

  const { data: tokenSymbol, refetch: refetchSymbol } = useReadContract({
    address: selectedTokenAddress as `0x${string}`,
    abi: erc20Abi,
    functionName: 'symbol',
    query: { enabled: !!selectedTokenAddress }
  })

  const { data: tokenDecimals, refetch: refetchDecimals } = useReadContract({
    address: selectedTokenAddress as `0x${string}`,
    abi: erc20Abi,
    functionName: 'decimals',
    query: { enabled: !!selectedTokenAddress }
  })

  const exactAmount = useMemo(() => {
    if (!amount || !selectedTokenAddress) return undefined
    try {
      return parseUnits(amount, tokenDecimals ?? 18)
    } catch {
      return undefined
    }
  }, [amount, selectedTokenAddress, tokenDecimals])

  const { data: tokenBalance, refetch: refetchBalance } = useReadContract({
    address: selectedTokenAddress as `0x${string}`,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [address as `0x${string}`],
    query: { enabled: !!selectedTokenAddress && !!address }
  })

  // Handlers
  const handleMint = useCallback(async () => {
    if (!selectedTokenAddress || !exactAmount || !address) return
    setMintPending(true)
    try {
      await writeContract({
        chain,
        account: address,
        address: platform.erc20MinterFacade as `0x${string}`,
        abi: erc20MinterFacadeAbi,
        functionName: 'mintToken',
        args: [selectedTokenAddress as `0x${string}`, exactAmount, address as `0x${string}`]
      })

      // Refresh data after action
      refetchBalance()
    } catch (error) {
      console.error('Mint failed:', error)
    } finally {
      setMintPending(false)
    }
  }, [selectedTokenAddress, exactAmount, address, chain, writeContract, platform.erc20MinterFacade, refetchBalance])

  // Refresh data when dependencies change
  useEffect(() => {
    if (selectedTokenAddress) {
      refetchName()
      refetchSymbol()
      refetchDecimals()
      refetchBalance()
    }
  }, [selectedTokenAddress, refetchName, refetchSymbol, refetchDecimals, refetchBalance])

  if (!isConnected) {
    return (
      <div className="container mx-auto px-4">
        <div className="text-center pt-10 pb-6">
          <h1 className="text-3xl font-bold text-white">Mint Test Tokens</h1>
          <p className="text-gray-300 mt-2">Connect your wallet to mint tokens</p>
        </div>
      </div>
    )
  }

  return (
    <div className="container mx-auto px-4 max-w-2xl">
      <h1 className="text-3xl font-bold text-white text-center py-8">Mint Test Tokens</h1>

      <div className="mb-6 p-4 bg-slate-800/40 rounded-lg text-sm text-gray-300">
        This page is for dev/testnet only. It only supports minting base test ERC20s via the ERC20 Minter Facade (no vault shares, no Standard Exchange vault minting, no DETFs).
      </div>
      
      {/* Token Selection */}
      <div className="mb-6">
        <label className="block text-sm font-medium text-gray-300 mb-2">Select Token</label>
        <select
          value={selectedToken}
          onChange={(e) => setSelectedToken(e.target.value as TokenOption['value'] | '')}
          className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-3"
        >
          <option value="">Select a Token</option>
          {tokenOptions.map(option => (
            <option key={String(option.value)} value={String(option.value)}>{option.label}</option>
          ))}
        </select>
      </div>
      
      {/* Amount Input */}
      <div className="mb-6">
        <label className="block text-sm font-medium text-gray-300 mb-2">Amount to Mint</label>
        <input
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-3"
          placeholder="0.0"
        />
      </div>
      
      {/* Token Info */}
      {selectedTokenAddress && (
        <div className="mb-6 p-4 bg-slate-700/50 rounded-lg">
          <div className="text-sm text-blue-300 font-medium">Token Information</div>
          <div className="text-xs text-gray-400 mt-1">
            <div>Name: {tokenName || 'Loading...'}</div>
            <div>Symbol: {tokenSymbol || 'Loading...'}</div>
            <div>Decimals: {tokenDecimals?.toString() || 'Loading...'}</div>
            <div>Address: {selectedTokenAddress}</div>
            {tokenBalance && (
              <div>Current Balance: {formatUnits(tokenBalance, tokenDecimals || 18)} {tokenSymbol}</div>
            )}
          </div>
        </div>
      )}
      
      {/* Actions */}
      <button
        onClick={handleMint}
        disabled={!selectedTokenAddress || !exactAmount}
        className="w-full py-3 px-4 bg-blue-600 text-white rounded-md disabled:opacity-50"
      >
        {mintPending ? 'Minting...' : 'Mint Tokens'}
      </button>
    </div>
  )
}
