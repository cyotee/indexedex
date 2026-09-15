'use client'

import { useMemo } from 'react'
import Link from 'next/link'
import { erc20Abi, formatUnits, type PublicClient } from 'viem'
import { useAccount, usePublicClient, useReadContracts } from 'wagmi'
import { useQuery } from '@tanstack/react-query'
import { useSearchParams } from 'next/navigation'
import WalletStatusBanner from '../components/WalletStatusBanner'
import { AddressLink } from '../components/ui/AddressLink'
import { PageHeader } from '../components/ui/PageHeader'
import { CHAIN_ID_ROBINHOOD, getAddressArtifacts } from '@indexedex/protocol/addressArtifacts'
import useChainResolution from '../lib/hooks/useChainResolution'
import { type Address } from '@indexedex/protocol/tokenlists'
import { displayTokenSymbol } from '../lib/customerSymbols'
import { DetfActions } from '../insights/components/DetfActions'
import { insightsViewAbi, standardizedYieldDiscoveryAbi } from '../insights/lib/insightsAbi'
import { asAddr, type ActionToken } from '../insights/lib/actionTokens'
import SyntheticPrices from './sections/SyntheticPrices'
import MigrationClaimPanel from './sections/MigrationClaimPanel'
import { readProtocolDetf } from '../lib/tokenStaking/migration'
import { Button } from '../components/ui/Button'
import StakingSwapComparison from './sections/StakingSwapComparison'

const workspaceReadAbi = [...erc20Abi, ...insightsViewAbi, ...standardizedYieldDiscoveryAbi] as const

export type StakingPageClientProps = {
  embedMode?: boolean
  fixedDetf?: `0x${string}`
}

/** The full workspace and Earn embed use the same standard routes and funded bond actions as Insights. */
export default function StakingPageClient({ embedMode = false, fixedDetf }: StakingPageClientProps = {}) {
  const chain = useChainResolution(CHAIN_ID_ROBINHOOD)
  const wallet = useAccount()
  const client = usePublicClient({ chainId: chain.dataChainId }) as PublicClient | undefined
  const searchParams = useSearchParams()
  const platform = useMemo(() => getAddressArtifacts(chain.dataChainId, chain.environment).platform as { tokenStaking?: string }, [chain.dataChainId, chain.environment])
  const stakingAddress = asAddr(platform.tokenStaking)
  const wrongNetwork = chain.isConnected && !chain.walletMatchesDataChain
  const discovery = useQuery({
    queryKey: ['protocol-detf-discovery', chain.dataChainId, chain.environment, stakingAddress,
      wallet.address, wallet.chainId, wallet.status, wallet.connector?.uid],
    queryFn: () => readProtocolDetf(client!, stakingAddress!),
    enabled: !embedMode && !!stakingAddress && !!client && !wrongNetwork,
    retry: false, staleTime: 0, refetchInterval: 15_000,
  })
  // URL parameters and stale rehearsal catalogs cannot select another product.
  // Earn embeds continue to supply their own fixed product.
  const detfAddress = embedMode ? asAddr(fixedDetf) ?? undefined
    : !wrongNetwork && !discovery.isError ? discovery.data ?? undefined : undefined

  const details = useReadContracts({
    contracts: detfAddress
      ? (['symbol', 'rebasingClaimToken', 'bondNftVault', 'protocolNFTVault', 'isReserveLive', 'acceptedBondTokens',
        'mintThreshold', 'burnThreshold', 'rawSY', 'stakingSY'] as const)
        .map((functionName) => ({ address: detfAddress, abi: workspaceReadAbi, functionName, chainId: chain.dataChainId }))
      : [],
    allowFailure: true,
    query: { enabled: !!detfAddress, refetchInterval: 15_000 },
  })
  const value = (index: number): unknown => details.data?.[index]?.result
  const detfSymbol = displayTokenSymbol(typeof value(0) === 'string' ? value(0) as string : undefined) || (embedMode ? 'DETF' : 'DTF-DETF')
  const stakingToken = asAddr(value(1)) ?? undefined
  const nftVault = asAddr(value(2)) ?? asAddr(value(3)) ?? undefined
  const reserveLive = typeof value(4) === 'boolean' ? value(4) as boolean : undefined
  const bondTokens = useMemo(() => {
    const raw = details.data?.[5]?.result
    return Array.isArray(raw) ? raw.map(asAddr).filter((token): token is Address => token != null) : []
  }, [details.data])
  const symbols = useReadContracts({
    contracts: bondTokens.map((token) => ({ address: token, abi: erc20Abi, functionName: 'symbol' as const, chainId: chain.dataChainId })),
    allowFailure: true,
    query: { enabled: bondTokens.length > 0 },
  })
  const paymentTokens: ActionToken[] = bondTokens.map((address, index) => ({
    address,
    symbol: typeof symbols.data?.[index]?.result === 'string'
      ? displayTokenSymbol(symbols.data[index]!.result as string) : `${address.slice(0, 6)}…${address.slice(-4)}`,
  }))
  const price = (index: number) => typeof value(index) === 'bigint' ? formatUnits(value(index) as bigint, 18) : '—'
  const shellClass = embedMode ? 'text-[var(--text-primary,#EDEDED)]' : 'mx-auto max-w-5xl px-4 text-[var(--text-primary,#EDEDED)] sm:px-6 lg:px-8'

  return <div className={shellClass} data-testid={embedMode ? 'detf-workspace-embed-body' : 'detf-workspace-full'}>
    {!embedMode ? <>
      <PageHeader title="DTF-DETF staking" subtitle="View your migrated DTF position, claim staking tokens, or purchase a DTF-DETF bond." />
      <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">Looking for strategy vaults? <Link href="/earn" className="text-[var(--accent,#4FD44B)] hover:underline">Browse Earn</Link>.</p>
    </> : null}
    <WalletStatusBanner className={embedMode ? 'mt-0' : 'mt-4'} isConnected={chain.isConnected}
      isUnsupportedChain={chain.isUnsupportedChain} walletMatchesDataChain={chain.walletMatchesDataChain}
      attachedWalletChainId={chain.attachedWalletChainId} dataChainId={chain.dataChainId} environment={chain.environment} />
    {!embedMode && stakingAddress ? <StakingSwapComparison chainId={chain.dataChainId} environment={chain.environment} staking={stakingAddress} detf={detfAddress} /> : null}
    {!embedMode && stakingAddress ? <StakingSwapComparison mode="detf" chainId={chain.dataChainId} environment={chain.environment} staking={stakingAddress} detf={detfAddress} /> : null}
    {!embedMode && stakingAddress && detfAddress ?
      <MigrationClaimPanel chainId={chain.dataChainId} staking={stakingAddress} detf={detfAddress} /> : null}
    {!detfAddress ? <div className="mt-6 text-sm text-[var(--text-muted,#9aa3b2)]" data-testid="staking-discovery-status">
      {wrongNetwork ? <p>Switch your wallet to the selected network to view DTF-DETF.</p>
        : discovery.isError ? <div role="alert"><p>Could not load DTF-DETF from the current network.</p>
          <Button onClick={() => void discovery.refetch()} disabled={discovery.isFetching}>Retry</Button></div>
        : !embedMode && stakingAddress && discovery.isPending ? <p>Loading DTF-DETF…</p>
        : <p>DTF-DETF migration has not been configured on this network.</p>}
    </div> : <div className="mt-5 space-y-4" data-testid="staking-detf" data-detf={detfAddress}>

      <div className="rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] p-4 text-sm">
        <SyntheticPrices key={`${chain.dataChainId}:${detfAddress}`} detf={detfAddress} chainId={chain.dataChainId} />
        <div className="mt-4 flex flex-wrap gap-x-6 gap-y-2">
          <span>Mint threshold: {price(6)}</span><span>Burn threshold: {price(7)}</span>
        </div>
        <p className="mt-2 text-[var(--text-muted,#9aa3b2)]">Outside the primary mint or burn threshold, exchanges execute through the reserve pool.</p>
        <details className="mt-3">
          <summary className="cursor-pointer">Contract addresses</summary>
          {([['DETF', detfAddress], ['sDETF', stakingToken], ['Bond NFT', nftVault], ['Raw DETF SY', asAddr(value(8))], ['Staking SY', asAddr(value(9))]] as const)
            .map(([label, address]) => address ? <div key={label} className="mt-2">{label}: <AddressLink chainId={chain.dataChainId} address={address} /></div> : null)}
        </details>
      </div>
      <DetfActions key={`${chain.dataChainId}:${detfAddress}`} detf={detfAddress} detfSymbol={detfSymbol}
        pairTokens={paymentTokens} chainId={chain.dataChainId} claimToken={stakingToken} claimSymbol="sDETF"
        reserveLive={reserveLive} nftVault={nftVault} initialTab={searchParams?.get('tab') ?? undefined} />
    </div>}
  </div>
}
