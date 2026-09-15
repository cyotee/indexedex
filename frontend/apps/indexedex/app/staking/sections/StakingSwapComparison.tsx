'use client'

import { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useAccount, usePublicClient, useSwitchChain, useWalletClient } from 'wagmi'
import { useConnectModal } from '@rainbow-me/rainbowkit'
import { encodeFunctionData, erc20Abi, formatUnits, publicActions, type Address, type Hex, type PublicClient } from 'viem'
import { getAddressArtifacts, type DeploymentEnvironment } from '@indexedex/protocol/addressArtifacts'
import { AmountField } from '../../components/ui/AmountField'
import { Button } from '../../components/ui/Button'
import { computeMinAmountOut } from '../../lib/earn/computeMinAmountOut'
import { parseContractError } from '../../lib/tx/parseContractError'
import { encodeUniversalSwap, UNIVERSAL_ROUTER_EXECUTE_ABI } from '../../swap/lib/v4Encode'
import { toPoolId } from '../../swap/lib/v4PoolId'
import { sameAddress } from '../../swap/lib/v4Types'
import { getSwapMarket, isSwapQuoteFresh, loadSwapComparison, parseSwapAmount, permitAllowanceAbi, quoteComparisonPool, readSwapAllowance, swapDeadline, type ReserveSettlement, type SwapDirection, type SwapPool } from '../lib/swapComparison'

type Props = { chainId: number; environment: DeploymentEnvironment; staking: Address; detf?: Address; mode?: 'comparison' | 'detf' }
type PendingSwap = { pool: SwapPool; hash: Hex; chainId: number; account: Address; to: Address; data: Hex; value: bigint; step: string }
const names = { base: 'Base pool', reserve: 'Reserve pool', detf: 'DTF-DETF reserve' } as const

export default function StakingSwapComparison({ chainId, environment, staking, detf, mode = 'comparison' }: Props) {
  const isDetf = mode === 'detf'
  const visiblePools: SwapPool[] = isDetf ? ['detf'] : ['base', 'reserve']
  const wallet = useAccount()
  const { data: walletClient } = useWalletClient({ chainId })
  const readClient = usePublicClient({ chainId }) as PublicClient | undefined
  const { openConnectModal } = useConnectModal()
  const { switchChainAsync } = useSwitchChain()
  const queryClient = useQueryClient()
  const [amount, setAmount] = useState('')
  const [direction, setDirection] = useState<SwapDirection>(isDetf ? 'sell' : 'buy')
  const [settlement, setSettlement] = useState<ReserveSettlement>('eth')
  const [slippage, setSlippage] = useState(0.5)
  const [activePool, setActivePool] = useState<SwapPool | null>(null)
  const [status, setStatus] = useState<{ pool: SwapPool; text: string } | null>(null)
  const [transaction, setTransaction] = useState<PendingSwap | null>(null)
  const [unknownReceipt, setUnknownReceipt] = useState(false)
  const pending = useRef<PendingSwap | null>(null)
  const mutex = useRef(false)
  const mounted = useRef(true)
  useEffect(() => { mounted.current = true; return () => { mounted.current = false } }, [])

  const wrongNetwork = wallet.isConnected && wallet.chainId !== chainId
  const bindingScope = `${chainId}:${environment}:${staking}:${detf ?? ''}:${wallet.address ?? ''}:${wallet.chainId}:${wallet.connector?.uid}:${wallet.status}`
  const scope = `${bindingScope}:${mode}:execution-quotes-v2`
  const platform = useMemo(() => getAddressArtifacts(chainId, environment).platform as Record<string, unknown>, [chainId, environment])
  const poolsQuery = useQuery({
    queryKey: ['staking-swap', bindingScope, 'pools-v3'],
    queryFn: () => loadSwapComparison(readClient!, staking, detf!, platform),
    enabled: !!readClient && !!detf && !wrongNetwork, retry: false, staleTime: 30_000,
  })
  const pools = poolsQuery.data
  const market = pools ? getSwapMarket(pools, isDetf ? 'detf' : 'base', direction, settlement) : undefined
  const intent = `${scope}:${settlement}:${direction}:${amount}:${slippage}:${pools ? visiblePools.map(pool => toPoolId(getSwapMarket(pools, pool, direction, settlement).poolKey)).join(':') : ''}`
  const currentIntent = useRef(intent)
  useLayoutEffect(() => { currentIntent.current = intent }, [intent])
  const parsed = market ? parseSwapAmount(amount, market.inDecimals) : undefined
  const [debouncedIntent, setDebouncedIntent] = useState('')
  useEffect(() => {
    const timer = setTimeout(() => setDebouncedIntent(intent), 250)
    return () => clearTimeout(timer)
  }, [intent])
  const canQuote = !!readClient && !!pools && !!parsed && !wrongNetwork && intent === debouncedIntent
  const baseQuote = useQuery({
    queryKey: ['staking-swap', scope, 'quote', 'base', intent],
    queryFn: async () => ({ route: await quoteComparisonPool(readClient!, pools!, 'base', direction, parsed!, wallet.address), intent }),
    enabled: canQuote && !isDetf, retry: false, refetchInterval: 15_000,
  })
  const reserveQuote = useQuery({
    queryKey: ['staking-swap', scope, 'quote', 'reserve', intent],
    queryFn: async () => ({ route: await quoteComparisonPool(readClient!, pools!, 'reserve', direction, parsed!, wallet.address), intent }),
    enabled: canQuote && !isDetf, retry: false, refetchInterval: 15_000,
  })
  const detfQuote = useQuery({
    queryKey: ['staking-swap', scope, 'quote', 'detf', intent],
    queryFn: async () => ({ route: await quoteComparisonPool(readClient!, pools!, 'detf', direction, parsed!, wallet.address, settlement), intent }),
    enabled: canQuote && isDetf, retry: false, refetchInterval: 15_000,
  })
  const allowance = useQuery({
    queryKey: ['staking-swap', scope, 'allowance', market?.payToken, parsed?.toString()],
    queryFn: () => readSwapAllowance(readClient!, pools!, wallet.address!, market!.payToken, parsed!),
    enabled: !!readClient && !!pools && !!market && !!wallet.address && !!parsed && !wrongNetwork,
    retry: false, refetchInterval: 10_000,
  })
  const quotes = { base: baseQuote, reserve: reserveQuote, detf: detfQuote }
  const busy = activePool !== null || unknownReceipt
  const assetSymbol = isDetf ? 'DTF-DETF' : 'DTF'
  const counterSymbol = isDetf && settlement === 'dtf' ? 'DTF' : 'ETH'
  const paySymbol = market?.paySymbol ?? (direction === 'buy' ? counterSymbol : assetSymbol)
  const receiveSymbol = market?.receiveSymbol ?? (direction === 'buy' ? assetSymbol : counterSymbol)
  const payDecimals = market?.inDecimals ?? (isDetf && direction === 'sell' ? 9 : 18)
  const receiveDecimals = market?.outDecimals ?? (isDetf && direction === 'buy' ? 9 : 18)
  const ready = (pool: SwapPool) => canQuote && !quotes[pool].isFetching && !quotes[pool].isError && quotes[pool].data?.intent === intent
  const refresh = () => queryClient.invalidateQueries({ queryKey: ['staking-swap'] })

  async function confirm(record: PendingSwap) {
    try {
      if (!walletClient || await walletClient.getChainId() !== record.chainId) {
        setUnknownReceipt(true)
        setStatus({ pool: record.pool, text: 'Return to the transaction network to check confirmation.' })
        return
      }
      const client = walletClient.extend(publicActions)
      const receipt = await client.waitForTransactionReceipt({
        hash: record.hash, timeout: 120_000,
        onReplaced: ({ transaction: replacement }) => {
          record = { ...record, hash: replacement.hash }
          pending.current = record
          if (mounted.current) setTransaction(record)
        },
      })
      const actual = await client.getTransaction({ hash: receipt.transactionHash })
      const matches = actual.to && sameAddress(actual.to, record.to) && sameAddress(actual.from, record.account) && actual.input === record.data && actual.value === record.value
      pending.current = null
      if (mounted.current) {
        setUnknownReceipt(false)
        setStatus({ pool: record.pool, text: receipt.status === 'success' && matches ? `${record.step} confirmed.` : 'Transaction reverted or was replaced. No swap success was recorded.' })
        void refresh()
      }
    } catch {
      if (mounted.current) {
        setUnknownReceipt(true)
        setStatus({ pool: record.pool, text: 'Transaction submitted; confirmation is unavailable. Check confirmation before trying again.' })
      }
    }
  }

  async function act(pool: SwapPool) {
    if (mutex.current || pending.current) return
    if (!wallet.isConnected) { openConnectModal?.(); return }
    if (wrongNetwork) {
      try { await switchChainAsync({ chainId }) } catch (error) { setStatus({ pool, text: parseContractError(error) }) }
      return
    }
    const shown = quotes[pool].data
    const quoteTime = quotes[pool].dataUpdatedAt
    if (!ready(pool) || !shown || !pools || !market || !parsed || !wallet.address || !walletClient || !allowance.data) return
    const selectedMarket = getSwapMarket(pools, pool, direction, settlement)
    const minOut = computeMinAmountOut(shown.route.amountOut, slippage)
    if (minOut <= 0n) return
    mutex.current = true
    setActivePool(pool)
    setStatus({ pool, text: 'Checking the selected pool and wallet…' })
    const expectedIntent = intent
    const account = wallet.address
    let phase: 'preparation' | 'simulation' | 'submission' = 'preparation'
    const client = walletClient.extend(publicActions) as unknown as PublicClient
    const guard = async () => {
      const [actualChain, accounts] = await Promise.all([walletClient.getChainId(), walletClient.getAddresses()])
      if (!mounted.current || currentIntent.current !== expectedIntent || actualChain !== chainId || !accounts[0] || !sameAddress(accounts[0], account)) {
        throw new Error('Wallet or swap details changed. Review both quotes before continuing.')
      }
    }
    try {
      await guard()
      const freshAllowance = await readSwapAllowance(client, pools, account, selectedMarket.payToken, parsed)
      await guard()
      if (freshAllowance.balance < parsed) throw new Error(`Insufficient ${paySymbol} balance.`)
      if (freshAllowance.step !== allowance.data.step) throw new Error('Approval state changed. Review the updated action and try again.')
      const block = await client.getBlock()
      const deadline = swapDeadline(block.timestamp)
      await guard()
      let to: Address
      let data: Hex
      let value = 0n
      let step: string
      if (freshAllowance.step === 'token') {
        if (!selectedMarket.payToken) throw new Error('Native ETH does not require token approval.')
        to = selectedMarket.payToken
        data = encodeFunctionData({ abi: erc20Abi, functionName: 'approve', args: [pools.permit2, parsed] })
        step = `${paySymbol} approval`
      } else if (freshAllowance.step === 'permit') {
        to = pools.permit2
        if (!selectedMarket.payToken) throw new Error('Native ETH does not require swap permission.')
        data = encodeFunctionData({ abi: permitAllowanceAbi, functionName: 'approve', args: [selectedMarket.payToken, pools.router, parsed, Number(deadline)] })
        step = 'Swap permission'
      } else {
        if (!isSwapQuoteFresh(quoteTime)) throw new Error('This quote expired. Refresh both quotes and review them again.')
        const fresh = await quoteComparisonPool(client, pools, pool, direction, parsed, account, settlement)
        await guard()
        if (fresh.amountOut < minOut) throw new Error('The quote moved beyond your slippage limit. Refresh and review it again.')
        const encoded = encodeUniversalSwap({ route: fresh, amountOutMinimum: minOut, nativeIn: selectedMarket.nativeIn, nativeOut: selectedMarket.nativeOut, wrappedNative: pools.weth, prepayInput: pool === 'detf' })
        to = pools.router
        data = encodeFunctionData({ abi: UNIVERSAL_ROUTER_EXECUTE_ABI, functionName: 'execute', args: [encoded.commands, encoded.inputs, deadline] })
        value = encoded.value
        step = `${names[pool]} swap`
      }
      // Simulate the complete exact calldata, including native value and the reviewed minimum.
      phase = 'simulation'
      await client.call({ account, to, data, value })
      await guard()
      if (freshAllowance.step === 'swap' && !isSwapQuoteFresh(quoteTime)) {
        throw new Error('This quote expired during preparation. Refresh and review both quotes.')
      }
      setStatus({ pool, text: `Confirm ${step.toLowerCase()} in your wallet.` })
      phase = 'submission'
      const hash = await walletClient.sendTransaction({ account, chain: walletClient.chain, to, data, value })
      const record: PendingSwap = { pool, hash, chainId, account, to, data, value, step }
      pending.current = record
      if (mounted.current) { setTransaction(record); setStatus({ pool, text: 'Transaction submitted. Waiting for confirmation…' }) }
      await confirm(record)
    } catch (error) {
      if (mounted.current) {
        const reason = parseContractError(error)
        const text = phase === 'submission' ? reason
          : `${phase === 'simulation' ? 'Simulation' : 'Transaction preparation'} failed. No new transaction was submitted. ${reason}`
        setStatus({ pool, text })
        void refresh()
      }
    } finally {
      mutex.current = false
      if (mounted.current) setActivePool(null)
    }
  }

  async function checkConfirmation() {
    if (mutex.current || !pending.current) return
    mutex.current = true
    setActivePool(pending.current.pool)
    try { await confirm(pending.current) } finally { mutex.current = false; setActivePool(null) }
  }

  function label(pool: SwapPool) {
    if (!wallet.isConnected) return 'Connect wallet'
    if (wrongNetwork) return 'Switch network'
    if (busy) return activePool === pool ? 'Waiting for confirmation…' : 'Transaction in progress'
    if (!parsed) return 'Enter an amount'
    if (!ready(pool)) return quotes[pool].isError ? 'Quote unavailable' : 'Getting quote…'
    if (!allowance.data || allowance.isError) return 'Checking balance and approvals…'
    if (allowance.data.balance < parsed) return `Insufficient ${paySymbol}`
    return allowance.data.step === 'token' ? `Approve ${paySymbol}` : allowance.data.step === 'permit' ? `Allow ${paySymbol} swaps` : isDetf ? `Swap ${paySymbol} for ${receiveSymbol}` : `Swap via ${names[pool].toLowerCase()}`
  }

  const headingId = isDetf ? 'staking-detf-swap-heading' : 'staking-swap-heading'
  return <section className="mt-6 space-y-4" aria-labelledby={headingId} data-testid={isDetf ? 'staking-detf-swap' : 'staking-swap-comparison'}>
    <div className="flex flex-wrap items-end justify-between gap-3">
      <div>
        <h2 id={headingId} className="text-xl font-semibold">{isDetf ? 'Swap DTF-DETF' : 'Compare DTF swaps'}</h2>
        <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)]">{isDetf ? 'Trade wallet-held DTF-DETF through the reserve pool. Unstake sDETF first if needed.' : 'Enter an amount in either panel to compare the same trade. Choose which pool to use.'}</p>
      </div>
      {isDetf ? <label className="text-xs text-[var(--text-muted,#9aa3b2)]">{direction === 'sell' ? 'Receive asset' : 'Pay with'}
        <select aria-label="DTF-DETF trading asset" data-testid="staking-detf-settlement" className="ml-2 rounded-lg border border-[var(--border-subtle)] bg-[var(--surface-2)] p-2" value={settlement} disabled={busy} onChange={event => {
          if (event.target.value !== 'eth' && event.target.value !== 'dtf') return
          setSettlement(event.target.value)
          if (direction === 'buy') setAmount('')
          setStatus(null)
        }}><option value="eth">ETH</option><option value="dtf">DTF</option></select>
      </label> : null}
      <label className="text-xs text-[var(--text-muted,#9aa3b2)]">Slippage
        <select aria-label={isDetf ? 'DTF-DETF swap slippage' : 'Swap comparison slippage'} className="ml-2 rounded-lg border border-[var(--border-subtle)] bg-[var(--surface-2)] p-2" value={slippage} disabled={busy} onChange={event => setSlippage(Number(event.target.value))}>
          {[0.1, 0.5, 1, 2, 5].map(value => <option key={value} value={value}>{value}%</option>)}
        </select>
      </label>
    </div>
    {poolsQuery.isError ? <p role="alert" className="text-sm">{parseContractError(poolsQuery.error)} <Button size="sm" onClick={() => void poolsQuery.refetch()}>Retry pool lookup</Button></p> : null}
    <div className={`grid gap-4 ${isDetf ? '' : 'md:grid-cols-2'}`}>
      {visiblePools.map(pool => {
        const quote = quotes[pool]
        const out = ready(pool) ? quote.data?.route.amountOut : undefined
        const other = pool === 'base' ? 'reserve' : 'base'
        const better = !isDetf && out && ready(other) && quotes[other].data && out > quotes[other].data!.route.amountOut
        const disabled = busy || (wallet.isConnected && !wrongNetwork && (!parsed || !ready(pool) || !allowance.data || allowance.isError || allowance.data.balance < parsed || computeMinAmountOut(out, slippage) <= 0n))
        const poolId = pools ? toPoolId(getSwapMarket(pools, pool, direction, settlement).poolKey) : undefined
        return <div key={pool} className="min-w-0 rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#111827)] p-4" data-testid={`staking-swap-${pool}`} data-pool-id={poolId}>
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h3 className="font-semibold">{names[pool]}</h3>
            {better ? <span className="rounded-full bg-[var(--accent,#4FD44B)]/10 px-2 py-1 text-xs text-[var(--accent,#4FD44B)]">Higher quote</span> : null}
          </div>
          <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">{pool === 'detf' ? `DTF-DETF / ${counterSymbol} · reserve swap${settlement === 'eth' ? '; ETH wraps or unwraps in the swap' : ''}` : pool === 'base' ? 'DTF / ETH · original pool' : 'DTF / WETH · reserve pool; ETH wraps or unwraps in the swap'}</p>
          <label className="mt-4 block text-xs">{isDetf ? 'Direction' : 'Pay token'}
            <select aria-label={`${names[pool]} pay token`} data-testid={`staking-swap-${pool}-direction`} value={direction} disabled={busy} onChange={event => { setDirection(event.target.value as SwapDirection); setAmount(''); setStatus(null) }} className="mt-1 w-full rounded-lg border border-[var(--border-subtle)] bg-[var(--surface-2,#1c2030)] p-2 text-sm">
              <option value="buy">{counterSymbol} → {assetSymbol}</option><option value="sell">{assetSymbol} → {counterSymbol}</option>
            </select>
          </label>
          <AmountField className="mt-3" label="You pay" symbol={paySymbol} value={amount} decimals={payDecimals} onChange={value => { setAmount(value); setStatus(null) }} disabled={busy} data-testid={`staking-swap-${pool}-amount`} />
          {wallet.isConnected && !wrongNetwork && allowance.data ? <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">Balance: {formatUnits(allowance.data.balance, payDecimals)} {paySymbol}</p> : null}
          <div className="mt-4 rounded-lg bg-[var(--surface-2,#1c2030)] p-3" aria-live="polite">
            <p className="text-xs text-[var(--text-muted,#9aa3b2)]">Estimated receive</p>
            <p className="mt-1 break-all font-mono text-lg tabular-nums" data-testid={`staking-swap-${pool}-quote`}>{out != null ? formatUnits(out, receiveDecimals) : '—'} <span className="text-sm">{receiveSymbol}</span></p>
            <p className="mt-2 text-xs text-[var(--text-muted,#9aa3b2)]">Minimum receive</p>
            <p className="mt-1 break-all font-mono text-xs text-[var(--text-muted,#9aa3b2)]">{out != null ? formatUnits(computeMinAmountOut(out, slippage), receiveDecimals) : '—'} {receiveSymbol}</p>
          </div>
          {quote.isError && canQuote ? <p role="alert" className="mt-2 text-xs">{parseContractError(quote.error)}</p> : null}
          <Button className="mt-4 w-full" disabled={disabled} data-testid={`staking-swap-${pool}-action`} onClick={() => void act(pool)}>{label(pool)}</Button>
          <Button variant="ghost" size="sm" className="mt-2" disabled={busy || !canQuote} onClick={() => void refresh()}>{isDetf ? 'Refresh quote' : 'Refresh quotes'}</Button>
          {status?.pool === pool ? <p role="status" className="mt-2 break-words text-xs" data-testid={`staking-swap-${pool}-status`}>{status.text}</p> : null}
          {transaction?.pool === pool ? <p className="mt-2 break-all text-[10px]">Last submitted transaction: {transaction.step}. <span className="font-mono" data-testid={`staking-swap-${pool}-tx`}>{transaction.hash}</span></p> : null}
          {unknownReceipt && transaction?.pool === pool ? <Button size="sm" variant="secondary" disabled={activePool !== null} onClick={() => void checkConfirmation()}>Check confirmation</Button> : null}
          {poolId ? <details className="mt-2 text-[10px] text-[var(--text-muted,#9aa3b2)]"><summary className="cursor-pointer">Pool ID</summary><p className="break-all font-mono">{poolId}</p></details> : null}
        </div>
      })}
    </div>
    <p className="text-xs text-[var(--text-muted,#9aa3b2)]">Quotes include pool fees, not network gas. Each button follows the route shown. Swapping does not stake your tokens.</p>
  </section>
}
