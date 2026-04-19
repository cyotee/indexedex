'use client'

import { useEffect, useMemo, useState } from 'react'
import { useAccount } from 'wagmi'
import { useReadContract, useSimulateContract, useWriteContract } from 'wagmi'
import { erc20Abi, formatUnits, parseUnits, zeroAddress } from 'viem'

import {
  buildTokenOptionsForChain,
  getTokenDecimalsByAddressForChain,
  resolveTokenAddressFromOptionForChain,
  type Address,
  type TokenOption,
  getSeigniorageDetfsForChain,
} from '../lib/tokenlists'
import { resolveAppChain } from '../lib/runtimeChains'
import { useSelectedNetwork } from '../lib/networkSelection'

const seigniorageDetfAbi = [
  {
    type: 'function',
    name: 'seigniorageToken',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
  },
  {
    type: 'function',
    name: 'seigniorageNFTVault',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
  },
  {
    type: 'function',
    name: 'reserveVaultRateTarget',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
  },
  {
    type: 'function',
    name: 'reservePool',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
  },
  // Standard exchange surface
  {
    type: 'function',
    name: 'previewExchangeIn',
    stateMutability: 'view',
    inputs: [
      { name: 'tokenIn', type: 'address' },
      { name: 'amountIn', type: 'uint256' },
      { name: 'tokenOut', type: 'address' },
    ],
    outputs: [{ name: 'amountOut', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'exchangeIn',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenIn', type: 'address' },
      { name: 'amountIn', type: 'uint256' },
      { name: 'tokenOut', type: 'address' },
      { name: 'minAmountOut', type: 'uint256' },
      { name: 'recipient', type: 'address' },
      { name: 'pretransferred', type: 'bool' },
      { name: 'deadline', type: 'uint256' },
    ],
    outputs: [{ name: 'amountOut', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'previewExchangeOut',
    stateMutability: 'view',
    inputs: [
      { name: 'tokenIn', type: 'address' },
      { name: 'tokenOut', type: 'address' },
      { name: 'amountOut', type: 'uint256' },
    ],
    outputs: [{ name: 'amountIn', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'exchangeOut',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenIn', type: 'address' },
      { name: 'maxAmountIn', type: 'uint256' },
      { name: 'tokenOut', type: 'address' },
      { name: 'amountOut', type: 'uint256' },
      { name: 'recipient', type: 'address' },
      { name: 'pretransferred', type: 'bool' },
      { name: 'deadline', type: 'uint256' },
    ],
    outputs: [{ name: 'amountIn', type: 'uint256' }],
  },
  // Underwriting
  {
    type: 'function',
    name: 'previewUnderwrite',
    stateMutability: 'view',
    inputs: [
      { name: 'tokenIn', type: 'address' },
      { name: 'amountIn', type: 'uint256' },
      { name: 'lockDuration', type: 'uint256' },
    ],
    outputs: [
      { name: 'originalShares', type: 'uint256' },
      { name: 'effectiveShares', type: 'uint256' },
      { name: 'bonusMultiplier', type: 'uint256' },
    ],
  },
  {
    type: 'function',
    name: 'underwrite',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenIn', type: 'address' },
      { name: 'amountIn', type: 'uint256' },
      { name: 'lockDuration', type: 'uint256' },
      { name: 'recipient', type: 'address' },
      { name: 'pretransferred', type: 'bool' },
    ],
    outputs: [{ name: 'tokenId', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'previewRedeem',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ name: 'amountOut', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'redeem',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenId', type: 'uint256' },
      { name: 'recipient', type: 'address' },
    ],
    outputs: [{ name: 'amountOut', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'withdrawRewards',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenId', type: 'uint256' },
      { name: 'recipient', type: 'address' },
    ],
    outputs: [{ name: 'rewards', type: 'uint256' }],
  },
] as const

const PERMIT2_ADDRESS = '0x000000000022D473030F116dDEE9F6B43aC78BA3' as const

const permit2Abi = [
  {
    type: 'function',
    name: 'allowance',
    stateMutability: 'view',
    inputs: [
      { name: 'user', type: 'address' },
      { name: 'token', type: 'address' },
      { name: 'spender', type: 'address' },
    ],
    outputs: [
      { name: 'amount', type: 'uint160' },
      { name: 'expiration', type: 'uint48' },
      { name: 'nonce', type: 'uint48' },
    ],
  },
  {
    type: 'function',
    name: 'approve',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'token', type: 'address' },
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint160' },
      { name: 'expiration', type: 'uint48' },
    ],
    outputs: [],
  },
] as const

const seigniorageNftVaultAbi = [
  {
    type: 'function',
    name: 'minimumLockDuration',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'maximumLockDuration',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'pendingRewards',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'unlock',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenId', type: 'uint256' },
      { name: 'recipient', type: 'address' },
    ],
    outputs: [{ name: 'amountOut', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'claimToken',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
  },
] as const

function clampInt(value: string, fallback: number): number {
  const n = Number(value)
  if (!Number.isFinite(n)) return fallback
  return Math.max(0, Math.floor(n))
}

const ZERO_BIGINT = BigInt(0)

export default function DetfPageClient() {
  const { selectedChainId } = useSelectedNetwork()
  const resolvedChainId = selectedChainId || 11155111
  const activeChain = useMemo(() => resolveAppChain(resolvedChainId), [resolvedChainId])
  const { address, isConnected } = useAccount()

  const detfOptions = useMemo(() => {
    const detfs = getSeigniorageDetfsForChain(resolvedChainId)
    return detfs.map((t) => ({ value: t.address, label: t.name || t.symbol }))
  }, [resolvedChainId])

  const [selectedDetf, setSelectedDetf] = useState<Address | ''>('')

  // General token options (for exchange + underwriting inputs)
  const tokenOptions: TokenOption[] = useMemo(
    () => buildTokenOptionsForChain(resolvedChainId, true, true),
    [resolvedChainId]
  )

  /* ---------------------------------------------------------------------- */
  /*                                 Reads                                  */
  /* ---------------------------------------------------------------------- */

  const { data: seigniorageToken } = useReadContract({
    address: selectedDetf ? (selectedDetf as `0x${string}`) : undefined,
    abi: seigniorageDetfAbi,
    functionName: 'seigniorageToken',
    args: [],
    query: { enabled: !!selectedDetf },
  })

  const { data: nftVault } = useReadContract({
    address: selectedDetf ? (selectedDetf as `0x${string}`) : undefined,
    abi: seigniorageDetfAbi,
    functionName: 'seigniorageNFTVault',
    args: [],
    query: { enabled: !!selectedDetf },
  })

  const { data: reservePool } = useReadContract({
    address: selectedDetf ? (selectedDetf as `0x${string}`) : undefined,
    abi: seigniorageDetfAbi,
    functionName: 'reservePool',
    args: [],
    query: { enabled: !!selectedDetf },
  })

  const { data: rateTarget } = useReadContract({
    address: selectedDetf ? (selectedDetf as `0x${string}`) : undefined,
    abi: seigniorageDetfAbi,
    functionName: 'reserveVaultRateTarget',
    args: [],
    query: { enabled: !!selectedDetf },
  })

  const { data: claimToken } = useReadContract({
    address: nftVault ? (nftVault as `0x${string}`) : undefined,
    abi: seigniorageNftVaultAbi,
    functionName: 'claimToken',
    args: [],
    query: { enabled: !!nftVault },
  })

  const { data: claimTokenDecimals } = useReadContract({
    address: claimToken ? (claimToken as `0x${string}`) : undefined,
    abi: erc20Abi,
    functionName: 'decimals',
    args: [],
    query: { enabled: !!claimToken && claimToken !== zeroAddress },
  })

  const { data: rewardTokenDecimals } = useReadContract({
    address: seigniorageToken ? (seigniorageToken as `0x${string}`) : undefined,
    abi: erc20Abi,
    functionName: 'decimals',
    args: [],
    query: { enabled: !!seigniorageToken && seigniorageToken !== zeroAddress },
  })

  const { data: minLock } = useReadContract({
    address: nftVault ? (nftVault as `0x${string}`) : undefined,
    abi: seigniorageNftVaultAbi,
    functionName: 'minimumLockDuration',
    args: [],
    query: { enabled: !!nftVault },
  })

  const { data: maxLock } = useReadContract({
    address: nftVault ? (nftVault as `0x${string}`) : undefined,
    abi: seigniorageNftVaultAbi,
    functionName: 'maximumLockDuration',
    args: [],
    query: { enabled: !!nftVault },
  })

  /* ---------------------------------------------------------------------- */
  /*                             Exchange In/Out                             */
  /* ---------------------------------------------------------------------- */

  const [exMode, setExMode] = useState<'exactIn' | 'exactOut'>('exactIn')
  const [exTokenInOpt, setExTokenInOpt] = useState<TokenOption['value'] | ''>('')
  const [exTokenOutOpt, setExTokenOutOpt] = useState<TokenOption['value'] | ''>('')
  const [exAmount, setExAmount] = useState('')
  const [slippageBps, setSlippageBps] = useState(100) // 1%

  const exTokenIn = useMemo(
    () => (exTokenInOpt ? resolveTokenAddressFromOptionForChain(resolvedChainId, exTokenInOpt) : undefined),
    [resolvedChainId, exTokenInOpt]
  )
  const exTokenOut = useMemo(
    () => (exTokenOutOpt ? resolveTokenAddressFromOptionForChain(resolvedChainId, exTokenOutOpt) : undefined),
    [resolvedChainId, exTokenOutOpt]
  )

  const exTokenInDecimals = useMemo(
    () => getTokenDecimalsByAddressForChain(resolvedChainId, exTokenIn ?? undefined),
    [resolvedChainId, exTokenIn]
  )
  const exTokenOutDecimals = useMemo(
    () => getTokenDecimalsByAddressForChain(resolvedChainId, exTokenOut ?? undefined),
    [resolvedChainId, exTokenOut]
  )

  const exAmountParsed = useMemo(() => {
    if (!exAmount || !exTokenIn || !exTokenOut) return undefined
    const decimals = exMode === 'exactIn' ? exTokenInDecimals : exTokenOutDecimals
    try {
      return parseUnits(exAmount, decimals)
    } catch {
      return undefined
    }
  }, [exAmount, exMode, exTokenIn, exTokenOut, exTokenInDecimals, exTokenOutDecimals])

  const { data: exPreviewIn } = useReadContract({
    address: selectedDetf ? (selectedDetf as `0x${string}`) : undefined,
    abi: seigniorageDetfAbi,
    functionName: 'previewExchangeIn',
    args:
      exTokenIn && exTokenOut && exMode === 'exactIn' && exAmountParsed
        ? [exTokenIn, exAmountParsed, exTokenOut]
        : undefined,
    query: { enabled: !!selectedDetf && !!exTokenIn && !!exTokenOut && exMode === 'exactIn' && !!exAmountParsed },
  })

  const { data: exPreviewOut } = useReadContract({
    address: selectedDetf ? (selectedDetf as `0x${string}`) : undefined,
    abi: seigniorageDetfAbi,
    functionName: 'previewExchangeOut',
    args:
      exTokenIn && exTokenOut && exMode === 'exactOut' && exAmountParsed
        ? [exTokenIn, exTokenOut, exAmountParsed]
        : undefined,
    query: { enabled: !!selectedDetf && !!exTokenIn && !!exTokenOut && exMode === 'exactOut' && !!exAmountParsed },
  })

  const deadline = useMemo(() => BigInt(Math.floor(Date.now() / 1000) + 5 * 60), [])

  const minAmountOut = useMemo(() => {
    if (exMode !== 'exactIn') return BigInt(0)
    if (!exPreviewIn) return BigInt(0)
    const bps = BigInt(Math.max(0, Math.min(10000, slippageBps)))
    const base = BigInt(10000)
    return (exPreviewIn * (base - bps)) / base
  }, [exMode, exPreviewIn, slippageBps])

  const maxAmountIn = useMemo(() => {
    if (exMode !== 'exactOut') return BigInt(0)
    if (!exPreviewOut) return BigInt(0)
    const bps = BigInt(Math.max(0, Math.min(10000, slippageBps)))
    const base = BigInt(10000)
    return (exPreviewOut * (base + bps)) / base
  }, [exMode, exPreviewOut, slippageBps])

  const exchangeAmountNeeded = useMemo(() => {
    if (exMode === 'exactIn') return exAmountParsed
    return maxAmountIn > ZERO_BIGINT ? maxAmountIn : undefined
  }, [exMode, exAmountParsed, maxAmountIn])

  const permit2Expiration = useMemo(() => Math.floor(Date.now() / 1000) + 3 * 24 * 60 * 60, [])

  const { writeContractAsync, isPending: isWritePending } = useWriteContract()

  const { data: detfAllowance } = useReadContract({
    address: exTokenIn ? (exTokenIn as `0x${string}`) : undefined,
    abi: erc20Abi,
    functionName: 'allowance',
    args: address && selectedDetf && exTokenIn ? [address, selectedDetf as `0x${string}`] : undefined,
    query: { enabled: !!address && !!selectedDetf && !!exTokenIn },
  })

  const { data: permit2TokenAllowance } = useReadContract({
    address: exTokenIn ? (exTokenIn as `0x${string}`) : undefined,
    abi: erc20Abi,
    functionName: 'allowance',
    args: address && exTokenIn ? [address, PERMIT2_ADDRESS] : undefined,
    query: { enabled: !!address && !!exTokenIn },
  })

  const { data: permit2Allowance } = useReadContract({
    address: PERMIT2_ADDRESS,
    abi: permit2Abi,
    functionName: 'allowance',
    args: address && selectedDetf && exTokenIn ? [address, exTokenIn, selectedDetf as `0x${string}`] : undefined,
    query: { enabled: !!address && !!selectedDetf && !!exTokenIn },
  })

  const { data: approveSim } = useSimulateContract({
    address: exTokenIn ? (exTokenIn as `0x${string}`) : undefined,
    abi: erc20Abi,
    functionName: 'approve',
    args:
      selectedDetf && exTokenIn && exchangeAmountNeeded
        ? [selectedDetf as `0x${string}`, exchangeAmountNeeded]
        : undefined,
    query: { enabled: !!selectedDetf && !!exTokenIn && !!exchangeAmountNeeded },
  })

  const { data: permit2TokenApproveSim } = useSimulateContract({
    address: exTokenIn ? (exTokenIn as `0x${string}`) : undefined,
    abi: erc20Abi,
    functionName: 'approve',
    args: exTokenIn && exchangeAmountNeeded ? [PERMIT2_ADDRESS, exchangeAmountNeeded] : undefined,
    query: { enabled: !!exTokenIn && !!exchangeAmountNeeded },
  })

  const { data: permit2ApproveSim } = useSimulateContract({
    address: PERMIT2_ADDRESS,
    abi: permit2Abi,
    functionName: 'approve',
    args:
      selectedDetf && exTokenIn && exchangeAmountNeeded
        ? [exTokenIn, selectedDetf as `0x${string}`, exchangeAmountNeeded, permit2Expiration]
        : undefined,
    query: { enabled: !!selectedDetf && !!exTokenIn && !!exchangeAmountNeeded },
  })

  const hasDetfAllowance = !!exchangeAmountNeeded && (detfAllowance ?? ZERO_BIGINT) >= exchangeAmountNeeded
  const hasPermit2Allowance =
    !!exchangeAmountNeeded &&
    (permit2TokenAllowance ?? ZERO_BIGINT) >= exchangeAmountNeeded &&
    (permit2Allowance?.[0] ?? ZERO_BIGINT) >= exchangeAmountNeeded
  const needsPermit2TokenApproval =
    !!exchangeAmountNeeded && (permit2TokenAllowance ?? ZERO_BIGINT) < exchangeAmountNeeded
  const needsPermit2SpenderApproval =
    !!exchangeAmountNeeded && (permit2Allowance?.[0] ?? ZERO_BIGINT) < exchangeAmountNeeded

  /* ---------------------------------------------------------------------- */
  /*                                  Bonds                                 */
  /* ---------------------------------------------------------------------- */

  const [bondTokenInOpt, setBondTokenInOpt] = useState<TokenOption['value'] | ''>('')
  const [bondAmountIn, setBondAmountIn] = useState('')
  const [bondLockDays, setBondLockDays] = useState('30')
  const [bondTokenId, setBondTokenId] = useState('')

  const bondTokenIn = useMemo(
    () => (bondTokenInOpt ? resolveTokenAddressFromOptionForChain(resolvedChainId, bondTokenInOpt) : undefined),
    [resolvedChainId, bondTokenInOpt]
  )
  const bondTokenInDecimals = useMemo(
    () => getTokenDecimalsByAddressForChain(resolvedChainId, bondTokenIn ?? undefined),
    [resolvedChainId, bondTokenIn]
  )

  const lockSeconds = useMemo(() => BigInt(clampInt(bondLockDays, 30) * 24 * 60 * 60), [bondLockDays])

  const bondAmountParsed = useMemo(() => {
    if (!bondAmountIn || !bondTokenIn) return undefined
    try {
      return parseUnits(bondAmountIn, bondTokenInDecimals)
    } catch {
      return undefined
    }
  }, [bondAmountIn, bondTokenIn, bondTokenInDecimals])

  const { data: bondPreview } = useReadContract({
    address: selectedDetf ? (selectedDetf as `0x${string}`) : undefined,
    abi: seigniorageDetfAbi,
    functionName: 'previewUnderwrite',
    args: bondTokenIn && bondAmountParsed ? [bondTokenIn, bondAmountParsed, lockSeconds] : undefined,
    query: { enabled: !!selectedDetf && !!bondTokenIn && !!bondAmountParsed },
  })

  const tokenIdParsed = useMemo(() => {
    if (!bondTokenId) return undefined
    try {
      return BigInt(bondTokenId)
    } catch {
      return undefined
    }
  }, [bondTokenId])

  const { data: redeemPreview } = useReadContract({
    address: selectedDetf ? (selectedDetf as `0x${string}`) : undefined,
    abi: seigniorageDetfAbi,
    functionName: 'previewRedeem',
    args: tokenIdParsed ? [tokenIdParsed] : undefined,
    query: { enabled: !!selectedDetf && !!tokenIdParsed },
  })

  const { data: pendingRewards } = useReadContract({
    address: nftVault ? (nftVault as `0x${string}`) : undefined,
    abi: seigniorageNftVaultAbi,
    functionName: 'pendingRewards',
    args: tokenIdParsed ? [tokenIdParsed] : undefined,
    query: { enabled: !!nftVault && !!tokenIdParsed },
  })

  useEffect(() => {
    // reset per-selection inputs to reduce accidental interactions
    setExAmount('')
    setBondAmountIn('')
    setBondTokenId('')
  }, [selectedDetf])

  const canWrite = isConnected && !!address && !!selectedDetf
  const canSubmitExchange =
    !!canWrite &&
    !isWritePending &&
    !!exTokenIn &&
    !!exTokenOut &&
    !!exchangeAmountNeeded &&
    (hasDetfAllowance || hasPermit2Allowance)

  return (
    <div className="mx-auto max-w-5xl px-4 py-10">
      <h1 className="text-2xl font-bold text-white">DETFs</h1>
      <p className="mt-1 text-sm text-gray-300">
        Exchange via <code className="text-gray-200">exchangeIn/exchangeOut</code> and manage bond NFTs via{' '}
        <code className="text-gray-200">underwrite/redeem</code>.
      </p>

      <div className="mt-6 rounded-lg border border-gray-700 bg-gray-900 p-4">
        <label className="block text-sm font-medium text-gray-200">Select DETF</label>
        <select
          className="mt-2 w-full rounded bg-gray-800 px-3 py-2 text-white"
          value={selectedDetf}
          onChange={(e) => setSelectedDetf(e.target.value as Address)}
        >
          <option value="">-- select --</option>
          {detfOptions.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label} ({o.value.slice(0, 6)}…{o.value.slice(-4)})
            </option>
          ))}
        </select>
        {detfOptions.length === 0 && (
          <p className="mt-2 text-sm text-yellow-300">
            No DETFs found for this environment and chain. Re-run the DETF deployment stage and frontend export for the
            selected deployment bundle.
          </p>
        )}

        {selectedDetf && (
          <div className="mt-4 grid grid-cols-1 gap-2 text-sm text-gray-200">
            <div>
              <span className="text-gray-400">DETF:</span> {selectedDetf}
            </div>
            <div>
              <span className="text-gray-400">sRBT:</span> {String(seigniorageToken ?? zeroAddress)}
            </div>
            <div>
              <span className="text-gray-400">Bond NFT Vault:</span> {String(nftVault ?? zeroAddress)}
            </div>
            <div>
              <span className="text-gray-400">Claim Token (reserve vault shares):</span> {String(claimToken ?? zeroAddress)}
            </div>
            <div>
              <span className="text-gray-400">Reserve Pool (80/20 BPT):</span> {String(reservePool ?? zeroAddress)}
            </div>
            <div>
              <span className="text-gray-400">Reserve Vault Rate Target:</span> {String(rateTarget ?? zeroAddress)}
            </div>
            <div>
              <span className="text-gray-400">Lock Range (days):</span>{' '}
              {minLock ? Number(minLock) / 86400 : '?'} – {maxLock ? Number(maxLock) / 86400 : '?'}
            </div>
          </div>
        )}
      </div>

      {/* Exchange */}
      <div className="mt-6 rounded-lg border border-gray-700 bg-gray-900 p-4">
        <h2 className="text-lg font-semibold text-white">Exchange</h2>
        <div className="mt-3 flex gap-3">
          <button
            className={`rounded px-3 py-1 text-sm ${exMode === 'exactIn' ? 'bg-green-600 text-white' : 'bg-gray-800 text-gray-200'}`}
            onClick={() => setExMode('exactIn')}
          >
            Exact In
          </button>
          <button
            className={`rounded px-3 py-1 text-sm ${exMode === 'exactOut' ? 'bg-green-600 text-white' : 'bg-gray-800 text-gray-200'}`}
            onClick={() => setExMode('exactOut')}
          >
            Exact Out
          </button>
        </div>

        <div className="mt-4 grid grid-cols-1 gap-4 md:grid-cols-2">
          <div>
            <label className="block text-sm text-gray-200">Token In</label>
            <select
              className="mt-1 w-full rounded bg-gray-800 px-3 py-2 text-white"
              value={exTokenInOpt as any}
              onChange={(e) => setExTokenInOpt(e.target.value as any)}
            >
              <option value="">-- select --</option>
              {tokenOptions.map((o) => (
                <option key={String(o.value)} value={String(o.value)}>
                  {o.label}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-sm text-gray-200">Token Out</label>
            <select
              className="mt-1 w-full rounded bg-gray-800 px-3 py-2 text-white"
              value={exTokenOutOpt as any}
              onChange={(e) => setExTokenOutOpt(e.target.value as any)}
            >
              <option value="">-- select --</option>
              {tokenOptions.map((o) => (
                <option key={String(o.value)} value={String(o.value)}>
                  {o.label}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-sm text-gray-200">Amount ({exMode === 'exactIn' ? 'In' : 'Out'})</label>
            <input
              className="mt-1 w-full rounded bg-gray-800 px-3 py-2 text-white"
              value={exAmount}
              onChange={(e) => setExAmount(e.target.value)}
              placeholder="0.0"
            />
          </div>
          <div>
            <label className="block text-sm text-gray-200">Slippage (bps)</label>
            <input
              className="mt-1 w-full rounded bg-gray-800 px-3 py-2 text-white"
              value={slippageBps}
              onChange={(e) => setSlippageBps(clampInt(e.target.value, 100))}
            />
            <p className="mt-1 text-xs text-gray-400">100 bps = 1%</p>
          </div>
        </div>

        <div className="mt-4 text-sm text-gray-200">
          {exMode === 'exactIn' && exPreviewIn !== undefined && exTokenOut && (
            <div>
              Preview out: <span className="text-white">{formatUnits(exPreviewIn, exTokenOutDecimals)}</span>
            </div>
          )}
          {exMode === 'exactOut' && exPreviewOut !== undefined && exTokenIn && (
            <div>
              Preview in: <span className="text-white">{formatUnits(exPreviewOut, exTokenInDecimals)}</span>
              <div className="mt-1 text-xs text-gray-400">
                Preview is conservative for exact-out: actual input used may be lower.
              </div>
            </div>
          )}
        </div>

        <div className="mt-4 flex flex-wrap gap-3">
          <button
            className="rounded bg-gray-700 px-4 py-2 text-white disabled:opacity-50"
            disabled={!canWrite || !approveSim?.request}
            onClick={async () => {
              if (!approveSim?.request) return
              if (!address) return
              await writeContractAsync({
                ...approveSim.request,
                chain: activeChain,
                account: address,
              })
            }}
          >
            Approve DETF Directly
          </button>

          <button
            className="rounded bg-gray-700 px-4 py-2 text-white disabled:opacity-50"
            disabled={!canWrite || !permit2TokenApproveSim?.request}
            onClick={async () => {
              if (!permit2TokenApproveSim?.request) return
              if (!address) return
              await writeContractAsync({
                ...permit2TokenApproveSim.request,
                chain: activeChain,
                account: address,
              })
            }}
          >
            Approve Permit2 Token
          </button>

          <button
            className="rounded bg-gray-700 px-4 py-2 text-white disabled:opacity-50"
            disabled={!canWrite || !permit2ApproveSim?.request}
            onClick={async () => {
              if (!permit2ApproveSim?.request) return
              if (!address) return
              await writeContractAsync({
                ...permit2ApproveSim.request,
                chain: activeChain,
                account: address,
              })
            }}
          >
            Approve DETF Via Permit2
          </button>

          <button
            className="rounded bg-green-600 px-4 py-2 text-white disabled:opacity-50"
            disabled={
              !canSubmitExchange ||
              !exTokenIn ||
              !exTokenOut ||
              exTokenIn === null ||
              exTokenOut === null
            }
            onClick={async () => {
              if (!selectedDetf || !address || !exTokenIn || !exTokenOut || !exchangeAmountNeeded) return
              if (exTokenIn === null || exTokenOut === null) return
              if (!hasDetfAllowance && !hasPermit2Allowance) return
              if (exMode === 'exactIn') {
                await writeContractAsync({
                  address: selectedDetf as `0x${string}`,
                  abi: seigniorageDetfAbi,
                  functionName: 'exchangeIn',
                  args: [exTokenIn, exchangeAmountNeeded, exTokenOut, minAmountOut, address, false, deadline],
                  chain: activeChain,
                  account: address,
                })
              } else {
                if (!exAmountParsed) return
                await writeContractAsync({
                  address: selectedDetf as `0x${string}`,
                  abi: seigniorageDetfAbi,
                  functionName: 'exchangeOut',
                  args: [exTokenIn, maxAmountIn, exTokenOut, exAmountParsed, address, false, deadline],
                  chain: activeChain,
                  account: address,
                })
              }
            }}
          >
            Submit Exchange
          </button>
        </div>

        {exTokenIn && exTokenOut && exchangeAmountNeeded && (
          <div className="mt-3 rounded border border-gray-700 bg-gray-800/50 p-3 text-sm text-gray-300">
            <div>
              Direct DETF allowance:{' '}
              <span className={hasDetfAllowance ? 'text-green-300' : 'text-yellow-300'}>
                {hasDetfAllowance ? 'ready' : 'approval needed'}
              </span>
            </div>
            <div>
              Permit2 token approval:{' '}
              <span className={!needsPermit2TokenApproval ? 'text-green-300' : 'text-yellow-300'}>
                {!needsPermit2TokenApproval ? 'ready' : 'approval needed'}
              </span>
            </div>
            <div>
              Permit2 DETF allowance:{' '}
              <span className={!needsPermit2SpenderApproval ? 'text-green-300' : 'text-yellow-300'}>
                {!needsPermit2SpenderApproval ? 'ready' : 'approval needed'}
              </span>
            </div>
            {!hasDetfAllowance && !hasPermit2Allowance && (
              <p className="mt-2 text-yellow-300">
                This DETF will revert with <code className="text-gray-200">TransferFromFailed()</code> until you either
                approve the DETF directly or complete both Permit2 approval steps.
              </p>
            )}
          </div>
        )}
      </div>

      {/* Bonds */}
      <div className="mt-6 rounded-lg border border-gray-700 bg-gray-900 p-4">
        <h2 className="text-lg font-semibold text-white">Bond NFT</h2>

        <div className="mt-4 grid grid-cols-1 gap-4 md:grid-cols-2">
          <div>
            <label className="block text-sm text-gray-200">Token In</label>
            <select
              className="mt-1 w-full rounded bg-gray-800 px-3 py-2 text-white"
              value={bondTokenInOpt as any}
              onChange={(e) => setBondTokenInOpt(e.target.value as any)}
            >
              <option value="">-- select --</option>
              {tokenOptions.map((o) => (
                <option key={String(o.value)} value={String(o.value)}>
                  {o.label}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-sm text-gray-200">Amount In</label>
            <input
              className="mt-1 w-full rounded bg-gray-800 px-3 py-2 text-white"
              value={bondAmountIn}
              onChange={(e) => setBondAmountIn(e.target.value)}
              placeholder="0.0"
            />
          </div>
          <div>
            <label className="block text-sm text-gray-200">Lock Duration (days)</label>
            <input
              className="mt-1 w-full rounded bg-gray-800 px-3 py-2 text-white"
              value={bondLockDays}
              onChange={(e) => setBondLockDays(e.target.value)}
            />
          </div>
          <div className="text-sm text-gray-200">
            <div className="mt-6">
              Preview:
              {bondPreview ? (
                <ul className="mt-2 space-y-1 text-gray-300">
                  <li>originalShares: {formatUnits(bondPreview[0], 18)}</li>
                  <li>effectiveShares: {formatUnits(bondPreview[1], 18)}</li>
                  <li>bonusMultiplier: {formatUnits(bondPreview[2], 18)}x</li>
                </ul>
              ) : (
                <div className="mt-2 text-gray-400">(fill token + amount)</div>
              )}
            </div>
          </div>
        </div>

        <div className="mt-4 flex flex-wrap gap-3">
          <button
            className="rounded bg-gray-700 px-4 py-2 text-white disabled:opacity-50"
            disabled={!canWrite || !selectedDetf || !bondTokenIn || !bondAmountParsed}
            onClick={async () => {
              if (!selectedDetf || !bondTokenIn || !bondAmountParsed) return
              if (!address) return
              await writeContractAsync({
                address: bondTokenIn as `0x${string}`,
                abi: erc20Abi,
                functionName: 'approve',
                args: [selectedDetf as `0x${string}`, bondAmountParsed],
                chain: activeChain,
                account: address,
              })
            }}
          >
            Approve Bond Token
          </button>

          <button
            className="rounded bg-green-600 px-4 py-2 text-white disabled:opacity-50"
            disabled={!canWrite || !bondTokenIn || !bondAmountParsed || !address}
            onClick={async () => {
              if (!selectedDetf || !bondTokenIn || !bondAmountParsed || !address) return
              await writeContractAsync({
                address: selectedDetf as `0x${string}`,
                abi: seigniorageDetfAbi,
                functionName: 'underwrite',
                args: [bondTokenIn, bondAmountParsed, lockSeconds, address, false],
                chain: activeChain,
                account: address,
              })
            }}
          >
            Buy Bond NFT (Underwrite)
          </button>
        </div>

        <div className="mt-6 grid grid-cols-1 gap-4 md:grid-cols-2">
          <div>
            <label className="block text-sm text-gray-200">Token ID</label>
            <input
              className="mt-1 w-full rounded bg-gray-800 px-3 py-2 text-white"
              value={bondTokenId}
              onChange={(e) => setBondTokenId(e.target.value)}
              placeholder="e.g. 1"
            />
            {redeemPreview !== undefined && (
              <p className="mt-2 text-sm text-gray-300">
                previewRedeem: {formatUnits(redeemPreview, Number(claimTokenDecimals ?? 18))}
              </p>
            )}
            {pendingRewards !== undefined && (
              <p className="mt-1 text-sm text-gray-300">
                pendingRewards: {formatUnits(pendingRewards, Number(rewardTokenDecimals ?? 18))}
              </p>
            )}
          </div>
          <div className="flex flex-wrap items-end gap-3">
            <button
              className="rounded bg-green-600 px-4 py-2 text-white disabled:opacity-50"
              disabled={!canWrite || !tokenIdParsed || !address}
              onClick={async () => {
                if (!selectedDetf || !tokenIdParsed || !address) return
                await writeContractAsync({
                  address: selectedDetf as `0x${string}`,
                  abi: seigniorageDetfAbi,
                  functionName: 'redeem',
                  args: [tokenIdParsed, address],
                  chain: activeChain,
                  account: address,
                })
              }}
            >
              Redeem (DETF)
            </button>

            <button
              className="rounded bg-gray-700 px-4 py-2 text-white disabled:opacity-50"
              disabled={!canWrite || !tokenIdParsed || !address || !nftVault}
              onClick={async () => {
                if (!nftVault || !tokenIdParsed || !address) return
                await writeContractAsync({
                  address: nftVault as `0x${string}`,
                  abi: seigniorageNftVaultAbi,
                  functionName: 'unlock',
                  args: [tokenIdParsed, address],
                  chain: activeChain,
                  account: address,
                })
              }}
            >
              Unlock (NFT Vault)
            </button>

            <button
              className="rounded bg-gray-700 px-4 py-2 text-white disabled:opacity-50"
              disabled={!canWrite || !tokenIdParsed || !address}
              onClick={async () => {
                if (!selectedDetf || !tokenIdParsed || !address) return
                await writeContractAsync({
                  address: selectedDetf as `0x${string}`,
                  abi: seigniorageDetfAbi,
                  functionName: 'withdrawRewards',
                  args: [tokenIdParsed, address],
                  chain: activeChain,
                  account: address,
                })
              }}
            >
              Withdraw Rewards
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
