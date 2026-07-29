'use client'

import Link from 'next/link'
import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  erc20Abi,
  type PublicClient,
} from 'viem'
import {
  useAccount,
  useChainId,
  useConnect,
  usePublicClient,
  useReadContract,
  useSwitchChain,
  useWriteContract,
} from 'wagmi'

import { useApprovalFlow } from '../../lib/hooks/useApprovalFlow'
import { getAddressArtifacts } from '../../lib/addressArtifacts'
import { useDeploymentEnvironment } from '../../lib/deploymentEnvironment'
import { swapExactInAbi } from '../../lib/swapAbis'
import {
  buildStrategyVaultDepositArgs,
  buildStrategyVaultWithdrawArgs,
} from '../../lib/earn/buildVaultSwapArgs'
import {
  computeMinAmountOut,
  DEFAULT_SLIPPAGE_PERCENT,
} from '../../lib/earn/computeMinAmountOut'
import { formatPreviewAmount } from '../../lib/earn/previewFormat'
import {
  querySwapExactInAbi,
  toVaultDepositQueryArgs,
  toVaultWithdrawQueryArgs,
} from '../../lib/earn/toVaultSwapQueryArgs'
import type { EarnProduct } from '../../lib/earn/types'
import {
  resolveWalletGate,
  type PendingLeg,
} from '../../lib/tx/actionState'
import { parseContractError } from '../../lib/tx/parseContractError'
import { ActionCta } from '../ui/ActionCta'
import { AmountField, parseAmountFieldValue } from '../ui/AmountField'
import { Button } from '../ui/Button'
import { Card } from '../ui/Card'
import { TxSteps } from '../ui/TxSteps'
import SlippageInput from '../SlippageInput'

const vaultTokensAbi = [
  {
    type: 'function',
    name: 'tokens',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address[]' }],
  },
  {
    type: 'function',
    name: 'vaultTokens',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address[]' }],
  },
] as const

type Mode = 'deposit' | 'withdraw'

/**
 * Strategy vault deposit/withdraw via Standard Exchange Router.
 *
 * Preview: query 8-tuple + simulateContract + ZERO_ADDR account (never execute-args spread).
 * Execute: 10-tuple builders with minOut from computeMinAmountOut(preview, slippage).
 * Approvals: split handlers only (K17) — never one-shot handleApproval for multi-leg CTA.
 */
export function DepositPanel({
  product,
  chainId,
}: {
  product: EarnProduct
  chainId: number
}) {
  const { address, isConnected } = useAccount()
  const walletChainId = useChainId()
  const { connect, connectors, isPending: isConnectPending } = useConnect()
  const { switchChainAsync, isPending: isSwitchPending } = useSwitchChain()
  const { environment } = useDeploymentEnvironment()
  const publicClient = usePublicClient({ chainId }) as PublicClient | undefined
  const { writeContractAsync } = useWriteContract()

  const [mode, setMode] = useState<Mode>('deposit')
  const [tokenIn, setTokenIn] = useState<`0x${string}` | ''>('')
  const [amount, setAmount] = useState('')
  const [status, setStatus] = useState('')
  const [txPhase, setTxPhase] = useState<'idle' | 'approve' | 'submit' | 'done' | 'error'>('idle')
  const [successHash, setSuccessHash] = useState<string | null>(null)
  const [slippage, setSlippage] = useState(DEFAULT_SLIPPAGE_PERCENT)
  const [previewOut, setPreviewOut] = useState<bigint | null>(null)
  const [previewError, setPreviewError] = useState<string | null>(null)
  const [previewLoading, setPreviewLoading] = useState(false)
  const [pendingLeg, setPendingLeg] = useState<PendingLeg>(null)
  const [assetSymbols, setAssetSymbols] = useState<Record<string, string>>({})

  const isWrongNetwork =
    isConnected && typeof walletChainId === 'number' && walletChainId !== chainId

  const platform = useMemo(() => {
    try {
      return getAddressArtifacts(chainId, environment).platform as {
        balancerV3StandardExchangeRouter?: `0x${string}`
        permit2?: `0x${string}`
      }
    } catch {
      return {}
    }
  }, [chainId, environment])

  const routerAddress = platform.balancerV3StandardExchangeRouter ?? null
  const permit2Address = platform.permit2 ?? null
  const vaultAddress = product.address

  const { data: vaultTokensLegacy } = useReadContract({
    address: vaultAddress,
    abi: vaultTokensAbi,
    functionName: 'tokens',
    chainId,
    query: { enabled: product.productType === 'strategy' },
  })
  const { data: vaultTokensMulti } = useReadContract({
    address: vaultAddress,
    abi: vaultTokensAbi,
    functionName: 'vaultTokens',
    chainId,
    query: { enabled: product.productType === 'strategy' },
  })

  const underlyingTokens = useMemo(() => {
    const raw = Array.isArray(vaultTokensMulti)
      ? vaultTokensMulti
      : Array.isArray(vaultTokensLegacy)
        ? vaultTokensLegacy
        : []
    return (raw as unknown[]).filter((t): t is `0x${string}` => typeof t === 'string' && t.startsWith('0x'))
  }, [vaultTokensLegacy, vaultTokensMulti])

  useEffect(() => {
    if (mode === 'deposit' && underlyingTokens[0] && !tokenIn) {
      setTokenIn(underlyingTokens[0])
    }
    if (mode === 'withdraw') {
      setTokenIn(vaultAddress)
    }
  }, [mode, underlyingTokens, tokenIn, vaultAddress])

  // Resolve symbols for underlying assets (symbol primary in select)
  useEffect(() => {
    if (!publicClient || underlyingTokens.length === 0) return
    let cancelled = false
    void (async () => {
      const entries: Record<string, string> = {}
      await Promise.all(
        underlyingTokens.map(async (t) => {
          try {
            const sym = (await publicClient.readContract({
              address: t,
              abi: erc20Abi,
              functionName: 'symbol',
            })) as string
            entries[t.toLowerCase()] = sym
          } catch {
            entries[t.toLowerCase()] = `${t.slice(0, 6)}…${t.slice(-4)}`
          }
        }),
      )
      if (!cancelled) setAssetSymbols(entries)
    })()
    return () => {
      cancelled = true
    }
  }, [publicClient, underlyingTokens])

  const withdrawTokenOut = underlyingTokens[0] as `0x${string}` | undefined

  const assetForBalance =
    mode === 'deposit' ? (tokenIn as `0x${string}` | undefined) : vaultAddress

  // Output token for preview display: deposit → vault shares; withdraw → underlying
  const assetForOut =
    mode === 'deposit'
      ? vaultAddress
      : (withdrawTokenOut as `0x${string}` | undefined)

  const { data: decimals } = useReadContract({
    address: assetForBalance,
    abi: erc20Abi,
    functionName: 'decimals',
    chainId,
    query: { enabled: !!assetForBalance },
  })

  const { data: symbol } = useReadContract({
    address: assetForBalance,
    abi: erc20Abi,
    functionName: 'symbol',
    chainId,
    query: { enabled: !!assetForBalance },
  })

  const { data: outDecimalsRaw } = useReadContract({
    address: assetForOut,
    abi: erc20Abi,
    functionName: 'decimals',
    chainId,
    query: { enabled: !!assetForOut },
  })

  const { data: outSymbolRaw } = useReadContract({
    address: assetForOut,
    abi: erc20Abi,
    functionName: 'symbol',
    chainId,
    query: { enabled: !!assetForOut },
  })

  const { data: balance, refetch: refetchBalance } = useReadContract({
    address: assetForBalance,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    chainId,
    query: { enabled: !!assetForBalance && !!address },
  })

  const dec = typeof decimals === 'number' ? decimals : 18
  // Prefer on-chain out decimals; fall back to product.decimals for vault shares
  const outDec =
    typeof outDecimalsRaw === 'number'
      ? outDecimalsRaw
      : mode === 'deposit' && typeof product.decimals === 'number'
        ? product.decimals
        : 18
  const outSymbolDisplay =
    outSymbolRaw != null
      ? String(outSymbolRaw)
      : mode === 'deposit'
        ? product.symbol || 'shares'
        : 'asset'
  const parsedAmount = useMemo(
    () => parseAmountFieldValue(amount, dec),
    [amount, dec],
  )
  const amountValid = parsedAmount != null && parsedAmount > BigInt(0)

  const approval = useApprovalFlow({
    tokenAddress: mode === 'deposit' ? (tokenIn as `0x${string}`) || null : vaultAddress,
    permit2Address,
    routerAddress,
    publicClient: publicClient ?? null,
    address: address ?? null,
    writeContractAsync: writeContractAsync as any,
    effectiveApprovalMode: 'explicit',
    resolvedChainId: chainId,
    routerHasBytecode: routerAddress ? true : null,
    effectiveAmount: parsedAmount,
  })

  // Preview: 8-tuple query via simulateContract + ZERO_ADDR
  useEffect(() => {
    if (!routerAddress || !publicClient || !amountValid || !parsedAmount) {
      setPreviewOut(null)
      setPreviewError(null)
      setPreviewLoading(false)
      return
    }
    if (mode === 'deposit' && !tokenIn) {
      setPreviewOut(null)
      return
    }
    if (mode === 'withdraw' && !withdrawTokenOut) {
      setPreviewOut(null)
      setPreviewError('Vault underlying tokens unavailable for withdraw.')
      return
    }

    let cancelled = false
    setPreviewLoading(true)
    setPreviewError(null)

    const run = async () => {
      try {
        const queryArgs =
          mode === 'deposit'
            ? toVaultDepositQueryArgs({
                vault: vaultAddress,
                tokenIn: tokenIn as `0x${string}`,
                amountIn: parsedAmount,
              })
            : toVaultWithdrawQueryArgs({
                vault: vaultAddress,
                tokenOut: withdrawTokenOut as `0x${string}`,
                amountIn: parsedAmount,
              })

        // Explicit 8-tuple only — never spread execute 10-tuple
        const { result } = await publicClient.simulateContract({
          address: routerAddress,
          abi: querySwapExactInAbi,
          functionName: 'querySwapSingleTokenExactIn',
          args: [...queryArgs],
          account: '0x0000000000000000000000000000000000000000',
        })

        if (!cancelled) {
          setPreviewOut(result as bigint)
          setPreviewError(null)
        }
      } catch (e) {
        if (!cancelled) {
          setPreviewOut(null)
          setPreviewError(parseContractError(e))
        }
      } finally {
        if (!cancelled) setPreviewLoading(false)
      }
    }

    void run()
    return () => {
      cancelled = true
    }
  }, [
    routerAddress,
    publicClient,
    amountValid,
    parsedAmount,
    mode,
    tokenIn,
    withdrawTokenOut,
    vaultAddress,
  ])

  const minOut =
    previewOut != null && previewOut > BigInt(0)
      ? computeMinAmountOut(previewOut, slippage)
      : BigInt(0)
  const hasPreview = previewOut != null && previewOut > BigInt(0) && minOut > BigInt(0)

  const gate = resolveWalletGate({
    isConnected,
    isWrongNetwork,
    amountValid,
    hasPreview: hasPreview && !!routerAddress,
    needsTokenApproval: approval.needsTokenApproval,
    needsPermit2Approval: approval.needsPermit2Approval,
    executeLabel: mode === 'deposit' ? 'Deposit' : 'Withdraw',
  })

  // Merge local pending with connect/switch hook pending
  const effectivePending: PendingLeg =
    pendingLeg ??
    (isConnectPending
      ? 'connect'
      : isSwitchPending
        ? 'switch'
        : approval.approvalState === 'approving'
          ? gate.kind === 'approve' && gate.leg === 'token-permit2'
            ? 'approve-token-permit2'
            : gate.kind === 'approve' && gate.leg === 'permit2-router'
              ? 'approve-permit2-router'
              : null
          : null)

  const handleConnect = useCallback(() => {
    const c = connectors[0]
    if (c) connect({ connector: c })
  }, [connect, connectors])

  const handleSwitch = useCallback(async () => {
    try {
      setStatus('')
      await switchChainAsync?.({ chainId })
    } catch (e) {
      setStatus(parseContractError(e))
    }
  }, [switchChainAsync, chainId])

  const handleApproveToken = useCallback(async () => {
    setPendingLeg('approve-token-permit2')
    setTxPhase('approve')
    setStatus('')
    try {
      // Split handler only — never handleApproval for sequential multi-leg
      await approval.handleIssuePermit2Approval()
    } catch (e) {
      setTxPhase('error')
      setStatus(parseContractError(e))
    } finally {
      setPendingLeg(null)
    }
  }, [approval])

  const handleApproveRouter = useCallback(async () => {
    setPendingLeg('approve-permit2-router')
    setTxPhase('approve')
    setStatus('')
    try {
      await approval.handleIssueRouterApproval(parsedAmount)
    } catch (e) {
      setTxPhase('error')
      setStatus(parseContractError(e))
    } finally {
      setPendingLeg(null)
    }
  }, [approval, parsedAmount])

  const runExecute = useCallback(async () => {
    if (!routerAddress || !publicClient || !address || !parsedAmount || !hasPreview) {
      setStatus('Quote required before deposit. Continue via Swap if preview fails.')
      return
    }
    if (mode === 'deposit' && !tokenIn) {
      setStatus('Select an underlying token to deposit.')
      return
    }
    if (mode === 'withdraw' && !withdrawTokenOut) {
      setStatus('Vault underlying tokens unavailable for withdraw.')
      return
    }
    // Honest floor: never silent minOut = 0 on happy path
    if (minOut <= BigInt(0)) {
      setStatus('Preview unavailable — cannot deposit with zero minOut. Use Swap fallback.')
      return
    }

    try {
      setStatus('')
      setSuccessHash(null)
      setPendingLeg('execute')
      setTxPhase('submit')
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 1200)

      const args =
        mode === 'deposit'
          ? buildStrategyVaultDepositArgs({
              vault: vaultAddress,
              tokenIn: tokenIn as `0x${string}`,
              amountIn: parsedAmount,
              minAmountOut: minOut,
              deadline,
            })
          : buildStrategyVaultWithdrawArgs({
              vault: vaultAddress,
              tokenOut: withdrawTokenOut as `0x${string}`,
              amountIn: parsedAmount,
              minAmountOut: minOut,
              deadline,
            })

      // 10-tuple execute only
      if (args.length !== 10) {
        throw new Error('Invalid execute args arity')
      }

      const hash = await writeContractAsync({
        address: routerAddress,
        abi: swapExactInAbi,
        functionName: 'swapSingleTokenExactIn',
        args: [...args],
        chainId,
      })

      await publicClient.waitForTransactionReceipt({ hash })
      setSuccessHash(hash)
      setTxPhase('done')
      setStatus(mode === 'deposit' ? 'Position live.' : 'Withdraw complete.')
      setAmount('')
      void refetchBalance()
      void approval.refetchAllowance()
      void approval.refetchPermit2Allowance()
    } catch (e: unknown) {
      setTxPhase('error')
      setStatus(parseContractError(e))
    } finally {
      setPendingLeg(null)
    }
  }, [
    routerAddress,
    publicClient,
    address,
    parsedAmount,
    hasPreview,
    minOut,
    mode,
    tokenIn,
    withdrawTokenOut,
    writeContractAsync,
    vaultAddress,
    chainId,
    refetchBalance,
    approval,
  ])

  if (product.productType !== 'strategy') {
    return (
      <Card>
        <h3 className="text-sm font-medium text-[var(--text-primary,#EDEDED)]">Deposit via DETF flows</h3>
        <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">
          Protocol and seigniorage DETFs use mint / bond / sell rather than a single vault share deposit.
          Use the DETF actions below, or open the full workspace.
        </p>
        <div className="mt-3">
          <Link href={`/staking?detf=${product.address}`}>
            <Button variant="secondary" size="sm">
              Open DETF workspace
            </Button>
          </Link>
        </div>
      </Card>
    )
  }

  const steps = [
    {
      id: 'approve',
      label: 'Approve tokens',
      status:
        txPhase === 'approve'
          ? ('active' as const)
          : txPhase === 'submit' || txPhase === 'done'
            ? ('done' as const)
            : txPhase === 'error'
              ? ('error' as const)
              : ('pending' as const),
    },
    {
      id: 'submit',
      label: mode === 'deposit' ? 'Deposit via router' : 'Withdraw via router',
      status:
        txPhase === 'submit'
          ? ('active' as const)
          : txPhase === 'done'
            ? ('done' as const)
            : txPhase === 'error'
              ? ('error' as const)
              : ('pending' as const),
    },
  ]

  return (
    <Card>
      <div className="flex gap-2 mb-4">
        <Button
          data-testid="earn-mode-deposit"
          size="sm"
          variant={mode === 'deposit' ? 'primary' : 'secondary'}
          onClick={() => {
            setMode('deposit')
            setTokenIn(underlyingTokens[0] || '')
            setTxPhase('idle')
            setStatus('')
            setPreviewOut(null)
          }}
        >
          Deposit
        </Button>
        <Button
          data-testid="earn-mode-withdraw"
          size="sm"
          variant={mode === 'withdraw' ? 'primary' : 'secondary'}
          onClick={() => {
            setMode('withdraw')
            setTokenIn(vaultAddress)
            setTxPhase('idle')
            setStatus('')
            setPreviewOut(null)
          }}
        >
          Withdraw
        </Button>
      </div>

      {mode === 'deposit' && underlyingTokens.length > 0 ? (
        <label className="block text-xs text-[var(--text-muted,#9aa3b2)] mb-3">
          Asset
          <select
            data-testid="earn-deposit-asset"
            className="mt-1 w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm text-[var(--text-primary,#EDEDED)]"
            value={tokenIn}
            onChange={(e) => setTokenIn(e.target.value as `0x${string}`)}
          >
            {underlyingTokens.map((t) => {
              const sym = assetSymbols[t.toLowerCase()]
              return (
                <option key={t} value={t}>
                  {sym ? `${sym} · ${t.slice(0, 6)}…${t.slice(-4)}` : t}
                </option>
              )
            })}
          </select>
        </label>
      ) : null}

      <AmountField
        data-testid="earn-deposit-amount"
        label="Amount"
        value={amount}
        onChange={setAmount}
        decimals={dec}
        balance={typeof balance === 'bigint' ? balance : undefined}
        symbol={symbol ? String(symbol) : undefined}
        usdValue={null}
      />

      <div className="mt-3">
        <SlippageInput value={slippage} onChange={setSlippage} className="max-w-xs" />
      </div>

      <div className="mt-2 text-[11px] text-[var(--text-muted,#9aa3b2)] space-y-0.5">
        {previewLoading ? <p data-testid="earn-deposit-preview-loading">Fetching quote…</p> : null}
        {hasPreview ? (
          <p data-testid="earn-deposit-preview">
            Expected out:{' '}
            <span className="font-mono tabular-nums text-[var(--text-primary,#EDEDED)]">
              {formatPreviewAmount(previewOut!, outDec)}
            </span>{' '}
            {outSymbolDisplay}
            {' · '}
            Min:{' '}
            <span className="font-mono tabular-nums">{formatPreviewAmount(minOut, outDec)}</span>
          </p>
        ) : null}
        {previewError && amountValid ? (
          <p data-testid="earn-deposit-preview-error" className="text-amber-300/90">
            Quote unavailable: {previewError}
          </p>
        ) : null}
        <p>Fees: protocol/router fees apply on-chain. Numeric fee display not yet available.</p>
      </div>

      {!routerAddress ? (
        <p className="mt-3 text-sm text-red-300">Router not configured for this environment.</p>
      ) : null}

      <div className="mt-4">
        <TxSteps steps={steps} />
      </div>

      <div className="mt-4 flex flex-wrap gap-2 items-center">
        <ActionCta
          data-testid="earn-deposit-submit"
          gate={gate}
          pendingLeg={effectivePending}
          onConnect={handleConnect}
          onSwitchNetwork={() => void handleSwitch()}
          onApproveTokenPermit2={() => void handleApproveToken()}
          onApprovePermit2Router={() => void handleApproveRouter()}
          onExecute={() => void runExecute()}
        />
        {txPhase === 'done' ? (
          <Link href="/portfolio">
            <Button variant="secondary">View portfolio</Button>
          </Link>
        ) : null}
        <Link
          href={`/swap?tokenOut=${vaultAddress}`}
          data-testid="earn-deposit-swap-fallback"
          className="inline-flex items-center text-xs text-[var(--text-muted,#9aa3b2)] hover:text-[var(--accent,#4FD44B)]"
        >
          Continue via Swap →
        </Link>
      </div>

      {gate.kind === 'disabled' && gate.reason === 'no-preview' && amountValid ? (
        <p className="mt-2 text-xs text-amber-200/90">
          Deposit disabled until a quote is available. Use Swap fallback if the vault quote fails.
        </p>
      ) : null}

      {status ? (
        <p
          data-testid="earn-deposit-status"
          className={`mt-3 text-sm ${txPhase === 'error' ? 'text-red-300' : 'text-[var(--accent,#4FD44B)]'}`}
        >
          {status}
        </p>
      ) : null}
      {approval.approvalError ? (
        <p className="mt-2 text-sm text-red-300">{approval.approvalError}</p>
      ) : null}
      {successHash ? (
        <p
          data-testid="earn-deposit-tx-hash"
          className="mt-1 font-mono text-[10px] text-[var(--text-muted,#9aa3b2)] break-all"
        >
          {successHash}
        </p>
      ) : null}
    </Card>
  )
}

export default DepositPanel
