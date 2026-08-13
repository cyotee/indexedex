'use client'

/**
 * Pons-style launch token buy/sell page (v1: Uniswap V3 WETH pool from day one).
 * Appearance mirrors common ponsfamily listing layout: identity header, graduation bar, trade card.
 */

import Link from 'next/link'
import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  useAccount,
  useBalance,
  useBlockNumber,
  usePublicClient,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
} from 'wagmi'
import { erc20Abi, formatEther, formatUnits, parseEther, parseUnits } from 'viem'

import { AddressLink } from '../components/ui/AddressLink'
import { Badge } from '../components/ui/Badge'
import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { PageHeader } from '../components/ui/PageHeader'
import { Stat } from '../components/ui/Stat'
import WalletStatusBanner from '../components/WalletStatusBanner'
import useChainResolution from '../lib/hooks/useChainResolution'
import {
  getPonsLaunchArtifact,
  PONS_FACTORY_ABI,
  priceTokenInWethFromSqrt,
  SWAP_ROUTER02_EXACT_IN_ABI,
  UNI_V3_POOL_SLOT0_ABI,
  WETH_ABI,
  type PonsLaunchArtifact,
} from '../lib/pons/launchArtifact'
import { CHAIN_ID_ROBINHOOD } from '@indexedex/protocol/addressArtifacts'
import { parseContractError } from '../lib/tx/parseContractError'

type Side = 'buy' | 'sell'

function shortAddr(a: string) {
  return `${a.slice(0, 6)}…${a.slice(-4)}`
}

function clampPct(n: number) {
  if (!Number.isFinite(n)) return 0
  return Math.max(0, Math.min(100, n))
}

export default function TokenLaunchClient() {
  const launch = useMemo(() => getPonsLaunchArtifact(), [])
  const chain = useChainResolution(CHAIN_ID_ROBINHOOD)
  const { address, isConnected } = useAccount()
  const publicClient = usePublicClient({ chainId: chain.dataChainId })
  const { data: blockNumber } = useBlockNumber({ chainId: chain.dataChainId, watch: true })

  const [side, setSide] = useState<Side>('buy')
  const [amountIn, setAmountIn] = useState('')
  const [slippagePct, setSlippagePct] = useState('5')
  const [status, setStatus] = useState('')
  const [txHash, setTxHash] = useState<`0x${string}` | undefined>()

  const { writeContractAsync, isPending } = useWriteContract()
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash: txHash,
    chainId: chain.dataChainId,
  })

  useEffect(() => {
    if (isConfirmed && txHash) {
      setStatus(`Confirmed ${shortAddr(txHash)}`)
      setAmountIn('')
    }
  }, [isConfirmed, txHash])

  if (!launch) {
    return (
      <div className="max-w-4xl mx-auto">
        <PageHeader
          title="Token launch"
          subtitle="No pons launch artifact found for this build."
        />
        <Card>
          <p className="text-sm text-[var(--text-muted,#9aa3b2)]">
            Run the launch-only script, then hard-refresh:
          </p>
          <pre className="mt-3 overflow-x-auto rounded-lg bg-black/40 p-3 text-xs text-[var(--text-primary,#EDEDED)]">
            {`DEV_ADDRESS=0xf39F… PRIVATE_KEY=0xac09… \\
  ./scripts/shell/pons_launch_rich.sh
# writes frontend/.../chain/4663/pons-launch.json`}
          </pre>
        </Card>
      </div>
    )
  }

  return (
    <LaunchTradeSurface
      launch={launch}
      chain={chain}
      address={address}
      isConnected={isConnected}
      publicClient={publicClient}
      blockNumber={blockNumber}
      side={side}
      setSide={setSide}
      amountIn={amountIn}
      setAmountIn={setAmountIn}
      slippagePct={slippagePct}
      setSlippagePct={setSlippagePct}
      status={status}
      setStatus={setStatus}
      txHash={txHash}
      setTxHash={setTxHash}
      writeContractAsync={writeContractAsync}
      isPending={isPending || isConfirming}
    />
  )
}

function LaunchTradeSurface({
  launch,
  chain,
  address,
  isConnected,
  publicClient,
  blockNumber,
  side,
  setSide,
  amountIn,
  setAmountIn,
  slippagePct,
  setSlippagePct,
  status,
  setStatus,
  txHash,
  setTxHash,
  writeContractAsync,
  isPending,
}: {
  launch: PonsLaunchArtifact
  chain: ReturnType<typeof useChainResolution>
  address: `0x${string}` | undefined
  isConnected: boolean
  publicClient: ReturnType<typeof usePublicClient>
  blockNumber: bigint | undefined
  side: Side
  setSide: (s: Side) => void
  amountIn: string
  setAmountIn: (v: string) => void
  slippagePct: string
  setSlippagePct: (v: string) => void
  status: string
  setStatus: (v: string) => void
  txHash: `0x${string}` | undefined
  setTxHash: (h: `0x${string}` | undefined) => void
  writeContractAsync: ReturnType<typeof useWriteContract>['writeContractAsync']
  isPending: boolean
}) {
  const token = launch.token
  const weth = launch.weth
  const chainId = chain.dataChainId

  const { data: ethBal } = useBalance({ address, chainId })
  const { data: wethBal } = useReadContract({
    address: weth,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    chainId,
    query: { enabled: !!address },
  })
  const { data: tokenBal } = useReadContract({
    address: token,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    chainId,
    query: { enabled: !!address },
  })
  const { data: tokenName } = useReadContract({
    address: token,
    abi: erc20Abi,
    functionName: 'name',
    chainId,
  })
  const { data: tokenSymbol } = useReadContract({
    address: token,
    abi: erc20Abi,
    functionName: 'symbol',
    chainId,
  })

  const { data: graduation } = useReadContract({
    address: launch.factory,
    abi: PONS_FACTORY_ABI,
    functionName: 'graduationStatus',
    args: [token],
    chainId,
  })

  const { data: slot0 } = useReadContract({
    address: launch.pool,
    abi: UNI_V3_POOL_SLOT0_ABI,
    functionName: 'slot0',
    chainId,
  })
  const { data: poolLiq } = useReadContract({
    address: launch.pool,
    abi: UNI_V3_POOL_SLOT0_ABI,
    functionName: 'liquidity',
    chainId,
  })
  const { data: poolToken0 } = useReadContract({
    address: launch.pool,
    abi: UNI_V3_POOL_SLOT0_ABI,
    functionName: 'token0',
    chainId,
  })

  const displayName = (typeof tokenName === 'string' && tokenName) || launch.name
  const displaySymbol = (typeof tokenSymbol === 'string' && tokenSymbol) || launch.symbol

  const tokenIsToken0 = useMemo(() => {
    if (typeof poolToken0 === 'string') {
      return poolToken0.toLowerCase() === token.toLowerCase()
    }
    return launch.isToken0
  }, [poolToken0, token, launch.isToken0])

  const priceWeth = useMemo(() => {
    const sqrt = Array.isArray(slot0) ? (slot0[0] as bigint) : undefined
    if (sqrt === undefined) return null
    return priceTokenInWethFromSqrt(sqrt, tokenIsToken0)
  }, [slot0, tokenIsToken0])

  const paired = graduation ? (graduation[0] as bigint) : BigInt(0)
  const threshold = graduation ? (graduation[1] as bigint) : BigInt(0)
  const graduated = graduation ? Boolean(graduation[2]) : false
  const progressPct =
    threshold > BigInt(0) ? clampPct(Number((paired * BigInt(10000)) / threshold) / 100) : graduated ? 100 : 0

  const restrictionsEnd = launch.restrictionsEndBlock
  const block = blockNumber !== undefined ? Number(blockNumber) : 0
  const buysRestricted = restrictionsEnd > 0 && block > 0 && block <= restrictionsEnd

  const ethBalance = ethBal?.value ?? BigInt(0)
  const wethBalance = typeof wethBal === 'bigint' ? wethBal : BigInt(0)
  const tokenBalance = typeof tokenBal === 'bigint' ? tokenBal : BigInt(0)
  // Buy spends ETH that we wrap; show combined eth+weth as available pay.
  const buyPayBalance = ethBalance + wethBalance

  const payLabel = side === 'buy' ? 'ETH' : displaySymbol
  const receiveLabel = side === 'buy' ? displaySymbol : 'ETH'
  const payBalance = side === 'buy' ? buyPayBalance : tokenBalance

  const parsedIn = useMemo(() => {
    try {
      if (!amountIn || Number(amountIn) <= 0) return BigInt(0)
      return parseUnits(amountIn, 18)
    } catch {
      return BigInt(0)
    }
  }, [amountIn])

  const estOut = useMemo(() => {
    const oneE18 = BigInt('1000000000000000000')
    if (parsedIn === BigInt(0) || !priceWeth || priceWeth <= 0) return null
    // Rough mid estimate (not a quoter) — UI honesty: label as estimate.
    const priceWad = BigInt(Math.max(1, Math.floor(priceWeth * 1e18)))
    if (side === 'buy') {
      // amountIn WETH → tokens ≈ amountIn / price
      return (parsedIn * oneE18) / priceWad
    }
    // sell tokens → WETH ≈ amountIn * price
    return (parsedIn * priceWad) / oneE18
  }, [parsedIn, priceWeth, side])

  const onMax = () => {
    if (side === 'buy') {
      // leave gas headroom
      const headroom = parseEther('0.01')
      const avail = buyPayBalance > headroom ? buyPayBalance - headroom : BigInt(0)
      setAmountIn(formatEther(avail))
    } else {
      setAmountIn(formatUnits(tokenBalance, 18))
    }
  }

  const execute = useCallback(async () => {
    if (!address || !publicClient) {
      setStatus('Connect wallet on Robinhood (4663)')
      return
    }
    if (chain.isUnsupportedChain || !chain.walletMatchesDataChain) {
      setStatus('Switch wallet to Robinhood Anvil (chain 4663)')
      return
    }
    if (parsedIn === BigInt(0)) {
      setStatus('Enter an amount')
      return
    }
    if (side === 'buy' && buysRestricted) {
      setStatus(`Buys restricted until block ${restrictionsEnd} (now ${block || '…'})`)
      return
    }

    const slip = Math.min(50, Math.max(0.1, Number(slippagePct) || 5))
    const minOut =
      estOut && estOut > BigInt(0)
        ? (estOut * BigInt(Math.floor((100 - slip) * 100))) / BigInt(10000)
        : BigInt(0)

    try {
      setStatus('Submitting…')
      setTxHash(undefined)

      if (side === 'buy') {
        // Ensure WETH balance covers amountIn: wrap ETH if needed.
        let wethHave = wethBalance
        if (wethHave < parsedIn) {
          const need = parsedIn - wethHave
          if (ethBalance < need) {
            setStatus('Insufficient ETH')
            return
          }
          const wrapHash = await writeContractAsync({
            address: weth,
            abi: WETH_ABI,
            functionName: 'deposit',
            value: need,
            chainId,
          })
          await publicClient.waitForTransactionReceipt({ hash: wrapHash })
          wethHave = parsedIn
        }

        const allowance = (await publicClient.readContract({
          address: weth,
          abi: erc20Abi,
          functionName: 'allowance',
          args: [address, launch.swapRouter],
        })) as bigint
        if (allowance < parsedIn) {
          const apHash = await writeContractAsync({
            address: weth,
            abi: erc20Abi,
            functionName: 'approve',
            args: [launch.swapRouter, parsedIn],
            chainId,
          })
          await publicClient.waitForTransactionReceipt({ hash: apHash })
        }

        const hash = await writeContractAsync({
          address: launch.swapRouter,
          abi: SWAP_ROUTER02_EXACT_IN_ABI,
          functionName: 'exactInputSingle',
          args: [
            {
              tokenIn: weth,
              tokenOut: token,
              fee: launch.poolFee,
              recipient: address,
              amountIn: parsedIn,
              amountOutMinimum: minOut,
              sqrtPriceLimitX96: BigInt(0),
            },
          ],
          chainId,
        })
        setTxHash(hash)
        setStatus(`Buy submitted ${shortAddr(hash)}`)
      } else {
        // Sell token → WETH
        const allowance = (await publicClient.readContract({
          address: token,
          abi: erc20Abi,
          functionName: 'allowance',
          args: [address, launch.swapRouter],
        })) as bigint
        if (allowance < parsedIn) {
          const apHash = await writeContractAsync({
            address: token,
            abi: erc20Abi,
            functionName: 'approve',
            args: [launch.swapRouter, parsedIn],
            chainId,
          })
          await publicClient.waitForTransactionReceipt({ hash: apHash })
        }

        const hash = await writeContractAsync({
          address: launch.swapRouter,
          abi: SWAP_ROUTER02_EXACT_IN_ABI,
          functionName: 'exactInputSingle',
          args: [
            {
              tokenIn: token,
              tokenOut: weth,
              fee: launch.poolFee,
              recipient: address,
              amountIn: parsedIn,
              amountOutMinimum: minOut,
              sqrtPriceLimitX96: BigInt(0),
            },
          ],
          chainId,
        })
        setTxHash(hash)
        setStatus(`Sell submitted ${shortAddr(hash)}`)
      }
    } catch (e) {
      setStatus(parseContractError(e) || 'Transaction failed')
    }
  }, [
    address,
    publicClient,
    chain,
    parsedIn,
    side,
    buysRestricted,
    restrictionsEnd,
    block,
    slippagePct,
    estOut,
    wethBalance,
    ethBalance,
    writeContractAsync,
    weth,
    token,
    launch,
    chainId,
    setStatus,
    setTxHash,
  ])

  const avatarLetter = (displaySymbol || '?').slice(0, 1).toUpperCase()

  return (
    <div className="max-w-5xl mx-auto">
      <PageHeader
        title="Launch"
        subtitle="Buy and sell on the pons v1 locked Uniswap V3 pool (WETH pair). Same venue as the ponsfamily listing — addresses are the source of truth."
      />

      <WalletStatusBanner
        className="mb-4"
        isConnected={isConnected}
        isUnsupportedChain={chain.isUnsupportedChain}
        walletMatchesDataChain={chain.walletMatchesDataChain}
        attachedWalletChainId={chain.attachedWalletChainId}
        dataChainId={chain.dataChainId}
        environment={chain.environment}
      />

      {/* Identity header — pons listing style */}
      <Card className="mb-4 overflow-hidden">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div className="flex gap-4 items-start">
            <div
              className="flex h-16 w-16 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-[var(--accent,#4FD44B)]/30 to-sky-500/20 text-2xl font-bold text-[var(--text-primary,#EDEDED)] border border-white/10"
              aria-hidden
            >
              {avatarLetter}
            </div>
            <div>
              <div className="flex flex-wrap items-center gap-2">
                <h1 className="text-xl font-semibold text-[var(--text-primary,#EDEDED)]">
                  {displayName}
                </h1>
                <Badge tone="neutral">{displaySymbol}</Badge>
                <Badge tone="info">pons v1</Badge>
                {graduated ? <Badge tone="accent">Graduated</Badge> : (
                  <Badge tone="warning">Live pool</Badge>
                )}
              </div>
              <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)] max-w-xl">
                {launch.description || 'Trade against the locked WETH pool from launch.'}
              </p>
              <div className="mt-2 flex flex-wrap gap-3 text-xs text-[var(--text-muted,#9aa3b2)]">
                <span>
                  Token{' '}
                  <AddressLink chainId={chainId} address={token} />
                </span>
                <span>
                  Pool{' '}
                  <AddressLink chainId={chainId} address={launch.pool} />
                </span>
              </div>
            </div>
          </div>
          <div className="text-right text-sm">
            <div className="text-[11px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">
              Price (mid)
            </div>
            <div className="font-mono text-lg text-[var(--text-primary,#EDEDED)]">
              {priceWeth !== null && priceWeth > 0
                ? `${priceWeth < 1e-6 ? priceWeth.toExponential(3) : priceWeth.toPrecision(4)} WETH`
                : '—'}
            </div>
            <div className="text-xs text-[var(--text-muted,#9aa3b2)] mt-0.5">
              from pool slot0 · not a firm quote
            </div>
          </div>
        </div>

        {/* Graduation / paired progress */}
        <div className="mt-6">
          <div className="flex justify-between text-xs text-[var(--text-muted,#9aa3b2)] mb-1">
            <span>Paired WETH toward graduation</span>
            <span className="font-mono">
              {formatEther(paired)} / {threshold > BigInt(0) ? formatEther(threshold) : '—'} ETH
              {graduated ? ' · graduated' : ''}
            </span>
          </div>
          <div className="h-2.5 w-full overflow-hidden rounded-full bg-white/10">
            <div
              className="h-full rounded-full bg-[var(--accent,#4FD44B)] transition-all"
              style={{ width: `${progressPct}%` }}
            />
          </div>
          <p className="mt-1 text-[11px] text-[var(--text-muted,#9aa3b2)]">
            pons v1 keeps the same V3 pool after graduation — bar is paired principal vs threshold.
          </p>
        </div>
      </Card>

      {buysRestricted ? (
        <div className="mb-4 rounded-xl border border-amber-500/40 bg-amber-500/10 px-4 py-3 text-sm text-amber-100">
          Buy restrictions active until block <span className="font-mono">{restrictionsEnd}</span>
          {block ? (
            <>
              {' '}
              (current <span className="font-mono">{block}</span>). Creator-only / anti-snipe window —
              sells may still work; wait before buying.
            </>
          ) : null}
        </div>
      ) : null}

      <div className="grid grid-cols-1 lg:grid-cols-5 gap-4">
        {/* Stats column */}
        <div className="lg:col-span-2 space-y-3">
          <div className="grid grid-cols-2 gap-3">
            <Card padding="sm">
              <Stat
                label="Pool fee"
                value={`${(launch.poolFee / 10000).toFixed(2)}%`}
                hint={`fee tier ${launch.poolFee}`}
              />
            </Card>
            <Card padding="sm">
              <Stat
                label="Liquidity"
                value={poolLiq !== undefined ? String(poolLiq) : '—'}
                hint="V3 liquidity units"
              />
            </Card>
            <Card padding="sm">
              <Stat
                label="Your ETH"
                value={formatEther(ethBalance)}
                hint="native"
              />
            </Card>
            <Card padding="sm">
              <Stat
                label={`Your ${displaySymbol}`}
                value={formatUnits(tokenBalance, 18)}
              />
            </Card>
          </div>
          <Card padding="sm">
            <h3 className="text-xs uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">
              Venue
            </h3>
            <ul className="mt-2 space-y-1 text-xs text-[var(--text-muted,#9aa3b2)]">
              <li>
                Factory <AddressLink chainId={chainId} address={launch.factory} />
              </li>
              <li>
                Router <AddressLink chainId={chainId} address={launch.swapRouter} />
              </li>
              <li>
                WETH <AddressLink chainId={chainId} address={weth} />
              </li>
              <li>
                Explorer{' '}
                <a
                  className="text-[var(--accent,#4FD44B)] hover:underline"
                  href={`https://robinhoodchain.blockscout.com/address/${token}`}
                  target="_blank"
                  rel="noreferrer"
                >
                  Blockscout
                </a>
                {' · '}
                <a
                  className="text-[var(--accent,#4FD44B)] hover:underline"
                  href="https://ponsfamily.com/launchpad"
                  target="_blank"
                  rel="noreferrer"
                >
                  ponsfamily
                </a>
              </li>
            </ul>
          </Card>
        </div>

        {/* Trade card — pons listing centerpiece */}
        <div className="lg:col-span-3">
          <Card className="border-[var(--border-accent,rgba(79,212,75,0.25))]">
            <div className="flex rounded-lg bg-black/30 p-1 mb-4">
              {(['buy', 'sell'] as const).map((s) => (
                <button
                  key={s}
                  type="button"
                  onClick={() => setSide(s)}
                  className={[
                    'flex-1 rounded-md py-2 text-sm font-semibold capitalize transition-colors',
                    side === s
                      ? s === 'buy'
                        ? 'bg-[var(--accent,#4FD44B)] text-black'
                        : 'bg-rose-500 text-white'
                      : 'text-[var(--text-muted,#9aa3b2)] hover:text-[var(--text-primary,#EDEDED)]',
                  ].join(' ')}
                >
                  {s}
                </button>
              ))}
            </div>

            <label className="block text-xs text-[var(--text-muted,#9aa3b2)] mb-1">
              You pay ({payLabel})
            </label>
            <div className="flex gap-2 mb-1">
              <input
                type="text"
                inputMode="decimal"
                value={amountIn}
                onChange={(e) => setAmountIn(e.target.value.replace(/[^0-9.]/g, ''))}
                placeholder="0.0"
                className="flex-1 rounded-xl border border-white/10 bg-black/40 px-4 py-3 text-lg font-mono text-[var(--text-primary,#EDEDED)] outline-none focus:border-[var(--accent,#4FD44B)]/50"
              />
              <Button type="button" variant="secondary" size="sm" onClick={onMax}>
                Max
              </Button>
            </div>
            <p className="text-[11px] text-[var(--text-muted,#9aa3b2)] mb-4">
              Balance {formatUnits(payBalance, 18)} {payLabel}
              {side === 'buy' ? ' (ETH + WETH; wraps on buy)' : ''}
            </p>

            <div className="rounded-xl border border-white/5 bg-white/[0.03] px-4 py-3 mb-4">
              <div className="text-xs text-[var(--text-muted,#9aa3b2)]">You receive (est.)</div>
              <div className="font-mono text-lg text-[var(--text-primary,#EDEDED)]">
                {estOut !== null ? formatUnits(estOut, 18) : '—'}{' '}
                <span className="text-sm text-[var(--text-muted,#9aa3b2)]">{receiveLabel}</span>
              </div>
              <p className="text-[11px] text-[var(--text-muted,#9aa3b2)] mt-1">
                Mid-price estimate only — execution uses pool slippage. Min out uses your slippage %.
              </p>
            </div>

            <label className="block text-xs text-[var(--text-muted,#9aa3b2)] mb-1">
              Slippage %
            </label>
            <input
              type="text"
              inputMode="decimal"
              value={slippagePct}
              onChange={(e) => setSlippagePct(e.target.value.replace(/[^0-9.]/g, ''))}
              className="mb-4 w-24 rounded-lg border border-white/10 bg-black/40 px-3 py-2 text-sm font-mono text-[var(--text-primary,#EDEDED)]"
            />

            <Button
              className="w-full"
              size="lg"
              loading={isPending}
              disabled={
                isPending ||
                !isConnected ||
                parsedIn === BigInt(0) ||
                (side === 'buy' && buysRestricted)
              }
              onClick={() => void execute()}
              data-testid="pons-launch-trade-submit"
            >
              {!isConnected
                ? 'Connect wallet'
                : side === 'buy' && buysRestricted
                  ? 'Buys restricted'
                  : side === 'buy'
                    ? `Buy ${displaySymbol}`
                    : `Sell ${displaySymbol}`}
            </Button>

            {status ? (
              <p className="mt-3 text-center text-xs text-[var(--text-muted,#9aa3b2)]" data-testid="pons-launch-status">
                {status}
                {txHash ? (
                  <>
                    {' · '}
                    <a
                      className="text-[var(--accent,#4FD44B)] hover:underline"
                      href={`https://robinhoodchain.blockscout.com/tx/${txHash}`}
                      target="_blank"
                      rel="noreferrer"
                    >
                      tx
                    </a>
                  </>
                ) : null}
              </p>
            ) : null}
          </Card>

          <p className="mt-3 text-center text-xs text-[var(--text-muted,#9aa3b2)]">
            After buying, put capital to work in{' '}
            <Link href="/earn" className="text-[var(--accent,#4FD44B)] hover:underline">
              Earn
            </Link>{' '}
            or the{' '}
            <Link href="/staking" className="text-[var(--accent,#4FD44B)] hover:underline">
              Protocol DETF
            </Link>
            .
          </p>
        </div>
      </div>
    </div>
  )
}
