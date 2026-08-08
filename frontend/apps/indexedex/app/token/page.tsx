'use client'

import Link from 'next/link'
import { useMemo } from 'react'

import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { PageHeader } from '../components/ui/PageHeader'
import { AddressLink } from '../components/ui/AddressLink'
import { getLaunchTokenAddress } from '../lib/lab'
import { loadFeaturedFeeDetfs } from '../lib/earn/loadEarnProducts'
import { feeDetfStakingHref } from '@indexedex/protocol/tokenlists'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'
import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'

export default function TokenPage() {
  const launchToken = getLaunchTokenAddress()
  const { selectedChainId } = useSelectedNetwork()
  const { environment } = useDeploymentEnvironment()
  const featuredFee = useMemo(
    () => loadFeaturedFeeDetfs(selectedChainId, environment, 1),
    [selectedChainId, environment],
  )
  const hero = featuredFee[0]

  const buyHref = launchToken
    ? `/swap?launch=1&tokenOut=${launchToken}`
    : '/swap?launch=1'

  return (
    <div className="max-w-3xl">
      <PageHeader
        title="Token"
        subtitle="Buy (when configured), then put capital to work in the Protocol DETF or Earn strategies."
      />

      <Card className="mb-6">
        <h2 className="text-base font-medium text-[var(--text-primary,#EDEDED)]">Launch status</h2>
        {launchToken ? (
          <>
            <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">
              Launch token address is configured for this build. Buy via Swap with launch defaults.
            </p>
            <div className="mt-3">
              <AddressLink chainId={selectedChainId} address={launchToken} />
            </div>
          </>
        ) : (
          <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">
            No mainnet TGE address is set (<code className="text-xs">NEXT_PUBLIC_LAUNCH_TOKEN_ADDRESS</code>).
            Use Swap on testnet when liquidity exists, or wait for launch configuration. We do not invent a
            claim contract.
          </p>
        )}
        <div className="mt-4 flex flex-wrap gap-2">
          <Link href={buyHref}>
            <Button>Buy via Swap</Button>
          </Link>
          <Link href="/earn">
            <Button variant="secondary">Browse Earn</Button>
          </Link>
        </div>
      </Card>

      <Card className="mb-6">
        <h2 className="text-base font-medium text-[var(--text-primary,#EDEDED)]">Then put it to work</h2>
        {hero ? (
          <>
            <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">
              After acquiring the token (or any base asset), open the Protocol DETF workspace to mint,
              bond, and sell. Protocol usage and seigniorage fees apply on-chain — amounts are not
              guarantees.
            </p>
            <Link href={feeDetfStakingHref(hero.address)} className="mt-4 inline-block">
              <Button variant="secondary" size="sm">
                Open {hero.symbol}
              </Button>
            </Link>
          </>
        ) : (
          <>
            <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">
              No Protocol DETF is configured on this network. Browse Earn for strategy vaults.
            </p>
            <Link href="/earn" className="mt-4 inline-block">
              <Button variant="secondary" size="sm">
                Browse Earn
              </Button>
            </Link>
          </>
        )}
      </Card>

      <Card>
        <h2 className="text-base font-medium text-[var(--text-primary,#EDEDED)]">Utility (honest)</h2>
        <ul className="mt-2 list-disc pl-5 text-sm text-[var(--text-muted,#9aa3b2)] space-y-1">
          <li>Access to protocol products through the app (Earn, Swap, Protocol DETF workflows).</li>
          <li>Fee / bonding utility is only claimed when live on-chain — check docs when published.</li>
          <li>Governance claims require deployed governance contracts.</li>
          <li>
            No airdrop claim surface is invented here — only{' '}
            <code className="text-xs">NEXT_PUBLIC_LAUNCH_TOKEN_ADDRESS</code> + Swap when configured.
          </li>
        </ul>
      </Card>
    </div>
  )
}
