'use client'

import { Suspense, useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useSearchParams } from 'next/navigation'
import {
  useAccount,
  useChainId,
  useConnect,
  usePublicClient,
  useSendTransaction,
  useSwitchChain,
  useWalletClient,
  useWriteContract,
} from 'wagmi'
import { erc20Abi, formatUnits, isAddress, publicActions, type PublicClient } from 'viem'

import { CHAIN_ID_ROBINHOOD, getAddressArtifacts } from '@indexedex/protocol/addressArtifacts'
import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'
import { hasBytecode } from '@indexedex/protocol/onchain'
import { robinhood, robinhoodTestnet } from '@indexedex/protocol/runtimeChains'
import {
  buildTokenOptionsForChain,
  getStrategyVaultTokensForChain,
  getTokenDecimalsByAddressForChain,
} from '@indexedex/protocol/tokenlists'

import { ActionCta } from '../components/ui/ActionCta'
import { parseAmountFieldValue } from '../components/ui/AmountField'
import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { TokenSelect } from './components/TokenSelect'
import SlippageInput from '../components/SlippageInput'
import { computeMinAmountOut, DEFAULT_SLIPPAGE_PERCENT } from '../lib/earn/computeMinAmountOut'
import { parseLaunchQuery } from '../lib/earn/launchQuery'
import { useApprovalFlow } from '../lib/hooks/useApprovalFlow'
import {
  resolveWalletGate,
  type PendingLeg,
} from '../lib/tx/actionState'
import { parseContractError } from '../lib/tx/parseContractError'

import { STATE_VIEW_ABI } from './lib/v4Abis'
import { resolveV4Platform } from './lib/v4Addresses'
import { discoverV4Pools } from './lib/v4Discover'
import { encodeUniversalSwap, UNIVERSAL_ROUTER_EXECUTE_ABI } from './lib/v4Encode'
import { toPoolId } from './lib/v4PoolId'
import { quoteBestRoute } from './lib/v4Quote'
import { findCandidatePaths } from './lib/v4Route'
import { pickQuote } from './lib/pickQuote'
import { formatPriceImpact, priceImpactBps } from './lib/priceImpact'
import { ethSearchToken, type SearchToken } from './lib/tokenSearch'
import { quoteAndSwapUniswapApi, uniswapApiEnabled, type UniswapApiQuote } from './lib/uniswapTradeApi'
import {
  type Address,
  type SwapRoute,
  type V4PoolKey,
  ZERO_ADDRESS,
  isNativeCurrency,
  isZeroHook,
  poolKeyId,
  sameAddress,
} from './lib/v4Types'

const ETH = 'ETH' as const

function asTokenAddr(value: string): Address | null {
  if (value === ETH) return ZERO_ADDRESS
  if (isAddress(value)) return value
  return null
}

function parseExtraHooks(raw: string): Address[] {
  const out: Address[] = []
  for (const part of raw.split(/[\s,]+/)) {
    const t = part.trim()
    if (isAddress(t) && t.toLowerCase() !== ZERO_ADDRESS) out.push(t)
  }
  return out
}

function hopLabel(pool: V4PoolKey, tokenNames: Map<string, string>): string {
  const a = tokenNames.get(pool.currency0.toLowerCase()) ?? pool.currency0.slice(0, 6)
  const b = tokenNames.get(pool.currency1.toLowerCase()) ?? pool.currency1.slice(0, 6)
  const fee = (pool.fee / 10_000).toFixed(2).replace(/0$/, '')
  const hook = isZeroHook(pool.hooks) ? 'vanilla' : `hook ${pool.hooks.slice(0, 8)}…`
  return `${a}/${b} ${fee}% · ${hook}`
}

function SwapPageInner() {
  const searchParams = useSearchParams()
  const launch = parseLaunchQuery({
    launch: searchParams.get('launch'),
    tokenOut: searchParams.get('tokenOut'),
    tokenIn: searchParams.get('tokenIn'),
  })

  const { address, isConnected } = useAccount()
  const walletChainId = useChainId()
  const { connect, connectors, isPending: isConnectPending } = useConnect()
  const { switchChainAsync, isPending: isSwitchPending } = useSwitchChain()
  const { selectedChainId } = useSelectedNetwork()
  const { environment } = useDeploymentEnvironment()
  const wagmiPublic = usePublicClient({ chainId: selectedChainId })
  const { data: walletClient } = useWalletClient()
  const { writeContractAsync } = useWriteContract()
  const { sendTransactionAsync } = useSendTransaction()

  const readClient = useMemo((): PublicClient | undefined => {
    if (walletClient) return walletClient.extend(publicActions) as unknown as PublicClient
    return wagmiPublic as PublicClient | undefined
  }, [walletClient, wagmiPublic])

  const isWrongNetwork = isConnected && typeof walletChainId === 'number' && walletChainId !== selectedChainId

  const platform = useMemo(() => {
    try {
      return getAddressArtifacts(selectedChainId, environment).platform as Record<string, unknown>
    } catch {
      return {}
    }
  }, [selectedChainId, environment])

  const v4 = useMemo(() => resolveV4Platform(platform), [platform])

  const seShareSet = useMemo(() => {
    return new Set(
      getStrategyVaultTokensForChain(selectedChainId, environment).map((t) => t.address.toLowerCase()),
    )
  }, [selectedChainId, environment])

  const tokenOptions = useMemo(() => {
    const opts = buildTokenOptionsForChain(selectedChainId, true, false).filter((t) => {
      if (t.value === ETH) return true
      if (t.type === 'token') return true
      if (t.type === 'vault' && !seShareSet.has(String(t.value).toLowerCase())) return true
      return false
    })
    const seen = new Set(opts.map((o) => String(o.value).toLowerCase()))
    if (launch.tokenOut && !seen.has(launch.tokenOut.toLowerCase())) {
      opts.push({
        value: launch.tokenOut,
        label: `${launch.tokenOut.slice(0, 6)}…${launch.tokenOut.slice(-4)}`,
        chainId: selectedChainId,
        type: 'token',
      })
    }
    if (launch.tokenIn && !seen.has(launch.tokenIn.toLowerCase())) {
      opts.push({
        value: launch.tokenIn,
        label: `${launch.tokenIn.slice(0, 6)}…${launch.tokenIn.slice(-4)}`,
        chainId: selectedChainId,
        type: 'token',
      })
    }
    return opts
  }, [selectedChainId, launch.tokenIn, launch.tokenOut, seShareSet])

  const [imported, setImported] = useState<SearchToken[]>([])

  const searchTokens = useMemo((): SearchToken[] => {
    const out: SearchToken[] = []
    const seen = new Set<string>()
    const push = (t: SearchToken) => {
      const k = t.address.toLowerCase()
      if (seen.has(k)) return
      seen.add(k)
      out.push(t)
    }
    push(ethSearchToken())
    for (let i = 0; i < tokenOptions.length; i++) {
      const t = tokenOptions[i]!
      if (t.value === ETH) continue
      const addr = t.value as Address
      push({
        value: addr,
        label: t.label,
        symbol: t.label.split('(')[0]?.trim() || t.label,
        name: t.label,
        address: addr,
        decimals: getTokenDecimalsByAddressForChain(selectedChainId, addr, environment),
      })
    }
    for (let i = 0; i < imported.length; i++) push(imported[i]!)
    return out
  }, [tokenOptions, imported, selectedChainId, environment])

  const tokenNames = useMemo(() => {
    const m = new Map<string, string>()
    for (let i = 0; i < searchTokens.length; i++) {
      const t = searchTokens[i]!
      m.set(t.address.toLowerCase(), t.symbol)
    }
    return m
  }, [searchTokens])

  const seVaults = useMemo(() => {
    return getStrategyVaultTokensForChain(selectedChainId, environment)
      .filter((t) => (t.tags ?? []).includes('se'))
      .map((t) => t.address)
  }, [selectedChainId, environment])

  const defaultIn = tokenOptions.find((t) => t.value !== ETH)?.value ?? ETH
  const defaultOut =
    launch.tokenOut && tokenOptions.some((t) => t.value !== ETH && sameAddress(t.value, launch.tokenOut!))
      ? launch.tokenOut
      : tokenOptions.find((t) => t.value !== ETH && t.value !== defaultIn)?.value ?? ''

  const [tokenIn, setTokenIn] = useState<string>(launch.tokenIn ?? defaultIn)
  const [tokenOut, setTokenOut] = useState<string>(defaultOut)
  const [amountIn, setAmountIn] = useState('')
  const [slippage, setSlippage] = useState(DEFAULT_SLIPPAGE_PERCENT)
  const [extraHooksRaw, setExtraHooksRaw] = useState('')
  const [showAdvanced, setShowAdvanced] = useState(false)
  const [approvalMode, setApprovalMode] = useState<'explicit' | 'signed'>('explicit')
  const [pools, setPools] = useState<V4PoolKey[]>([])
  const [poolsLoading, setPoolsLoading] = useState(false)
  const [poolsError, setPoolsError] = useState<string | null>(null)
  const [route, setRoute] = useState<SwapRoute | null>(null)
  const [uniQuote, setUniQuote] = useState<UniswapApiQuote | null>(null)
  const [quotePick, setQuotePick] = useState<'local' | 'uniswap' | null>(null)
  const [impactBps, setImpactBps] = useState<number | null>(null)
  const [txHash, setTxHash] = useState<`0x${string}` | null>(null)
  const [quoteError, setQuoteError] = useState<string | null>(null)
  const [quoteLoading, setQuoteLoading] = useState(false)
  const [status, setStatus] = useState('')
  const [pendingLeg, setPendingLeg] = useState<PendingLeg>(null)
  const [balanceIn, setBalanceIn] = useState<bigint | undefined>(undefined)
  const [routerHasBytecode, setRouterHasBytecode] = useState<boolean | null>(null)

  const extraHooks = useMemo(() => parseExtraHooks(extraHooksRaw), [extraHooksRaw])
  const tokenInAddress = asTokenAddr(tokenIn)
  const tokenOutAddress = asTokenAddr(tokenOut)
  const nativeIn = tokenIn === ETH || (tokenInAddress != null && isNativeCurrency(tokenInAddress))

  const inDecimals = useMemo(() => {
    const t = searchTokens.find((x) => String(x.value) === tokenIn || x.address.toLowerCase() === (tokenInAddress ?? '').toLowerCase())
    return t?.decimals ?? 18
  }, [searchTokens, tokenIn, tokenInAddress])

  const outDecimals = useMemo(() => {
    const t = searchTokens.find((x) => String(x.value) === tokenOut || x.address.toLowerCase() === (tokenOutAddress ?? '').toLowerCase())
    return t?.decimals ?? 18
  }, [searchTokens, tokenOut, tokenOutAddress])

  const parsedAmount = parseAmountFieldValue(amountIn, inDecimals)
  const amountValid = parsedAmount != null && parsedAmount > BigInt(0)

  const approval = useApprovalFlow({
    tokenAddress: nativeIn ? null : tokenInAddress,
    permit2Address: v4.permit2,
    routerAddress: v4.universalRouter,
    publicClient: readClient ?? null,
    address: address ?? null,
    writeContractAsync: writeContractAsync as any,
    effectiveApprovalMode: approvalMode,
    rpcChainId: walletChainId,
    resolvedChainId: selectedChainId,
    routerHasBytecode,
    effectiveAmount: parsedAmount,
  })

  useEffect(() => {
    let cancelled = false
    const router = v4.universalRouter
    const client = readClient
    if (!router || !client) {
      setRouterHasBytecode(null)
      return
    }
    void hasBytecode(client, router).then((ok) => {
      if (!cancelled) setRouterHasBytecode(ok)
    })
    return () => {
      cancelled = true
    }
  }, [v4.universalRouter, readClient])

  useEffect(() => {
    let cancelled = false
    const client = readClient
    const stateView = v4.stateView
    if (!client || !stateView) return
    const tokens = searchTokens
      .map((t) => t.address)
      .filter((t): t is Address => !!t)
    setPoolsLoading(true)
    setPoolsError(null)
    void discoverV4Pools({
      client,
      stateView,
      tokens,
      seVaults,
      extraHooks,
      poolManager: v4.poolManager,
    })
      .then((live) => {
        if (cancelled) return
        setPools(live)
        setPoolsLoading(false)
      })
      .catch((e) => {
        if (cancelled) return
        setPoolsError(parseContractError(e))
        setPoolsLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [readClient, v4.stateView, v4.poolManager, searchTokens, seVaults, extraHooks])

  const seededPair = useRef(false)
  useEffect(() => {
    if (seededPair.current) return
    if (launch.tokenOut) {
      seededPair.current = true
      return
    }
    if (pools.length === 0 || !tokenInAddress || !tokenOutAddress) return
    if (findCandidatePaths(pools, tokenInAddress, tokenOutAddress).length > 0) {
      seededPair.current = true
      return
    }
    const p = pools[0]!
    const toOption = (addr: Address) => {
      if (addr.toLowerCase() === ZERO_ADDRESS) return ETH
      const match = tokenOptions.find((t) => t.value !== ETH && sameAddress(String(t.value), addr))
      return match ? String(match.value) : addr
    }
    setTokenIn(toOption(p.currency0))
    setTokenOut(toOption(p.currency1))
    seededPair.current = true
  }, [pools, launch.tokenOut, tokenInAddress, tokenOutAddress, tokenOptions])

  useEffect(() => {
    let cancelled = false
    const client = readClient
    const quoter = v4.quoter
    if (!client || !quoter || !tokenInAddress || !tokenOutAddress || !parsedAmount) {
      setRoute(null)
      setUniQuote(null)
      setQuotePick(null)
      setImpactBps(null)
      setQuoteError(null)
      setQuoteLoading(false)
      return
    }
    if (sameAddress(tokenInAddress, tokenOutAddress)) {
      setRoute(null)
      setUniQuote(null)
      setQuotePick(null)
      setQuoteError('Pick two different tokens')
      return
    }
    setQuoteLoading(true)
    setQuoteError(null)
    const slippageBps = Math.floor(Math.min(5, Math.max(0, slippage)) * 100)
    const handle = setTimeout(() => {
      void Promise.all([
        quoteBestRoute({
          client,
          quoter,
          pools,
          tokenIn: tokenInAddress,
          tokenOut: tokenOutAddress,
          amountIn: parsedAmount,
          account: address,
        }),
        address && uniswapApiEnabled(selectedChainId)
          ? quoteAndSwapUniswapApi({
              chainId: selectedChainId,
              tokenIn: tokenInAddress,
              tokenOut: tokenOutAddress,
              amountIn: parsedAmount,
              swapper: address,
              slippageBps,
            })
          : Promise.resolve(null),
      ])
        .then(async ([local, uni]) => {
          if (cancelled) return
          const pick = pickQuote(local, uni)
          setRoute(local)
          setUniQuote(uni)
          setQuotePick(pick)
          setQuoteLoading(false)
          if (!pick) {
            setImpactBps(null)
            setQuoteError(
              pools.length === 0
                ? 'No live Uniswap v4 pools found yet. Connect a wallet on the network that holds the pools, or paste a token address.'
                : 'No route for this pair on the live pools we found. Search a token or pick a pair from the list below.',
            )
            return
          }
          if (pick === 'local' && local && local.hops.length === 1 && v4.stateView) {
            try {
              const hop = local.hops[0]!
              const slot0 = (await client.readContract({
                address: v4.stateView,
                abi: STATE_VIEW_ABI,
                functionName: 'getSlot0',
                args: [toPoolId(hop.pool)],
              })) as readonly [bigint, number, number, number]
              setImpactBps(
                priceImpactBps({
                  amountIn: local.amountIn,
                  amountOut: local.amountOut,
                  sqrtPriceX96: slot0[0],
                  zeroForOne: hop.zeroForOne,
                }),
              )
            } catch {
              setImpactBps(null)
            }
          } else {
            setImpactBps(null)
          }
        })
        .catch((e) => {
          if (cancelled) return
          setRoute(null)
          setUniQuote(null)
          setQuotePick(null)
          setImpactBps(null)
          setQuoteLoading(false)
          setQuoteError(parseContractError(e))
        })
    }, 250)
    return () => {
      cancelled = true
      clearTimeout(handle)
    }
  }, [
    readClient,
    v4.quoter,
    v4.stateView,
    pools,
    tokenInAddress,
    tokenOutAddress,
    parsedAmount,
    address,
    selectedChainId,
    slippage,
  ])

  useEffect(() => {
    let cancelled = false
    const client = readClient
    if (!client || !address || !tokenInAddress) {
      setBalanceIn(undefined)
      return
    }
    if (nativeIn) {
      void client.getBalance({ address }).then((b) => {
        if (!cancelled) setBalanceIn(b)
      })
      return () => {
        cancelled = true
      }
    }
    void client
      .readContract({
        address: tokenInAddress,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: [address],
      })
      .then((b) => {
        if (!cancelled) setBalanceIn(b as bigint)
      })
      .catch(() => {
        if (!cancelled) setBalanceIn(undefined)
      })
    return () => {
      cancelled = true
    }
  }, [readClient, address, tokenInAddress, nativeIn])

  const quotedOut =
    quotePick === 'uniswap' && uniQuote
      ? uniQuote.amountOut
      : quotePick === 'local' && route
        ? route.amountOut
        : null
  const minOut = quotedOut != null ? computeMinAmountOut(quotedOut, slippage) : BigInt(0)
  const hasPreview = quotedOut != null && quotedOut > BigInt(0) && minOut > BigInt(0) && !!v4.universalRouter

  const effectiveApprovalMode = approvalMode
  const gate = resolveWalletGate({
    isConnected,
    isWrongNetwork,
    amountValid,
    hasPreview,
    needsTokenApproval: nativeIn ? false : approval.needsTokenApproval,
    needsPermit2Approval: nativeIn ? false : approval.needsPermit2Approval,
    executeLabel: 'Swap',
    signedMode: effectiveApprovalMode === 'signed',
  })

  const effectiveSwapPendingLeg: PendingLeg =
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
      await switchChainAsync?.({ chainId: selectedChainId })
    } catch (e) {
      setStatus(parseContractError(e))
    }
  }, [switchChainAsync, selectedChainId])

  const handleIssuePermit2Approval = useCallback(async () => {
    setPendingLeg('approve-token-permit2')
    setStatus('')
    try {
      await approval.handleIssuePermit2Approval()
    } catch (e) {
      setStatus(parseContractError(e))
    } finally {
      setPendingLeg(null)
    }
  }, [approval])

  const handleIssueRouterApproval = useCallback(async () => {
    setPendingLeg('approve-permit2-router')
    setStatus('')
    try {
      await approval.handleIssueRouterApproval(parsedAmount)
    } catch (e) {
      setStatus(parseContractError(e))
    } finally {
      setPendingLeg(null)
    }
  }, [approval, parsedAmount])

  const handleSwap = useCallback(async () => {
    if (!readClient || !hasPreview) return
    setPendingLeg('execute')
    setStatus('')
    setTxHash(null)
    try {
      let hash: `0x${string}`
      if (quotePick === 'uniswap' && uniQuote) {
        hash = await sendTransactionAsync({
          to: uniQuote.to,
          data: uniQuote.data,
          value: uniQuote.value,
        })
      } else {
        if (!v4.universalRouter || !route) {
          setPendingLeg(null)
          return
        }
        const encoded = encodeUniversalSwap({
          route,
          amountOutMinimum: minOut,
          nativeIn,
        })
        const deadline = BigInt(Math.floor(Date.now() / 1000) + 1200)
        hash = await writeContractAsync({
          address: v4.universalRouter,
          abi: UNIVERSAL_ROUTER_EXECUTE_ABI,
          functionName: 'execute',
          args: [encoded.commands, encoded.inputs, deadline],
          value: encoded.value,
        })
      }
      await readClient.waitForTransactionReceipt({ hash })
      setTxHash(hash)
      setStatus(`Swap confirmed · ${hash.slice(0, 10)}…`)
    } catch (e) {
      setStatus(parseContractError(e))
    } finally {
      setPendingLeg(null)
    }
  }, [
    v4.universalRouter,
    readClient,
    route,
    hasPreview,
    minOut,
    nativeIn,
    writeContractAsync,
    sendTransactionAsync,
    quotePick,
    uniQuote,
  ])

  const flip = useCallback(() => {
    setTokenIn(tokenOut)
    setTokenOut(tokenIn)
    setAmountIn('')
  }, [tokenIn, tokenOut])

  const hookedHops = route?.hops.filter((h) => !isZeroHook(h.pool.hooks)).length ?? 0
  const explorerBase =
    selectedChainId === CHAIN_ID_ROBINHOOD
      ? robinhood.blockExplorers.default.url
      : robinhoodTestnet.blockExplorers.default.url

  return (
    <div className="mx-auto max-w-lg space-y-6">
        <section>
          <p className="text-xs font-mono uppercase tracking-[0.14em] text-[var(--accent,#4FD44B)]">Trade</p>
          <h1 className="mt-4 text-3xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)] md:text-4xl">
            Swap on Uniswap v4
          </h1>
          <p className="mt-4 max-w-xl text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
            Search any token, including by address. Routes use Uniswap Universal Router.
            IndexedEx hooks are included; Uniswap&apos;s app still skips some of them.
          </p>
        </section>

        <Card>
          <div className="space-y-3">
            <div className="rounded-2xl bg-[var(--surface-2,#1c2030)] p-4">
              <div className="flex items-center justify-between text-xs text-[var(--text-muted,#9aa3b2)]">
                <span>You pay</span>
                {balanceIn != null ? (
                  <button
                    type="button"
                    className="font-mono tabular-nums hover:text-[var(--text-primary,#EDEDED)]"
                    data-testid="swap-amount-in-max"
                    onClick={() => setAmountIn(formatUnits(balanceIn, inDecimals))}
                  >
                    Max {formatUnits(balanceIn, inDecimals)}
                  </button>
                ) : null}
              </div>
              <div className="mt-2 flex items-center gap-3">
                <input
                  data-testid="swap-amount-in-input"
                  value={amountIn}
                  onChange={(e) => setAmountIn(e.target.value)}
                  placeholder="0"
                  inputMode="decimal"
                  className="min-w-0 flex-1 bg-transparent text-3xl font-medium tabular-nums text-[var(--text-primary,#EDEDED)] outline-none"
                />
                <TokenSelect
                  tokens={searchTokens}
                  value={tokenIn}
                  onChange={setTokenIn}
                  onImport={(t) => setImported((prev) => prev.concat(t))}
                  readClient={readClient}
                  data-testid="swap-token-in-select"
                />
              </div>
            </div>

            <div className="flex justify-center">
              <Button size="sm" variant="secondary" onClick={flip} data-testid="swap-flip">
                Reverse
              </Button>
            </div>

            <div className="rounded-2xl bg-[var(--surface-2,#1c2030)] p-4">
              <div className="text-xs text-[var(--text-muted,#9aa3b2)]">You receive</div>
              <div className="mt-2 flex items-center gap-3">
                <p
                  className="min-w-0 flex-1 font-mono text-3xl font-medium tabular-nums text-[var(--text-primary,#EDEDED)]"
                  data-testid="swap-amount-out"
                >
                  {quoteLoading
                    ? '…'
                    : quotedOut != null
                      ? formatUnits(quotedOut, outDecimals)
                      : '0'}
                </p>
                <TokenSelect
                  tokens={searchTokens}
                  value={tokenOut}
                  onChange={setTokenOut}
                  onImport={(t) => setImported((prev) => prev.concat(t))}
                  readClient={readClient}
                  data-testid="swap-token-out-select"
                />
              </div>
              {hasPreview ? (
                <p className="mt-2 text-[11px] text-[var(--text-muted,#9aa3b2)]">
                  Min received ({slippage}% slip): {formatUnits(minOut, outDecimals)}
                  {impactBps != null && impactBps < 2500 && formatPriceImpact(impactBps)
                    ? ` · Impact ${formatPriceImpact(impactBps)}`
                    : ''}
                </p>
              ) : null}
            </div>

            <div className="rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-0,#0a0a0a)] px-3 py-2 text-xs text-[var(--text-muted,#9aa3b2)]">
              {poolsLoading ? (
                <p>Looking up live Uniswap v4 pools…</p>
              ) : (
                <p data-testid="swap-pool-count">
                  {pools.length} live pool{pools.length === 1 ? '' : 's'} ·{' '}
                  {pools.filter((p) => !isZeroHook(p.hooks)).length} with a hook
                  {quotePick === 'uniswap' ? ' · Uniswap router' : quotePick === 'local' ? ' · IndexedEx router' : ''}
                </p>
              )}
              {route ? (
                <ol className="mt-2 space-y-1" data-testid="swap-route">
                  {route.hops.map((hop, i) => (
                    <li key={`${i}-${hop.pool.hooks}`}>
                      {i + 1}. {hopLabel(hop.pool, tokenNames)}
                    </li>
                  ))}
                </ol>
              ) : null}
              {hookedHops > 0 ? (
                <p className="mt-2 text-[var(--accent,#4FD44B)]">
                  This route uses {hookedHops} hooked pool{hookedHops === 1 ? '' : 's'}.
                </p>
              ) : null}
              {!poolsLoading && pools.length > 0 ? (
                <div className="mt-2 flex flex-wrap gap-1" data-testid="swap-live-pools">
                  {pools
                    .filter((p) => {
                      const known = (addr: Address) =>
                        searchTokens.some((t) => sameAddress(t.address, addr))
                      if (!known(p.currency0) || !known(p.currency1)) return false
                      const a = tokenInAddress
                      const b = tokenOutAddress
                      if (!a && !b) return isZeroHook(p.hooks)
                      const hitA = a
                        ? sameAddress(p.currency0, a) || sameAddress(p.currency1, a)
                        : false
                      const hitB = b
                        ? sameAddress(p.currency0, b) || sameAddress(p.currency1, b)
                        : false
                      return hitA || hitB
                    })
                    .slice(0, 8)
                    .map((p) => (
                    <button
                      key={poolKeyId(p)}
                      type="button"
                      className="rounded border border-[var(--border-subtle,rgba(255,255,255,0.08))] px-1.5 py-0.5 text-[10px] hover:border-[var(--border-accent,rgba(79,212,75,0.45))]"
                      onClick={() => {
                        const toOption = (addr: Address) => {
                          if (addr.toLowerCase() === ZERO_ADDRESS) return ETH
                          const match = searchTokens.find((t) => sameAddress(t.address, addr))
                          return match ? String(match.value) : addr
                        }
                        setTokenIn(toOption(p.currency0))
                        setTokenOut(toOption(p.currency1))
                      }}
                    >
                      {hopLabel(p, tokenNames)}
                    </button>
                  ))}
                </div>
              ) : null}
            </div>

            {quoteError ? (
              <p className="text-sm text-[var(--danger,#E6386A)]">{quoteError}</p>
            ) : null}
            {poolsError ? (
              <p className="text-sm text-[var(--danger,#E6386A)]">{poolsError}</p>
            ) : null}

            <ActionCta
              gate={gate}
              pendingLeg={effectiveSwapPendingLeg}
              onConnect={handleConnect}
              onSwitchNetwork={() => void handleSwitch()}
              onApproveTokenPermit2={() => void handleIssuePermit2Approval()}
              onApprovePermit2Router={() => void handleIssueRouterApproval()}
              onExecute={() => void handleSwap()}
              data-testid="swap-submit"
              className="w-full"
            />

            {status ? (
              <p className="text-sm text-[var(--text-muted,#9aa3b2)]" data-testid="swap-status">
                {status}
                {txHash ? (
                  <>
                    {' '}
                    <a
                      className="underline underline-offset-2"
                      href={`${explorerBase}/tx/${txHash}`}
                      target="_blank"
                      rel="noreferrer"
                    >
                      View on explorer
                    </a>
                  </>
                ) : null}
              </p>
            ) : null}

            <button
              type="button"
              className="text-xs text-[var(--text-muted,#9aa3b2)] underline-offset-2 hover:underline"
              onClick={() => setShowAdvanced((v) => !v)}
            >
              {showAdvanced ? 'Hide advanced' : 'Advanced'}
            </button>
            {showAdvanced ? (
              <div className="space-y-3 border-t border-[var(--border-subtle,rgba(255,255,255,0.08))] pt-3">
                <SlippageInput value={slippage} onChange={setSlippage} />
                <label className="block text-xs text-[var(--text-muted,#9aa3b2)]">
                  Extra hook addresses
                  <input
                    value={extraHooksRaw}
                    onChange={(e) => setExtraHooksRaw(e.target.value)}
                    placeholder="0x… (optional, comma-separated)"
                    className="mt-1 w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 font-mono text-xs text-[var(--text-primary,#EDEDED)]"
                  />
                </label>
                <p className="text-[11px] text-[var(--text-muted,#9aa3b2)]">
                  Paste a hook to include its pools for listed tokens. Vanilla Uniswap pools
                  (no hook) are always considered.
                </p>
                <label className="block text-xs text-[var(--text-muted,#9aa3b2)]">
                  Approval
                  <select
                    value={approvalMode}
                    onChange={(e) => setApprovalMode(e.target.value as 'explicit' | 'signed')}
                    className="mt-1 w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm"
                  >
                    <option value="explicit">Explicit (token then Permit2)</option>
                    <option value="signed">Token → Permit2 only</option>
                  </select>
                </label>
              </div>
            ) : null}
          </div>
        </Card>
    </div>
  )
}

export default function SwapPage() {
  return (
    <Suspense fallback={<p className="px-4 text-sm text-[var(--text-muted,#9aa3b2)]">Loading swap…</p>}>
      <SwapPageInner />
    </Suspense>
  )
}
