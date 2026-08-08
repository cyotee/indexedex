'use client'

import { useEffect, useMemo, useState } from 'react'
import { erc20Abi, formatUnits, hashTypedData, keccak256, parseUnits, recoverAddress, zeroAddress } from 'viem'
import type { PublicClient } from 'viem'
import { useBalance, useReadContract, useSignTypedData } from 'wagmi'

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

interface MintChirSectionProps {
  detfAddress: `0x${string}` | undefined
  /** DETF share symbol (primary label). */
  detfSymbol?: string
  /** Rate asset symbol when known (often WETH). */
  rateAssetSymbol?: string
  effectiveWethToken: `0x${string}` | undefined
  dataChainId: number
  isConnected: boolean
  walletMatchesDataChain: boolean
  mintingAllowedNow: boolean | undefined
  routerAddress: `0x${string}` | null
  routerHasBytecode: boolean | null
  permit2Address: `0x${string}` | undefined
  address: `0x${string}` | undefined
  publicClient: PublicClient | undefined
  targetChain: any
  writeContractAsync: any
  setStatus: (status: string) => void
  waitForReceiptAndRefresh: (hash: `0x${string}`, label: string) => Promise<void>
  wethDecimals: number
}

function computeMinAmountOut(amountOut: bigint | undefined, slippage: number) {
  if (!amountOut) return BigInt(0)
  const slippageBps = BigInt(Math.floor(slippage * 100))
  return (amountOut * (BigInt(10000) - slippageBps)) / BigInt(10000)
}

export default function MintChirSection({
  detfAddress,
  detfSymbol = 'DETF',
  rateAssetSymbol = 'WETH',
  effectiveWethToken,
  dataChainId,
  isConnected,
  walletMatchesDataChain,
  mintingAllowedNow,
  routerAddress,
  routerHasBytecode,
  permit2Address,
  address,
  publicClient,
  targetChain,
  writeContractAsync,
  setStatus,
  waitForReceiptAndRefresh,
  wethDecimals,
}: MintChirSectionProps) {
  const { signTypedDataAsync } = useSignTypedData()
  const [mintWethAmount, setMintWethAmount] = useState('')
  const [approvalMode, setApprovalMode] = useState<'explicit' | 'signed'>('explicit')
  const [showApprovalSettings, setShowApprovalSettings] = useState(false)
  const [permit2SpendingLimit, setPermit2SpendingLimit] = useState('')
  const [mintSlippage, setMintSlippage] = useState(0.5)
  const [wrapEthBeforeMint, setWrapEthBeforeMint] = useState(false)
  const [accurateQuoteLoading, setAccurateQuoteLoading] = useState(false)
  const [accurateQuoteError, setAccurateQuoteError] = useState<string | null>(null)
  const [accurateQuote, setAccurateQuote] = useState<bigint | null>(null)
  const [storedPermitSignature, setStoredPermitSignature] = useState<StoredPermitSignature | null>(null)

  const parsedMintWeth = useMemo(() => {
    if (!mintWethAmount) return undefined
    try {
      return parseUnits(mintWethAmount, wethDecimals)
    } catch {
      return undefined
    }
  }, [mintWethAmount, wethDecimals])

  useEffect(() => {
    if (wrapEthBeforeMint && approvalMode !== 'explicit') {
      setApprovalMode('explicit')
      setStoredPermitSignature(null)
      setAccurateQuote(null)
      setAccurateQuoteError(null)
    }
  }, [wrapEthBeforeMint, approvalMode])

  const shouldPreviewMint = !!detfAddress && !!effectiveWethToken && mintingAllowedNow !== false && parsedMintWeth !== undefined && parsedMintWeth > BigInt(0)

  const { data: ethBalance } = useBalance({
    chainId: dataChainId,
    address,
    query: {
      enabled: !!address,
    },
  })

  const { data: wethBalance } = useReadContract({
    chainId: dataChainId,
    address: effectiveWethToken,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!effectiveWethToken && !!address,
    },
  })

  const { data: previewMintOut, error: previewMintOutError, refetch: refetchPreviewMintOut } = useReadContract({
    chainId: dataChainId,
    address: detfAddress,
    abi: protocolDetfAbi,
    functionName: 'previewExchangeIn',
    args: [effectiveWethToken ?? zeroAddress, parsedMintWeth ?? BigInt(0), detfAddress ?? zeroAddress],
    query: { enabled: shouldPreviewMint },
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
    tokenAddress: effectiveWethToken,
    permit2Address,
    routerAddress: routerAddress ?? undefined,
    publicClient: publicClient ?? null,
    address: address ?? null,
    writeContractAsync: writeContractAsyncWrapper,
    effectiveApprovalMode: approvalMode,
    resolvedChainId: dataChainId,
    routerHasBytecode,
    effectiveAmount: parsedMintWeth,
  })

  const { refetchNonce, nextUnusedNonce } = usePermit2Nonce({ permit2Address, owner: address })

  const activePermitIntentKey = useMemo(() => {
    if (approvalMode !== 'signed' || !address || !routerAddress || !detfAddress || !effectiveWethToken || !parsedMintWeth) {
      return null
    }

    return buildPermitIntentKey({
      chainId: dataChainId,
      owner: address,
      spender: routerAddress,
      pool: detfAddress,
      tokenIn: effectiveWethToken,
      tokenInVault: zeroAddress,
      tokenOut: detfAddress,
      tokenOutVault: zeroAddress,
      amountGiven: parsedMintWeth,
      limit: computeMinAmountOut(previewMintOut as bigint | undefined, mintSlippage),
      wethIsEth: wrapEthBeforeMint,
      userDataHash: keccak256('0x'),
      isExactIn: true,
    })
  }, [approvalMode, address, routerAddress, detfAddress, effectiveWethToken, parsedMintWeth, dataChainId, previewMintOut, mintSlippage, wrapEthBeforeMint])

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

  async function handleMint() {
    if (!detfAddress || !parsedMintWeth || !address || !effectiveWethToken || !routerAddress) return
    if (!walletMatchesDataChain) {
      setStatus(`Switch wallet network to chainId ${dataChainId} to mint.`)
      return
    }

    if (!wrapEthBeforeMint) {
      setStatus('Ensuring approvals…')
      try {
        await handleApproval()
        await Promise.all([refetchAllowance(), refetchPermit2Allowance()])
      } catch (error) {
        setStatus(error instanceof Error ? error.message : String(error))
        return
      }
    }

    const minAmountOut = computeMinAmountOut(previewMintOut as bigint | undefined, mintSlippage)
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 5 * 60)
    const swapParams = {
      sender: address,
      kind: 0,
      pool: detfAddress,
      tokenIn: effectiveWethToken,
      tokenInVault: detfAddress,
      tokenOut: detfAddress,
      tokenOutVault: zeroAddress,
      amountGiven: parsedMintWeth,
      limit: minAmountOut,
      deadline,
      wethIsEth: wrapEthBeforeMint,
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

    setStatus(wrapEthBeforeMint ? 'Submitting router swap with ETH wrapping…' : 'Submitting router swap (explicit)…')
    try {
      const hash = await writeContractAsync({
        chain: targetChain,
        account: address,
        address: routerAddress,
        abi: swapExactInAbi,
        functionName: 'swapSingleTokenExactIn',
        args: swapArgs,
        value: wrapEthBeforeMint ? parsedMintWeth : undefined,
      })
      await waitForReceiptAndRefresh(hash as `0x${string}`, 'Mint CHIR')
      clearSignedState()
      await refetchPreviewMintOut()
    } catch (error) {
      setStatus(error instanceof Error ? error.message : String(error))
    }
  }

  async function handleGetAccurateQuote() {
    if (wrapEthBeforeMint || approvalMode !== 'signed' || !detfAddress || !parsedMintWeth || !address || !effectiveWethToken || !routerAddress || !publicClient || !permit2Address) return

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
      const amountGiven = parsedMintWeth
      const limit = computeMinAmountOut(previewMintOut as bigint | undefined, mintSlippage)
      const userDataHash = keccak256('0x')
      const witness = createWitnessFromSwapParams(address, detfAddress, effectiveWethToken, zeroAddress, detfAddress, zeroAddress, amountGiven, limit, permitDeadline, false, userDataHash)
      const permitChainId = await publicClient.getChainId()
      const typedData = getPermit2TypedData(permitChainId, permit2Address, {
        token: effectiveWethToken,
        amount: amountGiven,
        nonce,
        deadline: permitDeadline,
        owner: address,
        spender: routerAddress,
        witness,
      })

      const signature = await signTypedDataAsync({ ...typedData, account: address })
      const typedDigest = hashTypedData(typedData)
      const permitDigest = buildPermit2WitnessDigest({ chainId: permitChainId, permit2Address, token: effectiveWethToken, amount: amountGiven, nonce, deadline: permitDeadline, spender: routerAddress, witness })
      const recoveredTypedSigner = await recoverAddress({ hash: typedDigest, signature })
      const recoveredPermitSigner = await recoverAddress({ hash: permitDigest, signature })
      if (recoveredTypedSigner.toLowerCase() !== address.toLowerCase() || recoveredPermitSigner.toLowerCase() !== address.toLowerCase()) {
        throw new Error('Permit signature signer mismatch. Refresh the quote and sign again.')
      }

      const swapParams = {
        sender: address,
        kind: 0,
        pool: detfAddress,
        tokenIn: effectiveWethToken,
        tokenInVault: detfAddress,
        tokenOut: detfAddress,
        tokenOutVault: zeroAddress,
        amountGiven,
        limit,
        deadline: permitDeadline,
        wethIsEth: false,
        userData: '0x' as `0x${string}`,
      } as const
      const permit = {
        permitted: { token: effectiveWethToken, amount: amountGiven },
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

  async function handleMintSigned() {
    if (!storedPermitSignature || !activePermitIntentKey) {
      setStatus('No current permit signature. Click Get Accurate Quote first.')
      return
    }
    if (storedPermitSignature.intentKey !== activePermitIntentKey || storedPermitSignature.deadline <= BigInt(Math.floor(Date.now() / 1000))) {
      clearSignedState()
      setStatus('Stored permit is stale or expired. Click Get Accurate Quote again.')
      return
    }
    if (!detfAddress || !parsedMintWeth || !address || !effectiveWethToken || !routerAddress) return

    const minAmountOut = computeMinAmountOut(previewMintOut as bigint | undefined, mintSlippage)
    const swapParams = {
      sender: address,
      kind: 0,
      pool: detfAddress,
      tokenIn: effectiveWethToken,
      tokenInVault: detfAddress,
      tokenOut: detfAddress,
      tokenOutVault: zeroAddress,
      amountGiven: parsedMintWeth,
      limit: minAmountOut,
      deadline: storedPermitSignature.deadline,
      wethIsEth: false,
      userData: '0x' as `0x${string}`,
    } as const
    const permit = {
      permitted: { token: effectiveWethToken, amount: parsedMintWeth },
      nonce: storedPermitSignature.nonce,
      deadline: storedPermitSignature.deadline,
    } as const

    setStatus('Submitting router swap (signed)…')
    try {
      const hash = await writeContractAsync({
        chain: targetChain,
        account: address,
        address: routerAddress,
        abi: balancerV3StandardExchangeRouterExactInSwapFacetAbi as any,
        functionName: 'swapSingleTokenExactInWithPermit',
        args: [swapParams, permit, storedPermitSignature.signature],
      })
      await waitForReceiptAndRefresh(hash as `0x${string}`, 'Mint CHIR')
      clearSignedState()
      await refetchPreviewMintOut()
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

  return (
    <div className="rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] p-4">
      <div className="text-sm font-medium text-[var(--text-primary,#EDEDED)]">
        Mint {detfSymbol}
      </div>
      <p className="mt-0.5 text-xs text-[var(--text-muted,#9aa3b2)]">
        Pay with {rateAssetSymbol}
        <span className="text-[var(--text-muted,#9aa3b2)]"> · rate asset</span>
      </p>
      <div className="mt-2 rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] p-2">
        <div className="text-xs font-medium uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">
          You receive (preview)
        </div>
        <div className="font-mono text-lg font-semibold tabular-nums text-[var(--text-primary,#EDEDED)]">
          {previewMintOut !== undefined ? formatUnits(previewMintOut as bigint, 18) : '—'}
        </div>
        <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
          Min:{' '}
          {previewMintOut
            ? formatUnits(computeMinAmountOut(previewMintOut as bigint, mintSlippage), 18)
            : '—'}{' '}
          {detfSymbol}
        </div>
      </div>
      <label className="mt-3 flex items-center gap-2 text-xs text-[var(--text-muted,#9aa3b2)]">
        <input
          type="checkbox"
          checked={wrapEthBeforeMint}
          onChange={(event) => {
            setWrapEthBeforeMint(event.target.checked)
            clearSignedState()
          }}
          className="rounded border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)]"
        />
        Wrap ETH to WETH in the router before minting
      </label>
      <label className="mt-2 block text-xs text-[var(--text-muted,#9aa3b2)]">
        {wrapEthBeforeMint ? 'ETH amount' : `${rateAssetSymbol} amount`}
      </label>
      <input
        value={mintWethAmount}
        onChange={(event) => setMintWethAmount(event.target.value)}
        className={inputClass}
        placeholder="1.0"
      />
      {wrapEthBeforeMint && ethBalance?.value !== undefined ? (
        <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
          Balance: {formatUnits(ethBalance.value, ethBalance.decimals)} ETH
        </div>
      ) : null}
      {!wrapEthBeforeMint && wethBalance !== undefined ? (
        <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
          Balance: {formatUnits(wethBalance, wethDecimals)} {rateAssetSymbol}
        </div>
      ) : null}
      <label className="mt-2 block text-xs text-[var(--text-muted,#9aa3b2)]">
        Preview {detfSymbol} out
      </label>
      <input
        value={
          mintingAllowedNow === false
            ? 'Unavailable'
            : !mintWethAmount.trim() || parsedMintWeth === undefined || parsedMintWeth === BigInt(0)
              ? '0'
              : previewMintOut !== undefined
                ? formatUnits(previewMintOut as bigint, 18)
                : ''
        }
        readOnly
        className={`${inputClass} text-[var(--text-muted,#9aa3b2)]`}
      />
      {mintingAllowedNow === false ? (
        <div className="mt-1 text-xs text-amber-300">
          Mint preview is unavailable unless minting is currently enabled.
        </div>
      ) : previewMintOutError ? (
        <div className="mt-1 text-xs text-amber-300">
          Mint preview read reverted on the current pool state.
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
        disableActions={
          wrapEthBeforeMint ||
          !isConnected ||
          !walletMatchesDataChain ||
          !effectiveWethToken ||
          !routerAddress
        }
        signedDisabled={wrapEthBeforeMint}
        signedDisabledReason="Signed Permit2 mode only applies when the input asset is WETH. Wrapping native ETH uses the router payable path instead."
        explicitDescription={
          wrapEthBeforeMint
            ? 'Native ETH path: the router wraps the sent ETH into WETH before the mint executes. No token approvals are required.'
            : undefined
        }
      />
      <SlippageInput className="mt-3" value={mintSlippage} onChange={setMintSlippage} />
      {approvalError ? (
        <div className="mt-2 text-xs text-amber-300">Approval error: {approvalError}</div>
      ) : null}
      {approvalState === 'approving' ? (
        <div className="mt-2 text-xs text-[var(--text-muted,#9aa3b2)]">Approvals pending…</div>
      ) : null}
      {accurateQuote !== null ? (
        <div className="mt-2 text-xs text-[var(--accent,#4FD44B)]">
          Accurate signed quote: {formatUnits(accurateQuote, 18)} {detfSymbol}
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
                !parsedMintWeth ||
                !effectiveWethToken ||
                !routerAddress ||
                accurateQuoteLoading
              }
              className={btnSecondary}
            >
              {accurateQuoteLoading ? 'Signing Quote…' : 'Get Accurate Quote (Signed)'}
            </button>
            <button
              type="button"
              onClick={() => void handleMintSigned()}
              disabled={
                mintingAllowedNow === false ||
                !isConnected ||
                !walletMatchesDataChain ||
                !parsedMintWeth ||
                !effectiveWethToken ||
                !routerAddress ||
                !storedPermitSignature ||
                storedPermitSignature.intentKey !== activePermitIntentKey
              }
              className={btnPrimary}
            >
              Mint (Signed)
            </button>
          </>
        ) : (
          <button
            type="button"
            onClick={() => void handleMint()}
            disabled={
              mintingAllowedNow === false ||
              !isConnected ||
              !walletMatchesDataChain ||
              !parsedMintWeth ||
              !effectiveWethToken ||
              !routerAddress
            }
            className={btnPrimary}
          >
            {wrapEthBeforeMint ? 'Mint with ETH Wrapping' : 'Mint (Explicit)'}
          </button>
        )}
      </div>
    </div>
  )
}