'use client'

import { useEffect, useMemo, useState } from 'react'
import { formatUnits, hashTypedData, keccak256, parseUnits, recoverAddress, zeroAddress } from 'viem'
import type { PublicClient } from 'viem'
import { useReadContract, useSignTypedData } from 'wagmi'

import ApprovalSettingsPanel from '../../components/ApprovalSettingsPanel'
import SlippageInput from '../../components/SlippageInput'
import { balancerV3StandardExchangeRouterExactInSwapFacetAbi } from '../../generated'
import { useApprovalFlow, type WriteContractAsync as WriteContractAsyncType } from '../../lib/hooks/useApprovalFlow'
import { usePermit2Nonce } from '../../lib/hooks/usePermit2Nonce'
import { buildPermit2WitnessDigest, buildPermitIntentKey, createWitnessFromSwapParams, getPermit2TypedData } from '@indexedex/protocol/permit2-signature'
import { protocolDetfAbi } from '@indexedex/protocol/protocolDetfAbi'
import { swapExactInAbi } from '@indexedex/protocol/swapAbis'

type StoredPermitSignature = {
  signature: `0x${string}`
  deadline: bigint
  nonce: bigint
  isExactIn: boolean
  intentKey: string
}

interface BurnChirSectionProps {
  detfAddress: `0x${string}` | undefined
  /** DETF share symbol (primary label). */
  detfSymbol?: string
  /** Rate asset symbol when known (often WETH). */
  rateAssetSymbol?: string
  effectiveWethToken: `0x${string}` | undefined
  dataChainId: number
  isConnected: boolean
  walletMatchesDataChain: boolean
  burningAllowedNow: boolean | undefined
  routerAddress: `0x${string}` | null
  routerHasBytecode: boolean | null
  permit2Address: `0x${string}` | undefined
  address: `0x${string}` | undefined
  publicClient: PublicClient | undefined
  targetChain: any
  writeContractAsync: any
  setStatus: (status: string) => void
  waitForReceiptAndRefresh: (hash: `0x${string}`, label: string) => Promise<void>
  chirBalance: bigint | undefined
  wethDecimals: number
}

function computeMinAmountOut(amountOut: bigint | undefined, slippage: number) {
  if (!amountOut) return BigInt(0)
  const slippageBps = BigInt(Math.floor(slippage * 100))
  return (amountOut * (BigInt(10000) - slippageBps)) / BigInt(10000)
}

export default function BurnChirSection({
  detfAddress,
  detfSymbol = 'DETF',
  rateAssetSymbol = 'WETH',
  effectiveWethToken,
  dataChainId,
  isConnected,
  walletMatchesDataChain,
  burningAllowedNow,
  routerAddress,
  routerHasBytecode,
  permit2Address,
  address,
  publicClient,
  targetChain,
  writeContractAsync,
  setStatus,
  waitForReceiptAndRefresh,
  chirBalance,
  wethDecimals,
}: BurnChirSectionProps) {
  const { signTypedDataAsync } = useSignTypedData()
  const [burnChirAmount, setBurnChirAmount] = useState('')
  const [approvalMode, setApprovalMode] = useState<'explicit' | 'signed'>('explicit')
  const [showApprovalSettings, setShowApprovalSettings] = useState(false)
  const [permit2SpendingLimit, setPermit2SpendingLimit] = useState('')
  const [burnSlippage, setBurnSlippage] = useState(0.5)
  const [unwrapWethAfterBurn, setUnwrapWethAfterBurn] = useState(false)
  const [accurateQuoteLoading, setAccurateQuoteLoading] = useState(false)
  const [accurateQuoteError, setAccurateQuoteError] = useState<string | null>(null)
  const [accurateQuote, setAccurateQuote] = useState<bigint | null>(null)
  const [storedPermitSignature, setStoredPermitSignature] = useState<StoredPermitSignature | null>(null)

  const parsedBurnChir = useMemo(() => {
    if (!burnChirAmount) return undefined
    try {
      return parseUnits(burnChirAmount, 18)
    } catch {
      return undefined
    }
  }, [burnChirAmount])

  const shouldPreviewBurn = !!detfAddress && !!effectiveWethToken && burningAllowedNow !== false && parsedBurnChir !== undefined && parsedBurnChir > BigInt(0)

  const { data: previewBurnOut, error: previewBurnOutError, refetch: refetchPreviewBurnOut } = useReadContract({
    chainId: dataChainId,
    address: detfAddress,
    abi: protocolDetfAbi,
    functionName: 'previewExchangeIn',
    args: [detfAddress ?? zeroAddress, parsedBurnChir ?? BigInt(0), effectiveWethToken ?? zeroAddress],
    query: { enabled: shouldPreviewBurn },
  })

  const writeContractAsyncWrapper: WriteContractAsyncType = async (params) => {
    const tx = await writeContractAsync({
      chain: targetChain,
      account: address,
      address: params.address,
      abi: params.abi,
      functionName: params.functionName,
      args: params.args,
      value: params.value,
    })
    return tx as `0x${string}`
  }

  const { approvalState, approvalError, handleApproval, handleIssuePermit2Approval, handleIssueRouterApproval, refetchAllowance, refetchPermit2Allowance } = useApprovalFlow({
    tokenAddress: detfAddress,
    permit2Address,
    routerAddress: routerAddress ?? undefined,
    publicClient: publicClient ?? null,
    address: address ?? null,
    writeContractAsync: writeContractAsyncWrapper,
    effectiveApprovalMode: approvalMode,
    resolvedChainId: dataChainId,
    routerHasBytecode,
    effectiveAmount: parsedBurnChir,
  })

  const { refetchNonce, nextUnusedNonce } = usePermit2Nonce({ permit2Address, owner: address })

  const activePermitIntentKey = useMemo(() => {
    if (approvalMode !== 'signed' || !address || !routerAddress || !detfAddress || !effectiveWethToken || !parsedBurnChir) {
      return null
    }

    return buildPermitIntentKey({
      chainId: dataChainId,
      owner: address,
      spender: routerAddress,
      pool: detfAddress,
      tokenIn: detfAddress,
      tokenInVault: zeroAddress,
      tokenOut: effectiveWethToken,
      tokenOutVault: zeroAddress,
      amountGiven: parsedBurnChir,
      limit: computeMinAmountOut(previewBurnOut as bigint | undefined, burnSlippage),
      wethIsEth: unwrapWethAfterBurn,
      userDataHash: keccak256('0x'),
      isExactIn: true,
    })
  }, [approvalMode, address, routerAddress, detfAddress, effectiveWethToken, parsedBurnChir, dataChainId, previewBurnOut, burnSlippage, unwrapWethAfterBurn])

  useEffect(() => {
    if (!storedPermitSignature) return
    if (!activePermitIntentKey || storedPermitSignature.intentKey !== activePermitIntentKey) {
      setStoredPermitSignature(null)
      setAccurateQuote(null)
      setAccurateQuoteError(null)
    }
  }, [storedPermitSignature, activePermitIntentKey])

  const clearSignedState = () => {
    setStoredPermitSignature(null)
    setAccurateQuote(null)
    setAccurateQuoteError(null)
  }

  async function handleBurn() {
    if (!detfAddress || !parsedBurnChir || !address || !effectiveWethToken || !routerAddress) return
    if (!walletMatchesDataChain) {
      setStatus(`Switch wallet network to chainId ${dataChainId} to burn.`)
      return
    }

    setStatus('Ensuring approvals…')
    try {
      await handleApproval()
      await Promise.all([refetchAllowance(), refetchPermit2Allowance()])
    } catch (error) {
      setStatus(error instanceof Error ? error.message : String(error))
      return
    }

    const minAmountOut = computeMinAmountOut(previewBurnOut as bigint | undefined, burnSlippage)
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 5 * 60)
    const swapParams = {
      sender: address,
      kind: 0,
      pool: detfAddress,
      tokenIn: detfAddress,
      tokenInVault: zeroAddress,
      tokenOut: effectiveWethToken,
      tokenOutVault: detfAddress,
      amountGiven: parsedBurnChir,
      limit: minAmountOut,
      deadline,
      wethIsEth: unwrapWethAfterBurn,
      userData: '0x' as `0x${string}`,
    } as const
    const swapArgs = [
      swapParams.pool,
      swapParams.tokenIn,
      swapParams.tokenInVault,
      swapParams.tokenOut,
      swapParams.tokenOutVault,
      swapParams.amountGiven,
      swapParams.limit,
      swapParams.deadline,
      swapParams.wethIsEth,
      swapParams.userData,
    ] as const

    setStatus(unwrapWethAfterBurn ? 'Submitting burn via router with WETH unwrapping…' : 'Submitting burn via router (explicit)…')
    try {
      const hash = await writeContractAsync({
        chain: targetChain,
        account: address,
        address: routerAddress,
        abi: swapExactInAbi,
        functionName: 'swapSingleTokenExactIn',
        args: swapArgs,
      })
      await waitForReceiptAndRefresh(hash as `0x${string}`, 'Burn DTF-DETF')
      clearSignedState()
      await refetchPreviewBurnOut()
    } catch (error) {
      setStatus(error instanceof Error ? error.message : String(error))
    }
  }

  async function handleGetAccurateQuote() {
    if (approvalMode !== 'signed' || !detfAddress || !parsedBurnChir || !address || !effectiveWethToken || !routerAddress || !publicClient || !permit2Address) return

    setAccurateQuoteLoading(true)
    setAccurateQuoteError(null)
    setAccurateQuote(null)

    try {
      const refreshedNonceBitmap = await refetchNonce()
      const nonce = refreshedNonceBitmap !== undefined
        ? (() => {
            const inverted = ~refreshedNonceBitmap & ((BigInt(1) << BigInt(256)) - BigInt(1))
            for (let index = 0; index < 256; index += 1) {
              if (((inverted >> BigInt(index)) & BigInt(1)) === BigInt(1)) return BigInt(index)
            }
            return undefined
          })()
        : nextUnusedNonce

      if (nonce === undefined || nonce === null) throw new Error('Failed to fetch Permit2 nonce')

      const permitDeadline = BigInt(Math.floor(Date.now() / 1000) + 5 * 60)
      const amountGiven = parsedBurnChir
      const limit = computeMinAmountOut(previewBurnOut as bigint | undefined, burnSlippage)
      const userDataHash = keccak256('0x')
      const witness = createWitnessFromSwapParams(address, detfAddress, detfAddress, zeroAddress, effectiveWethToken, zeroAddress, amountGiven, limit, permitDeadline, unwrapWethAfterBurn, userDataHash)
      const permitChainId = await publicClient.getChainId()
      const typedData = getPermit2TypedData(permitChainId, permit2Address, {
        token: detfAddress,
        amount: amountGiven,
        nonce,
        deadline: permitDeadline,
        owner: address,
        spender: routerAddress,
        witness,
      })

      const signature = await signTypedDataAsync({ ...typedData, account: address })
      const typedDigest = hashTypedData(typedData)
      const permitDigest = buildPermit2WitnessDigest({ chainId: permitChainId, permit2Address, token: detfAddress, amount: amountGiven, nonce, deadline: permitDeadline, spender: routerAddress, witness })
      const recoveredTypedSigner = await recoverAddress({ hash: typedDigest, signature })
      const recoveredPermitSigner = await recoverAddress({ hash: permitDigest, signature })
      if (recoveredTypedSigner.toLowerCase() !== address.toLowerCase() || recoveredPermitSigner.toLowerCase() !== address.toLowerCase()) {
        throw new Error('Permit signature signer mismatch. Refresh the quote and sign again.')
      }

      const swapParams = {
        sender: address,
        kind: 0,
        pool: detfAddress,
        tokenIn: detfAddress,
        tokenInVault: zeroAddress,
        tokenOut: effectiveWethToken,
        tokenOutVault: detfAddress,
        amountGiven,
        limit,
        deadline: permitDeadline,
        wethIsEth: unwrapWethAfterBurn,
        userData: '0x' as `0x${string}`,
      } as const
      const permit = {
        permitted: { token: detfAddress, amount: amountGiven },
        nonce,
        deadline: permitDeadline,
      } as const

      const simulation = await publicClient.simulateContract({
        address: routerAddress,
        abi: balancerV3StandardExchangeRouterExactInSwapFacetAbi as any,
        functionName: 'swapSingleTokenExactInWithPermit',
        args: [swapParams, permit, signature as `0x${string}`],
        account: address,
      })

      setStoredPermitSignature({ signature: signature as `0x${string}`, deadline: permitDeadline, nonce, isExactIn: true, intentKey: activePermitIntentKey ?? '' })
      setAccurateQuote(simulation.result as bigint)
      setStatus('Accurate quote obtained')
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error)
      setAccurateQuoteError(message)
      setStatus(message)
    } finally {
      setAccurateQuoteLoading(false)
    }
  }

  async function handleBurnSigned() {
    if (!storedPermitSignature || !activePermitIntentKey) {
      setStatus('No current permit signature. Click Get Accurate Quote first.')
      return
    }
    if (storedPermitSignature.intentKey !== activePermitIntentKey || storedPermitSignature.deadline <= BigInt(Math.floor(Date.now() / 1000))) {
      clearSignedState()
      setStatus('Stored permit is stale or expired. Click Get Accurate Quote again.')
      return
    }
    if (!detfAddress || !parsedBurnChir || !address || !effectiveWethToken || !routerAddress) return

    const minAmountOut = computeMinAmountOut(previewBurnOut as bigint | undefined, burnSlippage)
    const swapParams = {
      sender: address,
      kind: 0,
      pool: detfAddress,
      tokenIn: detfAddress,
      tokenInVault: zeroAddress,
      tokenOut: effectiveWethToken,
      tokenOutVault: detfAddress,
      amountGiven: parsedBurnChir,
      limit: minAmountOut,
      deadline: storedPermitSignature.deadline,
      wethIsEth: unwrapWethAfterBurn,
      userData: '0x' as `0x${string}`,
    } as const
    const permit = {
      permitted: { token: detfAddress, amount: parsedBurnChir },
      nonce: storedPermitSignature.nonce,
      deadline: storedPermitSignature.deadline,
    } as const

    setStatus(unwrapWethAfterBurn ? 'Submitting burn via router with ETH output…' : 'Submitting burn via router (signed)…')
    try {
      const hash = await writeContractAsync({
        chain: targetChain,
        account: address,
        address: routerAddress,
        abi: balancerV3StandardExchangeRouterExactInSwapFacetAbi as any,
        functionName: 'swapSingleTokenExactInWithPermit',
        args: [swapParams, permit, storedPermitSignature.signature],
      })
      await waitForReceiptAndRefresh(hash as `0x${string}`, 'Burn DTF-DETF')
      clearSignedState()
      await refetchPreviewBurnOut()
    } catch (error) {
      setStatus(error instanceof Error ? error.message : String(error))
    }
  }

  const inputClass =
    'mt-1 w-full rounded-md border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm text-[var(--text-primary,#EDEDED)]'
  const btnPrimary =
    'w-full rounded-lg bg-[var(--accent,#4FD44B)] px-3 py-2 text-sm font-semibold text-black hover:brightness-110 disabled:opacity-50'
  const btnSecondary =
    'w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm font-medium text-[var(--text-primary,#EDEDED)] hover:border-[var(--border-accent,rgba(79,212,75,0.45))] disabled:opacity-50'
  const outSymbol = unwrapWethAfterBurn ? 'ETH' : rateAssetSymbol

  return (
    <div className="rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] p-4">
      <div className="text-sm font-medium text-[var(--text-primary,#EDEDED)]">
        Burn {detfSymbol} for {outSymbol}
      </div>
      <p className="mt-0.5 text-xs text-[var(--text-muted,#9aa3b2)]">
        Receive {outSymbol}
        {!unwrapWethAfterBurn ? ' · rate asset' : ''}
      </p>
      <div className="mt-2 rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] p-2">
        <div className="text-xs font-medium uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">
          You receive (preview)
        </div>
        <div className="font-mono text-lg font-semibold tabular-nums text-[var(--text-primary,#EDEDED)]">
          {previewBurnOut !== undefined
            ? formatUnits(previewBurnOut as bigint, wethDecimals)
            : '—'}
        </div>
        <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
          Min:{' '}
          {previewBurnOut
            ? formatUnits(computeMinAmountOut(previewBurnOut as bigint, burnSlippage), wethDecimals)
            : '—'}{' '}
          {outSymbol}
        </div>
      </div>
      <label className="mt-3 block text-xs text-[var(--text-muted,#9aa3b2)]">
        {detfSymbol} amount
      </label>
      <input
        value={burnChirAmount}
        onChange={(event) => setBurnChirAmount(event.target.value)}
        className={inputClass}
        placeholder="100"
      />
      {chirBalance !== undefined ? (
        <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
          Balance: {formatUnits(chirBalance, 18)} {detfSymbol}
        </div>
      ) : null}
      <label className="mt-2 flex items-center gap-2 text-xs text-[var(--text-muted,#9aa3b2)]">
        <input
          type="checkbox"
          checked={unwrapWethAfterBurn}
          onChange={(event) => {
            setUnwrapWethAfterBurn(event.target.checked)
            clearSignedState()
          }}
          className="rounded border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)]"
        />
        Unwrap WETH to ETH in the router after burning
      </label>
      <label className="mt-2 block text-xs text-[var(--text-muted,#9aa3b2)]">
        Preview {outSymbol} out
      </label>
      <input
        value={
          burningAllowedNow === false
            ? 'Unavailable'
            : !burnChirAmount.trim() || parsedBurnChir === undefined || parsedBurnChir === BigInt(0)
              ? '0'
              : previewBurnOut !== undefined
                ? formatUnits(previewBurnOut as bigint, wethDecimals)
                : ''
        }
        readOnly
        className={`${inputClass} text-[var(--text-muted,#9aa3b2)]`}
      />
      {burningAllowedNow === false ? (
        <div className="mt-1 text-xs text-amber-300">
          Burn preview is unavailable unless burning is currently enabled.
        </div>
      ) : previewBurnOutError ? (
        <div className="mt-1 text-xs text-amber-300">
          Burn preview read reverted on the current pool state.
        </div>
      ) : null}
      <ApprovalSettingsPanel
        className="mt-3"
        approvalMode={approvalMode}
        onModeChange={(mode) => {
          setApprovalMode(mode)
          clearSignedState()
        }}
        showSettings={showApprovalSettings}
        onToggleSettings={() => setShowApprovalSettings((current) => !current)}
        permit2SpendingLimit={permit2SpendingLimit}
        onSpendingLimitChange={setPermit2SpendingLimit}
        onIssuePermit2Approval={handleIssuePermit2Approval}
        onIssueRouterApproval={handleIssueRouterApproval}
        onEnsureApprovals={handleApproval}
        disableActions={!isConnected || !walletMatchesDataChain || !detfAddress || !routerAddress}
        explicitDescription={`Two-step: approve ${detfSymbol} → Permit2, then Permit2 → Router for burn execution.`}
        signedDescription="EIP-712 signature per burn. Useful when you want a stricter signed path with no router allowance step."
      />
      <SlippageInput className="mt-3" value={burnSlippage} onChange={setBurnSlippage} />
      {approvalError ? (
        <div className="mt-2 text-xs text-amber-300">Approval error: {approvalError}</div>
      ) : null}
      {approvalState === 'approving' ? (
        <div className="mt-2 text-xs text-[var(--text-muted,#9aa3b2)]">Approvals pending…</div>
      ) : null}
      {accurateQuote !== null ? (
        <div className="mt-2 text-xs text-[var(--accent,#4FD44B)]">
          Accurate signed quote: {formatUnits(accurateQuote, wethDecimals)} {outSymbol}
        </div>
      ) : null}
      {accurateQuoteError ? (
        <div className="mt-2 text-xs text-amber-300">{accurateQuoteError}</div>
      ) : null}
      <div className="mt-3 flex flex-col gap-2">
        {approvalMode === 'signed' ? (
          <>
            <button
              type="button"
              onClick={() => void handleGetAccurateQuote()}
              disabled={
                !isConnected ||
                !walletMatchesDataChain ||
                !parsedBurnChir ||
                !detfAddress ||
                !routerAddress ||
                accurateQuoteLoading
              }
              className={btnSecondary}
            >
              {accurateQuoteLoading ? 'Signing Quote…' : 'Get Accurate Quote (Signed)'}
            </button>
            <button
              type="button"
              onClick={() => void handleBurnSigned()}
              disabled={
                burningAllowedNow === false ||
                !isConnected ||
                !walletMatchesDataChain ||
                !parsedBurnChir ||
                !detfAddress ||
                !routerAddress ||
                !storedPermitSignature ||
                storedPermitSignature.intentKey !== activePermitIntentKey
              }
              className={btnPrimary}
            >
              {unwrapWethAfterBurn ? 'Burn to ETH (Signed)' : 'Burn (Signed)'}
            </button>
          </>
        ) : (
          <button
            type="button"
            onClick={() => void handleBurn()}
            disabled={
              burningAllowedNow === false ||
              !isConnected ||
              !walletMatchesDataChain ||
              !parsedBurnChir ||
              !detfAddress ||
              !routerAddress
            }
            className={btnPrimary}
          >
            {unwrapWethAfterBurn ? 'Burn to ETH (Explicit)' : 'Burn (Explicit)'}
          </button>
        )}
      </div>
    </div>
  )
}