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
        subtitle="Buy when a launch token is set. Then put it to work in Protocol DETF or Earn vaults."
      />

      <Card className="mb-6">
        <h2 className="text-base font-medium text-[var(--text-primary,#EDEDED)]">Launch status</h2>
        {launchToken ? (
          <>
            <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">
              A launch token is set for this build. Buy it on Swap.
            </p>
            <div className="mt-3">
              <AddressLink chainId={selectedChainId} address={launchToken} />
            </div>
          </>
        ) : (
          <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">
            No launch token is set yet. Use Swap on testnet if a market exists. We do not invent a
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
              After you buy the token, open Protocol DETF to mint, bond, and sell. Fees may apply.
              Amounts are not promises.
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
        <h2 className="text-base font-medium text-[var(--text-primary,#EDEDED)]">What this token is for</h2>
        <ul className="mt-2 list-disc pl-5 text-sm text-[var(--text-muted,#9aa3b2)] space-y-1">
          <li>Use the app: Earn, Swap, and Protocol DETF.</li>
          <li>Fee and bond uses are only real when they are live onchain.</li>
          <li>Votes need live vote contracts. We do not invent them here.</li>
          <li>There is no airdrop claim on this page.</li>
        </ul>
      </Card>
    </div>
  )
}
