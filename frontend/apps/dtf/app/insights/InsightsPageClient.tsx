'use client'

import Link from 'next/link'
import { useCallback, useEffect, useMemo } from 'react'
import { useSearchParams, useRouter } from 'next/navigation'
import { useAccount, useReadContract, useReadContracts, type UseReadContractsParameters } from 'wagmi'
import { erc20Abi, formatUnits, isAddress } from 'viem'

import { isFeaturedFeeDetfAddress } from '@indexedex/protocol/tokenlists'

import { AddressLink } from '../components/ui/AddressLink'
import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { Stat } from '../components/ui/Stat'
import { VAULT_TOKENS_ABI } from '../create/lib/seAbi'
import { DetfAbout } from './components/DetfAbout'
import { DetfActions } from './components/DetfActions'
import { DetfContracts, type ContractRow } from './components/DetfContracts'
import { ThresholdGauge } from './components/ThresholdGauge'
import { resolveVaultShare } from '../create/lib/bondTokens'
import { collectActionTokenAddresses, collectSeVaultReadAddresses } from './lib/actionTokens'
import { insightsStakingHref } from './lib/claimMint'
import { checksumDetfAddress, insightsDetfHref, isInsightsActionTab } from './lib/insightsHref'
import { insightsViewAbi, rebasingClaimAbi } from './lib/insightsAbi'
import { collectDetfRelatedAddresses } from './lib/relatedAddresses'
import { useDetfPoolIds } from './lib/useDetfPoolIds'
import { pairAddresses, profileFor, type DetfLeg } from './lib/detfProfiles'
import { formatWad, scaleThresholds } from './lib/thresholdScale'
import { isZero, labelFor, shortAddr } from './lib/tokenLabels'
import { displayTokenLabel, displayTokenSymbol, isRetiredRichBrand } from '../lib/customerSymbols'
import { isArchivedDetf } from './lib/archivedDetfs'
import { useInsightDetfCatalog } from './lib/useInsightDetfCatalog'

type BasketRow = {
  role: string
  symbol: string
  name: string
  address?: `0x${string}`
}

const selectClass =
  'mt-1 w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm text-[var(--text-primary,#EDEDED)]'

function asAddr(v: unknown): `0x${string}` | undefined {
  if (typeof v !== 'string' || !isAddress(v) || isZero(v)) return undefined
  return v as `0x${string}`
}

export default function InsightsPageClient({ pathAddress }: { pathAddress: string }) {
  const searchParams = useSearchParams()
  const router = useRouter()
  const { address: wallet, isConnected } = useAccount()
  const {
    selectedChainId,
    environment,
    detfs,
    liveDetfs,
    archivedDetfs,
    labels,
    registryLoading,
    registryError,
  } = useInsightDetfCatalog()

  const qTab = searchParams.get('tab')
  const pathTab = isInsightsActionTab(qTab) ? qTab : undefined
  const canonical = checksumDetfAddress(pathAddress)
  const selected = canonical ?? ''

  useEffect(() => {
    if (!canonical) return
    if (canonical !== pathAddress) {
      router.replace(insightsDetfHref(canonical, pathTab), { scroll: false })
    }
  }, [canonical, pathAddress, pathTab, router])

  const pick = useCallback(
    (addr: string) => {
      router.replace(insightsDetfHref(addr, pathTab), { scroll: false })
    },
    [router, pathTab],
  )

  const detf =
    detfs.find((d) => d.address.toLowerCase() === selected.toLowerCase()) ??
    (selected && isAddress(selected)
      ? {
          chainId: selectedChainId,
          address: selected as `0x${string}`,
          name: 'DETF',
          symbol: 'DETF',
          decimals: 18,
          protocolFee: isFeaturedFeeDetfAddress(selectedChainId, environment, selected),
        }
      : undefined)
  const detfAddr = detf?.address as `0x${string}` | undefined
  const archived = isArchivedDetf(detfAddr)
  const enabled = !!detfAddr
  const profile = detfAddr ? profileFor(detfAddr, detf?.symbol) : undefined
  const pairs = profile ? pairAddresses(profile) : []

  const insightContracts = detfAddr
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
    : []
  const reads = useReadContracts({
    contracts: insightContracts as UseReadContractsParameters['contracts'],
    query: { enabled, refetchInterval: 15_000 },
    allowFailure: true,
  })

  const { data: weightedPairTokens } = useReadContract({
    address: detfAddr,
    abi: insightsViewAbi,
    functionName: 'pairTokens',
    query: { enabled, retry: 0 },
  })
  const { data: acceptedBondTokens } = useReadContract({
    address: detfAddr,
    abi: insightsViewAbi,
    functionName: 'acceptedBondTokens',
    query: { enabled, retry: 0 },
  })
  const { data: vaultShares } = useReadContract({
    address: detfAddr,
    abi: insightsViewAbi,
    functionName: 'vaultShares',
    query: { enabled, retry: 0 },
  })
  const { data: standardExchangeVault } = useReadContract({
    address: detfAddr,
    abi: insightsViewAbi,
    functionName: 'standardExchangeVault',
    query: { enabled, retry: 0 },
  })
  const { data: standardExchangeVaultShare } = useReadContract({
    address: detfAddr,
    abi: insightsViewAbi,
    functionName: 'standardExchangeVaultShare',
    query: { enabled, retry: 0 },
  })
  const { data: bondNftVaultRaw } = useReadContract({
    chainId: selectedChainId,
    address: detfAddr,
    abi: insightsViewAbi,
    functionName: 'bondNftVault',
    query: { enabled, retry: 0 },
  })
  const { data: protocolNftVaultRaw } = useReadContract({
    chainId: selectedChainId,
    address: detfAddr,
    abi: insightsViewAbi,
    functionName: 'protocolNFTVault',
    query: { enabled, retry: 0 },
  })
  const { data: reserveHookRaw } = useReadContract({
    address: detfAddr,
    abi: insightsViewAbi,
    functionName: 'reserveHook',
    query: { enabled, retry: 0 },
  })
  const bondNftVault = asAddr(bondNftVaultRaw)
  const protocolNftVault = asAddr(protocolNftVaultRaw)
  const reserveHookFromDetf = asAddr(reserveHookRaw)

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
  const claimFromBundle = asAddr(result<`0x${string}`>(7))
  const { data: claimRaw } = useReadContract({
    address: detfAddr,
    abi: insightsViewAbi,
    functionName: 'rebasingClaimToken',
    query: { enabled, retry: 0 },
  })
  const claimToken = claimFromBundle ?? asAddr(claimRaw)
  const { data: claimSymbol } = useReadContract({
    address: claimToken,
    abi: rebasingClaimAbi,
    functionName: 'symbol',
    query: { enabled: !!claimToken },
  })
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
  const seList = useMemo(
    () =>
      collectSeVaultReadAddresses({
        standardExchanges: exchanges,
        underlyingVault,
        standardExchangeVault,
      }),
    [exchanges, underlyingVault, standardExchangeVault],
  )
  const vaultShare = useMemo(
    () =>
      resolveVaultShare(
        asAddr(standardExchangeVault) ?? underlyingVault,
        asAddr(standardExchangeVaultShare) ?? (vaultShares as readonly unknown[] | undefined)?.[0],
      ),
    [standardExchangeVault, underlyingVault, standardExchangeVaultShare, vaultShares],
  )
  const seTokenReads = useReadContracts({
    contracts: seList.map((address) => ({
      address,
      abi: VAULT_TOKENS_ABI,
      functionName: 'vaultTokens' as const,
    })),
    query: { enabled: seList.length > 0 },
    allowFailure: true,
  })
  const seVaultTokens = useMemo(
    () =>
      (seTokenReads.data ?? []).map((row) =>
        row.status === 'success' ? (row.result as readonly `0x${string}`[]) : [],
      ),
    [seTokenReads.data],
  )
  const vs0 = pairs[0] ? result<bigint>(20) : undefined
  const vs1 = pairs[1] ? result<bigint>(21) : undefined
  const vs2 = pairs[2] ? result<bigint>(22) : undefined

  const readsReady = reads.isFetched || reads.isError
  const anyLive =
    totalSupply != null ||
    mintThreshold != null ||
    syntheticPrice != null ||
    pair0 != null ||
    reserveLive != null ||
    (Array.isArray(weightedPairTokens) && weightedPairTokens.length > 0)
  const noContractRead = readsReady && !anyLive
  const isQuad = profile?.family === 'quad' || pair0 != null
  const priceForGauge = isQuad ? vs0 : syntheticPrice
  const scale = scaleThresholds(burnThreshold, priceForGauge, mintThreshold)
  const rawSymbol = onchainSymbol || detf?.symbol || 'DETF'
  const rawName = onchainName || detf?.name || rawSymbol
  const symbol = displayTokenSymbol(rawSymbol) || rawSymbol
  const name = displayTokenLabel(rawName)
  const richBrandUnlisted =
    !!detfAddr &&
    !detfs.some((d) => d.address.toLowerCase() === detfAddr.toLowerCase()) &&
    (isRetiredRichBrand(rawSymbol) || isRetiredRichBrand(rawName))

  useEffect(() => {
    if (!richBrandUnlisted) return
    const next = detfs[0]?.address
    if (next && next.toLowerCase() !== detfAddr.toLowerCase()) pick(next)
  }, [richBrandUnlisted, detfs, detfAddr, pick])
  const supplyLabel = totalSupply != null ? formatUnits(totalSupply, detf?.decimals ?? 18) : '—'
  const holdLabel =
    walletBal != null ? formatUnits(walletBal, detf?.decimals ?? 18) : isConnected ? '0' : 'Connect to see'
  const modeLabel =
    thresholdMode === 1 ? 'Open' : thresholdMode === 0 ? 'Policy' : profile?.mintBurn === 'open' ? 'Open' : profile ? 'Policy' : '—'
  const mintLabel = archived
    ? 'Off'
    : mintingAllowed != null
      ? mintingAllowed
        ? 'Allowed'
        : 'Blocked'
      : allLegsMint != null
        ? allLegsMint
          ? 'Allowed'
          : 'Blocked'
        : '—'
  const burnLabel = burningAllowed == null ? '—' : burningAllowed ? 'Allowed' : 'Blocked'
  const reserveHook = reserveHookFromDetf ?? reservePool
  const { reservePoolId, sePoolIds } = useDetfPoolIds({
    chainId: selectedChainId,
    detf: detfAddr,
    pairToken: pairToken ?? pair0,
    reserveHook,
    claimToken,
    seVaults: seList,
  })

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

    const weightedPairs = ((weightedPairTokens as readonly `0x${string}`[] | undefined) ?? []).filter(
      (a) => asAddr(a),
    )
    const fallback: { role: string; address?: `0x${string}`; meaning: string }[] = [
      { role: 'Rate asset', address: rateAsset, meaning: 'Settlement token used to mint and bond' },
      ...(weightedPairs.length
        ? weightedPairs.map((address) => ({
            role: 'Pair token',
            address,
            meaning: 'A pair token in the weighted reserve',
          }))
        : [
            { role: 'Pair token', address: pairToken ?? pair0, meaning: 'The other token in the reserve market' },
            { role: 'Pair token', address: pair1, meaning: 'Second pair token' },
            { role: 'Pair token', address: pair2, meaning: 'Third pair token' },
          ]),
      { role: 'Underlying vault', address: underlyingVault, meaning: 'Standard Exchange the basket holds' },
      { role: 'Claim token', address: claimToken, meaning: 'Rebasing claim token. Stake to mint it.' },
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
    weightedPairTokens,
    underlyingVault,
    exchanges,
    claimToken,
    reservePool,
    rateAsset,
  ])

  const tradeHref = detfAddr ? `/swap?tokenOut=${detfAddr}` : '/swap'
  const actionAddrs = useMemo(
    () =>
      collectActionTokenAddresses({
        pairTokens: weightedPairTokens as readonly unknown[] | undefined,
        acceptedBondTokens: acceptedBondTokens as readonly unknown[] | undefined,
        vaultShares: vaultShares as readonly unknown[] | undefined,
        standardExchanges: exchanges,
        seVaultTokens,
        pairToken,
        pair0,
        pair1,
        pair2,
        rateAsset,
        underlyingVault,
        standardExchangeVault,
        standardExchangeVaultShare,
        exclude: detfAddr ? [detfAddr] : [],
      }),
    [
      weightedPairTokens,
      acceptedBondTokens,
      vaultShares,
      exchanges,
      seVaultTokens,
      pairToken,
      pair0,
      pair1,
      pair2,
      rateAsset,
      underlyingVault,
      standardExchangeVault,
      standardExchangeVaultShare,
      detfAddr,
    ],
  )
  const { data: actionMeta } = useReadContracts({
    contracts: actionAddrs.map((address) => ({
      address,
      abi: erc20Abi,
      functionName: 'symbol' as const,
    })),
    query: { enabled: actionAddrs.length > 0 },
    allowFailure: true,
  })
  const actionTokens = useMemo(() => {
    const fromChain = actionAddrs.map((address, i) => {
      const listed = labelFor(labels, address)
      const onchain =
        actionMeta?.[i]?.status === 'success' ? String(actionMeta[i]!.result) : undefined
      const listedOk = listed && listed.name !== 'Not in the local list'
      return {
        address,
        symbol:
          displayTokenSymbol(
            listedOk ? listed.symbol : onchain || listed?.symbol || shortAddr(address),
          ) || shortAddr(address),
      }
    })
    if (fromChain.length > 0) return fromChain
    if (profile) {
      return profile.legs
        .filter((l) => l.role === 'Pair token')
        .map((l) => ({ address: l.address, symbol: l.symbol }))
    }
    return []
  }, [actionAddrs, actionMeta, labels, profile])
  const protocolFee = !!detf?.protocolFee
  const defaultBurn = archived || (burningAllowed === true && mintingAllowed === false)
  const actionTab = pathTab ?? (defaultBurn ? 'burn' : undefined)

  const relatedBase = useMemo(
    () =>
      collectDetfRelatedAddresses({
        detf: detfAddr,
        rateAsset,
        pairTokens: weightedPairTokens as readonly unknown[] | undefined,
        pairToken,
        pair0,
        pair1,
        pair2,
        vaultShares: vaultShares as readonly unknown[] | undefined,
        standardExchangeVaultShare,
        underlyingVault,
        standardExchangeVault,
        standardExchanges: exchanges,
        seVaultTokens,
        claimToken,
        reservePool,
        bondNftVault,
        protocolNftVault,
      }),
    [
      detfAddr,
      rateAsset,
      weightedPairTokens,
      pairToken,
      pair0,
      pair1,
      pair2,
      vaultShares,
      standardExchangeVaultShare,
      underlyingVault,
      standardExchangeVault,
      exchanges,
      seVaultTokens,
      claimToken,
      reservePool,
      bondNftVault,
      protocolNftVault,
    ],
  )
  const { data: relatedMeta } = useReadContracts({
    contracts: relatedBase.map((row) => ({
      address: row.address,
      abi: erc20Abi,
      functionName: 'symbol' as const,
    })),
    query: { enabled: relatedBase.length > 0 },
    allowFailure: true,
  })
  const relatedRows: ContractRow[] = useMemo(() => {
    const meaning: Record<string, string> = {
      'Rate asset': 'Settlement token used to mint and bond',
      'Pair token': 'A pair token in the reserve',
      'Vault share': 'Share token of a vault in the basket',
      'Underlying vault': 'Standard Exchange the basket holds',
      'Vault token': 'Token held by a vault in the basket',
      'Claim token': 'Rebasing claim token. Stake to mint it.',
      'Reserve pool': 'Market for the DETF token',
      'Bond NFT': 'Bond positions for this DETF',
      'Protocol NFT': 'Protocol-owned bond vault',
    }
    return relatedBase.map((row, i) => {
      if (row.role === 'DETF token') {
        return { ...row, symbol, name }
      }
      const lab = labelFor(labels, row.address)
      const listed = lab && lab.name !== 'Not in the local list'
      const onchain =
        relatedMeta?.[i]?.status === 'success' ? String(relatedMeta[i]!.result) : undefined
      return {
        ...row,
        symbol: listed
          ? lab.symbol
          : displayTokenSymbol(onchain || lab?.symbol || '') || shortAddr(row.address),
        name: listed ? lab.name : meaning[row.role] ?? row.role,
      }
    })
  }, [relatedBase, relatedMeta, labels, symbol, name])

  if (!canonical) {
    return (
      <div className="space-y-5">
        <Card>
          <p className="text-sm text-[var(--text-primary,#EDEDED)]">That is not a DETF token address.</p>
          <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)]">
            Open a DETF from the list, or paste a 0x address in the URL.
          </p>
          <div className="mt-4">
            <Link href="/insights">
              <Button>All DETFs</Button>
            </Link>
          </div>
        </Card>
      </div>
    )
  }

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

      {detfs.length === 0 && !registryLoading && !detfAddr ? (
        <Card>
          <p className="text-sm text-[var(--text-muted,#9aa3b2)]">
            {registryError
              ? 'Could not read DETFs from the vault registry on this network.'
              : 'No DETF is on the vault registry for this network yet.'}
          </p>
          <div className="mt-4">
            <Link href="/create">
              <Button>Create DETF</Button>
            </Link>
          </div>
        </Card>
      ) : (
        <div className="space-y-5">
          <Card>
            <div className="flex flex-wrap items-center justify-between gap-2">
              <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
                DETF
              </label>
              <Link
                href="/insights"
                className="text-xs text-[var(--accent,#4FD44B)] underline-offset-2 hover:underline"
              >
                All DETFs
              </Link>
            </div>
            <label className="mt-1 block text-sm text-[var(--text-primary,#EDEDED)]">
              <select
                className={selectClass}
                value={detfAddr ?? ''}
                onChange={(e) => pick(e.target.value)}
                data-testid="insights-detf-list"
                aria-label="DETF"
              >
                {liveDetfs.length === 0 && archivedDetfs.length === 0 && !detfAddr ? (
                  <option value="">Reading DETFs…</option>
                ) : null}
                {detfAddr &&
                !detfs.some((d) => d.address.toLowerCase() === detfAddr.toLowerCase()) &&
                !isRetiredRichBrand(rawSymbol) &&
                !isRetiredRichBrand(rawName) ? (
                  <option value={detfAddr}>
                    {symbol} · {name}
                    {archived ? ' · Archived' : ''}
                  </option>
                ) : null}
                {liveDetfs.length > 0 ? (
                  <optgroup label="DETFs">
                    {liveDetfs.map((d) => (
                      <option key={d.address} value={d.address}>
                        {d.symbol} · {d.name}
                        {d.protocolFee ? ' · Protocol fees' : ''}
                      </option>
                    ))}
                  </optgroup>
                ) : null}
                {archivedDetfs.length > 0 ? (
                  <optgroup label="Archived DETFs">
                    {archivedDetfs.map((d) => (
                      <option key={d.address} value={d.address}>
                        {d.symbol} · {d.name}
                      </option>
                    ))}
                  </optgroup>
                ) : null}
              </select>
            </label>
            <p className="mt-2 text-xs text-[var(--text-muted,#9aa3b2)]">
              {registryLoading
                ? 'Reading DETFs from the vault registry…'
                : 'Live DETFs from the vault registry. Archived DETFs are in their own group.'}
            </p>
            {registryError ? (
              <p className="mt-2 text-xs text-[var(--danger,#E6386A)]">{registryError}</p>
            ) : null}
            <div className="mt-4">
              <Link href="/create">
                <Button size="sm" variant="secondary">
                  Create DETF
                </Button>
              </Link>
            </div>
          </Card>

          {detfAddr ? (
          <div className="space-y-5">
            <Card>
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p className="text-[10px] uppercase tracking-widest text-[var(--accent,#4FD44B)]">
                    {archived ? 'Archived DETF' : protocolFee ? 'Protocol DETF' : profile?.kicker || 'DETF'}
                  </p>
                  <h2 className="mt-1 text-2xl font-semibold text-[var(--text-primary,#EDEDED)]">{symbol}</h2>
                  <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)]">{name}</p>
                  {detfAddr ? (
                    <div className="mt-2">
                      <AddressLink chainId={selectedChainId} address={detfAddr} display="full" />
                    </div>
                  ) : null}
                </div>
                <div className="flex flex-wrap gap-2">
                  <Button
                    size="sm"
                    onClick={() =>
                      document.getElementById('detf-actions')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
                    }
                  >
                    {archived ? `Burn ${symbol}` : defaultBurn ? `Burn ${symbol}` : `Mint or bond ${symbol}`}
                  </Button>
                  {claimToken ? (
                    <Button
                      size="sm"
                      variant="secondary"
                      data-testid="insights-stake"
                      onClick={() => {
                        router.replace(insightsStakingHref(detfAddr), { scroll: false })
                        document
                          .getElementById('detf-actions')
                          ?.scrollIntoView({ behavior: 'smooth', block: 'start' })
                      }}
                    >
                      Stake {claimSymbol || 'claim token'}
                    </Button>
                  ) : null}
                  <Link href={tradeHref}>
                    <Button size="sm" variant="secondary">
                      Trade {symbol}
                    </Button>
                  </Link>
                </div>
              </div>

              <div className="mt-6">
                <DetfAbout profile={profile} protocolFee={protocolFee} archived={archived} />
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
              vaultShare={vaultShare}
              chainId={selectedChainId}
              claimToken={claimToken}
              claimSymbol={claimSymbol}
              reserveLive={reserveLive}
              burningAllowed={burningAllowed}
              archived={archived}
              initialTab={actionTab}
              nftVault={bondNftVault ?? protocolNftVault}
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
                    <div className="flex flex-wrap items-center gap-3">
                      {r.role === 'Claim token' && detfAddr ? (
                        <button
                          type="button"
                          className="text-xs text-[var(--accent,#4FD44B)] underline-offset-2 hover:underline"
                          onClick={() => {
                            router.replace(insightsStakingHref(detfAddr), { scroll: false })
                            document
                              .getElementById('detf-actions')
                              ?.scrollIntoView({ behavior: 'smooth', block: 'start' })
                          }}
                        >
                          Stake
                        </button>
                      ) : null}
                      {r.address ? (
                        <AddressLink chainId={selectedChainId} address={r.address} display="full" />
                      ) : (
                        <span className="text-xs text-[var(--text-muted,#9aa3b2)]">Not on this DETF</span>
                      )}
                    </div>
                  </li>
                ))}
              </ul>
            </Card>

            <DetfContracts
              rows={relatedRows}
              chainId={selectedChainId}
              reservePoolId={reservePoolId}
              sePoolIds={sePoolIds}
            />

            <div className="flex flex-wrap gap-3">
              <Link href="/create">
                <Button variant="secondary">Create your own DETF</Button>
              </Link>
              <Link href="/learn">
                <Button variant="ghost">How mint and burn work</Button>
              </Link>
            </div>
          </div>
          ) : null}
        </div>
      )}
    </div>
  )
}
