'use client'

import Link from 'next/link'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useSearchParams, useRouter } from 'next/navigation'
import { useAccount, useReadContract, useReadContracts } from 'wagmi'
import { erc20Abi, formatUnits, isAddress } from 'viem'

import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'
import {
  getBaseTokensForChain,
  getFeaturedFeeDetfsForChain,
  getProtocolDetfsForChain,
  getStrategyVaultTokensForChain,
  isFeaturedFeeDetfAddress,
  type TokenListEntry,
} from '@indexedex/protocol/tokenlists'
import { robinhood, robinhoodTestnet } from '@indexedex/protocol/runtimeChains'
import { CHAIN_ID_ROBINHOOD } from '@indexedex/protocol/addressArtifacts'

import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { Stat } from '../components/ui/Stat'
import { DetfAbout } from './components/DetfAbout'
import { DetfActions } from './components/DetfActions'
import { ThresholdGauge } from './components/ThresholdGauge'
import { insightsViewAbi } from './lib/insightsAbi'
import { pairAddresses, profileFor, type DetfLeg } from './lib/detfProfiles'
import { formatWad, scaleThresholds } from './lib/thresholdScale'
import { indexTokens, isZero, labelFor, shortAddr } from './lib/tokenLabels'

type InsightDetf = TokenListEntry & { protocolFee: boolean }

type BasketRow = {
  role: string
  symbol: string
  name: string
  address?: `0x${string}`
}

function mergeDetfs(
  featured: TokenListEntry[],
  protocol: TokenListEntry[],
  featuredSet: (addr: string) => boolean,
): InsightDetf[] {
  const out: InsightDetf[] = []
  const seen = new Set<string>()
  const add = (t: TokenListEntry, protocolFee: boolean) => {
    const k = t.address.toLowerCase()
    if (seen.has(k)) return
    seen.add(k)
    out.push({ ...t, protocolFee })
  }
  for (let i = 0; i < featured.length; i++) add(featured[i]!, true)
  for (let i = 0; i < protocol.length; i++) {
    const t = protocol[i]!
    add(t, featuredSet(t.address))
  }
  return out
}

function asAddr(v: unknown): `0x${string}` | undefined {
  if (typeof v !== 'string' || !isAddress(v) || isZero(v)) return undefined
  return v as `0x${string}`
}

export default function InsightsPageClient() {
  const searchParams = useSearchParams()
  const router = useRouter()
  const { address: wallet, isConnected } = useAccount()
  const { selectedChainId } = useSelectedNetwork()
  const { environment } = useDeploymentEnvironment()

  const featured = useMemo(
    () => getFeaturedFeeDetfsForChain(selectedChainId, environment),
    [selectedChainId, environment],
  )
  const protocol = useMemo(
    () => getProtocolDetfsForChain(selectedChainId, environment),
    [selectedChainId, environment],
  )
  const detfs = useMemo(
    () =>
      mergeDetfs(featured, protocol, (addr) =>
        isFeaturedFeeDetfAddress(selectedChainId, environment, addr),
      ),
    [featured, protocol, selectedChainId, environment],
  )
  const labels = useMemo(
    () =>
      indexTokens([
        getBaseTokensForChain(selectedChainId, environment),
        getStrategyVaultTokensForChain(selectedChainId, environment),
        featured,
        protocol,
      ]),
    [selectedChainId, environment, featured, protocol],
  )

  const qDetf = searchParams.get('detf')
  const [selected, setSelected] = useState('')

  useEffect(() => {
    if (qDetf && isAddress(qDetf)) {
      setSelected(qDetf)
      return
    }
    if (!qDetf && detfs[0] && !selected) setSelected(detfs[0].address)
  }, [qDetf, detfs, selected])

  const pick = useCallback(
    (addr: string) => {
      setSelected(addr)
      router.replace(`/insights?detf=${addr}`, { scroll: false })
    },
    [router],
  )

  const detf = detfs.find((d) => d.address.toLowerCase() === selected.toLowerCase()) ?? detfs[0]
  const detfAddr = detf?.address as `0x${string}` | undefined
  const enabled = !!detfAddr
  const profile = detfAddr ? profileFor(detfAddr, detf?.symbol) : undefined
  const pairs = profile ? pairAddresses(profile) : []

  const reads = useReadContracts({
    contracts: detfAddr
      ? [
          { address: detfAddr, abi: erc20Abi, functionName: 'totalSupply' },
          { address: detfAddr, abi: erc20Abi, functionName: 'symbol' },
          { address: detfAddr, abi: erc20Abi, functionName: 'name' },
          { address: detfAddr, abi: insightsViewAbi, functionName: 'mintThreshold' },
          { address: detfAddr, abi: insightsViewAbi, functionName: 'burnThreshold' },
          { address: detfAddr, abi: insightsViewAbi, functionName: 'thresholdMode' },
          { address: detfAddr, abi: insightsViewAbi, functionName: 'isReserveLive' },
          { address: detfAddr, abi: insightsViewAbi, functionName: 'rebasingClaimToken' },
          { address: detfAddr, abi: insightsViewAbi, functionName: 'reservePool' },
          { address: detfAddr, abi: insightsViewAbi, functionName: 'rateAsset' },
          { address: detfAddr, abi: insightsViewAbi, functionName: 'pairToken' },
          { address: detfAddr, abi: insightsViewAbi, functionName: 'underlyingVault' },
          { address: detfAddr, abi: insightsViewAbi, functionName: 'syntheticPrice' },
          { address: detfAddr, abi: insightsViewAbi, functionName: 'isMintingAllowed' },
          { address: detfAddr, abi: insightsViewAbi, functionName: 'isBurningAllowed' },
          { address: detfAddr, abi: insightsViewAbi, functionName: 'pairToken0' },
          { address: detfAddr, abi: insightsViewAbi, functionName: 'pairToken1' },
          { address: detfAddr, abi: insightsViewAbi, functionName: 'pairToken2' },
          { address: detfAddr, abi: insightsViewAbi, functionName: 'standardExchanges' },
          { address: detfAddr, abi: insightsViewAbi, functionName: 'isAllLegsMintRich' },
          ...(pairs[0]
            ? [{ address: detfAddr, abi: insightsViewAbi, functionName: 'syntheticVs' as const, args: [pairs[0]] }]
            : []),
          ...(pairs[1]
            ? [{ address: detfAddr, abi: insightsViewAbi, functionName: 'syntheticVs' as const, args: [pairs[1]] }]
            : []),
          ...(pairs[2]
            ? [{ address: detfAddr, abi: insightsViewAbi, functionName: 'syntheticVs' as const, args: [pairs[2]] }]
            : []),
        ]
      : [],
    query: { enabled, refetchInterval: 15_000 },
    allowFailure: true,
  })

  const { data: walletBal } = useReadContract({
    address: detfAddr,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: wallet ? [wallet] : undefined,
    query: { enabled: enabled && isConnected && !!wallet, refetchInterval: 15_000 },
  })

  const result = <T,>(i: number): T | undefined => {
    const row = reads.data?.[i]
    if (!row || row.status !== 'success') return undefined
    return row.result as T
  }

  const totalSupply = result<bigint>(0)
  const onchainSymbol = result<string>(1)
  const onchainName = result<string>(2)
  const mintThreshold = result<bigint>(3)
  const burnThreshold = result<bigint>(4)
  const thresholdMode = result<number>(5)
  const reserveLive = result<boolean>(6)
  const claimToken = asAddr(result<`0x${string}`>(7))
  const reservePool = asAddr(result<`0x${string}`>(8))
  const rateAsset = asAddr(result<`0x${string}`>(9))
  const pairToken = asAddr(result<`0x${string}`>(10))
  const underlyingVault = asAddr(result<`0x${string}`>(11))
  const syntheticPrice = result<bigint>(12)
  const mintingAllowed = result<boolean>(13)
  const burningAllowed = result<boolean>(14)
  const pair0 = asAddr(result<`0x${string}`>(15))
  const pair1 = asAddr(result<`0x${string}`>(16))
  const pair2 = asAddr(result<`0x${string}`>(17))
  const exchanges = result<readonly `0x${string}`[]>(18)
  const allLegsMint = result<boolean>(19)
  const vs0 = pairs[0] ? result<bigint>(20) : undefined
  const vs1 = pairs[1] ? result<bigint>(21) : undefined
  const vs2 = pairs[2] ? result<bigint>(22) : undefined

  const readsReady = reads.isFetched || reads.isError
  const anyLive =
    totalSupply != null ||
    mintThreshold != null ||
    syntheticPrice != null ||
    pair0 != null ||
    reserveLive != null
  const noContractRead = readsReady && !anyLive
  const isQuad = profile?.family === 'quad' || pair0 != null
  const priceForGauge = isQuad ? vs0 : syntheticPrice
  const scale = scaleThresholds(burnThreshold, priceForGauge, mintThreshold)
  const symbol = onchainSymbol || detf?.symbol || 'DETF'
  const name = onchainName || detf?.name || symbol
  const supplyLabel = totalSupply != null ? formatUnits(totalSupply, detf?.decimals ?? 18) : '—'
  const holdLabel =
    walletBal != null ? formatUnits(walletBal, detf?.decimals ?? 18) : isConnected ? '0' : 'Connect to see'
  const modeLabel =
    thresholdMode === 1 ? 'Open' : thresholdMode === 0 ? 'Policy' : profile?.mintBurn === 'open' ? 'Open' : profile ? 'Policy' : '—'
  const mintLabel =
    mintingAllowed != null ? (mintingAllowed ? 'Allowed' : 'Blocked') : allLegsMint != null ? (allLegsMint ? 'Allowed' : 'Blocked') : '—'
  const burnLabel = burningAllowed == null ? '—' : burningAllowed ? 'Allowed' : 'Blocked'

  const explorer =
    selectedChainId === CHAIN_ID_ROBINHOOD
      ? robinhood.blockExplorers.default.url
      : robinhoodTestnet.blockExplorers.default.url

  const basket: BasketRow[] = useMemo(() => {
    if (profile) {
      const overlay = new Map<string, `0x${string}`>()
      if (pairToken) overlay.set('pair-0', pairToken)
      if (pair0) overlay.set('pair-0', pair0)
      if (pair1) overlay.set('pair-1', pair1)
      if (pair2) overlay.set('pair-2', pair2)
      if (underlyingVault) overlay.set('vault-0', underlyingVault)
      if (exchanges) {
        for (let i = 0; i < exchanges.length; i++) {
          const a = asAddr(exchanges[i])
          if (a) overlay.set(`vault-${i}`, a)
        }
      }
      if (claimToken) overlay.set('claim', claimToken)
      if (reservePool) overlay.set('reserve', reservePool)
      if (rateAsset) overlay.set('rate', rateAsset)

      let pairN = 0
      let vaultN = 0
      const rows: BasketRow[] = profile.legs.map((leg: DetfLeg) => {
        let key = ''
        if (leg.role === 'Pair token') key = `pair-${pairN++}`
        else if (leg.role === 'Underlying vault' || leg.role === 'Vault') key = `vault-${vaultN++}`
        else if (leg.role === 'Claim token') key = 'claim'
        const live = key ? overlay.get(key) : undefined
        const addr = live ?? leg.address
        const lab = labelFor(labels, addr)
        const listed = lab && lab.name !== 'Not in the local list'
        return {
          role: leg.role,
          symbol: listed ? lab.symbol : leg.symbol,
          name: listed ? lab.name : leg.name,
          address: addr,
        }
      })
      if (rateAsset && !rows.some((r) => r.role === 'Rate asset')) {
        const lab = labelFor(labels, rateAsset)
        rows.push({
          role: 'Rate asset',
          symbol: lab?.symbol ?? shortAddr(rateAsset),
          name: lab?.name ?? 'Settlement token used to mint and bond',
          address: rateAsset,
        })
      }
      if (reservePool && !rows.some((r) => r.address?.toLowerCase() === reservePool.toLowerCase())) {
        rows.push({
          role: 'Reserve pool',
          symbol: 'Market',
          name: 'Market for the DETF token',
          address: reservePool,
        })
      }
      return rows
    }

    const fallback: { role: string; address?: `0x${string}`; meaning: string }[] = [
      { role: 'Rate asset', address: rateAsset, meaning: 'Settlement token used to mint and bond' },
      { role: 'Pair token', address: pairToken ?? pair0, meaning: 'The other token in the reserve market' },
      { role: 'Pair token', address: pair1, meaning: 'Second pair token' },
      { role: 'Pair token', address: pair2, meaning: 'Third pair token' },
      { role: 'Underlying vault', address: underlyingVault, meaning: 'Standard Exchange the basket holds' },
      { role: 'Claim token', address: claimToken, meaning: 'Claim issued when a bond is sold after maturity' },
      { role: 'Reserve pool', address: reservePool, meaning: 'Market for the DETF token' },
    ]
    if (exchanges) {
      for (let i = 0; i < exchanges.length; i++) {
        fallback.push({ role: 'Vault', address: asAddr(exchanges[i]), meaning: 'Standard Exchange in the basket' })
      }
    }
    return fallback
      .filter((r) => r.address)
      .map((r) => {
        const lab = labelFor(labels, r.address)
        return {
          role: r.role,
          symbol: lab?.symbol ?? (r.address ? shortAddr(r.address) : '—'),
          name: lab?.name && lab.name !== 'Not in the local list' ? lab.name : r.meaning,
          address: r.address,
        }
      })
  }, [
    profile,
    labels,
    pairToken,
    pair0,
    pair1,
    pair2,
    underlyingVault,
    exchanges,
    claimToken,
    reservePool,
    rateAsset,
  ])

  const tradeHref = detfAddr ? `/swap?tokenOut=${detfAddr}` : '/swap'
  const actionTokens = useMemo(() => {
    if (profile) {
      return profile.legs
        .filter((l) => l.role === 'Pair token')
        .map((l) => ({ address: l.address, symbol: l.symbol }))
    }
    return [pairToken, pair0, pair1, pair2]
      .filter((a): a is `0x${string}` => !!a)
      .map((a) => ({ address: a, symbol: labelFor(labels, a)?.symbol ?? shortAddr(a) }))
  }, [profile, pairToken, pair0, pair1, pair2, labels])
  const protocolFee = !!detf?.protocolFee

  return (
    <div className="space-y-8">
      <section>
        <p className="text-xs font-mono uppercase tracking-[0.14em] text-[var(--accent,#4FD44B)]">
          DETF means Decentralized ETF
        </p>
        <h1 className="mt-3 text-3xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)] md:text-4xl">
          DETFs
        </h1>
      </section>

      {detfs.length === 0 ? (
        <Card>
          <p className="text-sm text-[var(--text-muted,#9aa3b2)]">No DETF is listed on this network yet.</p>
          <div className="mt-4">
            <Link href="/create">
              <Button>Create DETF</Button>
            </Link>
          </div>
        </Card>
      ) : (
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-[16rem_minmax(0,1fr)]">
          <aside>
            <p className="text-[11px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">Listed DETFs</p>
            <ul className="mt-2 space-y-1" data-testid="insights-detf-list">
              {detfs.map((d) => {
                const active = detfAddr && d.address.toLowerCase() === detfAddr.toLowerCase()
                const listed = profileFor(d.address, d.symbol)
                return (
                  <li key={d.address}>
                    <button
                      type="button"
                      onClick={() => pick(d.address)}
                      className={`w-full rounded-lg px-3 py-2 text-left text-sm ${
                        active
                          ? 'bg-[var(--surface-2,#1c2030)] text-[var(--text-primary,#EDEDED)]'
                          : 'text-[var(--text-muted,#9aa3b2)] hover:bg-white/5'
                      }`}
                    >
                      <span className="font-medium">{d.symbol}</span>
                      <span className="mt-0.5 block text-[11px] truncate">{d.name}</span>
                      {d.protocolFee ? (
                        <span className="mt-1 inline-block text-[10px] uppercase tracking-wide text-[var(--accent,#4FD44B)]">
                          Protocol fees
                        </span>
                      ) : listed ? (
                        <span className="mt-1 block text-[11px] text-[var(--text-muted,#9aa3b2)] truncate">
                          {listed.shape}
                        </span>
                      ) : null}
                    </button>
                  </li>
                )
              })}
            </ul>
          </aside>

          <div className="space-y-5">
            <Card>
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p className="text-[10px] uppercase tracking-widest text-[var(--accent,#4FD44B)]">
                    {protocolFee ? 'Protocol DETF' : profile?.kicker || 'DETF'}
                  </p>
                  <h2 className="mt-1 text-2xl font-semibold text-[var(--text-primary,#EDEDED)]">{symbol}</h2>
                  <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)]">{name}</p>
                  {detfAddr ? (
                    <a
                      href={`${explorer}/address/${detfAddr}`}
                      className="mt-2 inline-block font-mono text-[11px] text-[var(--text-muted,#9aa3b2)] underline-offset-2 hover:underline"
                      target="_blank"
                      rel="noreferrer"
                    >
                      {shortAddr(detfAddr)}
                    </a>
                  ) : null}
                </div>
                <div className="flex flex-wrap gap-2">
                  <Button
                    size="sm"
                    onClick={() =>
                      document.getElementById('detf-actions')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
                    }
                  >
                    Mint or bond {symbol}
                  </Button>
                  <Link href={tradeHref}>
                    <Button size="sm" variant="secondary">
                      Trade {symbol}
                    </Button>
                  </Link>
                </div>
              </div>

              <div className="mt-6">
                <DetfAbout profile={profile} protocolFee={protocolFee} />
              </div>

              <div className="mt-6 grid grid-cols-2 gap-4 md:grid-cols-4">
                <Stat label="Supply" value={supplyLabel} hint={`${symbol} outstanding`} />
                <Stat label="You hold" value={holdLabel} />
                <Stat label="Mint" value={mintLabel} />
                <Stat label="Burn" value={burnLabel} />
              </div>
              <p className="mt-3 text-[11px] text-[var(--text-muted,#9aa3b2)]">
                Mode {modeLabel}
                {reserveLive === true
                  ? '. Reserve is live.'
                  : reserveLive === false
                    ? '. Inert until the first bond.'
                    : profile?.firstBonded
                      ? '. First bond already opened this DETF on the deploy fork.'
                      : ''}
              </p>
            </Card>

            <DetfActions
              key={detfAddr}
              detf={detfAddr}
              detfSymbol={symbol}
              pairTokens={actionTokens}
              chainId={selectedChainId}
            />

            <Card>
              <p className="text-[11px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">
                Synthetic price vs mint and burn
              </p>
              <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)]">
                Synthetic price is the contract price of the DETF token versus a pair, not a dollar
                price. Policy mint is allowed when that price is above the mint line. Burn is allowed
                when it is below the burn line. This is a live snapshot, not a history chart.
              </p>
              <div className="mt-4">
                {!readsReady ? (
                  <p className="text-sm text-[var(--text-muted,#9aa3b2)]" data-testid="insights-price-loading">
                    Reading the contract…
                  </p>
                ) : noContractRead ? (
                  <p className="text-sm text-[var(--text-muted,#9aa3b2)]" data-testid="insights-read-miss">
                    Could not read live price on the current RPC. The about and basket still come
                    from the listing. Connect a wallet on the chain where this DETF was deployed (a
                    local fork is not the public testnet).
                  </p>
                ) : reserveLive === false ? (
                  <ThresholdGauge
                    scale={{ ...scale, inert: true }}
                    burnLabel={formatWad(burnThreshold)}
                    priceLabel={formatWad(priceForGauge)}
                    mintLabel={formatWad(mintThreshold)}
                  />
                ) : isQuad ? (
                  <div className="space-y-3" data-testid="insights-quad-prices">
                    {(
                      [
                        [pairs[0], vs0, 'TTUSDE'],
                        [pairs[1], vs1, 'TTUSDG'],
                        [pairs[2], vs2, 'TTWETH'],
                      ] as const
                    ).map(([addr, price, fallback]) => {
                      if (!addr) return null
                      const lab = labelFor(labels, addr)
                      return (
                        <div key={addr} className="flex items-baseline justify-between gap-3 text-sm">
                          <span className="text-[var(--text-muted,#9aa3b2)]">vs {lab?.symbol ?? fallback}</span>
                          <span className="font-mono text-[var(--text-primary,#EDEDED)]">
                            {formatWad(price)}
                          </span>
                        </div>
                      )
                    })}
                    <p className="text-[11px] text-[var(--text-muted,#9aa3b2)]">
                      Mint line {formatWad(mintThreshold)}. Burn line {formatWad(burnThreshold)}.
                    </p>
                  </div>
                ) : (
                  <ThresholdGauge
                    scale={scale}
                    burnLabel={formatWad(burnThreshold)}
                    priceLabel={formatWad(priceForGauge)}
                    mintLabel={formatWad(mintThreshold)}
                  />
                )}
              </div>
            </Card>

            <Card>
              <p className="text-[11px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">Basket</p>
              <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)]">
                A DETF is one token over a basket that works in other apps.
                {noContractRead ? ' Names below are from the listing.' : ' Names from the listing; addresses from the contract when they read.'}
              </p>
              <ul className="mt-4 divide-y divide-[var(--border-subtle,rgba(255,255,255,0.08))]" data-testid="insights-basket">
                {basket.map((r, i) => (
                  <li key={`${r.role}-${r.address ?? i}`} className="flex flex-wrap items-center justify-between gap-2 py-3">
                    <div>
                      <div className="text-sm text-[var(--text-primary,#EDEDED)]">
                        {r.symbol}{' '}
                        <span className="text-[11px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">
                          {r.role}
                        </span>
                      </div>
                      <div className="text-[11px] text-[var(--text-muted,#9aa3b2)]">{r.name}</div>
                    </div>
                    {r.address ? (
                      <a
                        href={`${explorer}/address/${r.address}`}
                        className="font-mono text-xs text-[var(--text-muted,#9aa3b2)] underline-offset-2 hover:underline"
                        target="_blank"
                        rel="noreferrer"
                      >
                        {shortAddr(r.address)}
                      </a>
                    ) : (
                      <span className="text-xs text-[var(--text-muted,#9aa3b2)]">Not on this DETF</span>
                    )}
                  </li>
                ))}
              </ul>
            </Card>

            <div className="flex flex-wrap gap-3">
              <Link href="/create">
                <Button variant="secondary">Create your own DETF</Button>
              </Link>
              <Link href="/learn">
                <Button variant="ghost">How mint and burn work</Button>
              </Link>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
