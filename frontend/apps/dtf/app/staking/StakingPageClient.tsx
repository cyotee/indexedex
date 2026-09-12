'use client'

import { useMemo } from 'react'
import { erc20Abi, formatUnits } from 'viem'
import { useReadContracts } from 'wagmi'
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

const workspaceReadAbi = [...erc20Abi, ...insightsViewAbi, ...standardizedYieldDiscoveryAbi] as const

export type StakingPageClientProps = {
  embedMode?: boolean
  fixedDetf?: `0x${string}`
}

/** The full workspace and Earn embed use the same standard routes and funded bond actions as Insights. */
export default function StakingPageClient({ embedMode = false, fixedDetf }: StakingPageClientProps = {}) {
  const chain = useChainResolution(CHAIN_ID_ROBINHOOD)
  const searchParams = useSearchParams()
  const platform = useMemo(() => getAddressArtifacts(chain.dataChainId, chain.environment).platform as { protocolDetf?: string; tokenStaking?: string }, [chain.dataChainId, chain.environment])
  // The staking page is dedicated to the configured protocol DETF. Earn embeds
  // supply their own fixed product; URL parameters cannot change this page's DETF.
  const detfAddress = asAddr(embedMode ? fixedDetf : platform.protocolDetf) ?? undefined

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
      <PageHeader title="Protocol DETF" subtitle="Buy DETF, stake it, or purchase a bond that stays staked while its principal vests. Claim principal and staking rewards as sDETF, then unstake it 1:1 for DETF." />
      <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">Looking for strategy vaults? <a href="/earn" className="text-[var(--accent,#4FD44B)] hover:underline">Browse Earn</a>.</p>
    </> : null}
    <WalletStatusBanner className={embedMode ? 'mt-0' : 'mt-4'} isConnected={chain.isConnected}
      isUnsupportedChain={chain.isUnsupportedChain} walletMatchesDataChain={chain.walletMatchesDataChain}
      attachedWalletChainId={chain.attachedWalletChainId} dataChainId={chain.dataChainId} environment={chain.environment} />
    {!embedMode && asAddr(platform.tokenStaking) && asAddr(platform.protocolDetf) ?
      <MigrationClaimPanel chainId={chain.dataChainId} staking={asAddr(platform.tokenStaking)!} detf={asAddr(platform.protocolDetf)!} /> : null}
    {!detfAddress ? <p className="mt-6 text-sm text-[var(--text-muted,#9aa3b2)]">No Protocol DETF is configured on this network.</p> : <div className="mt-5 space-y-4">

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
