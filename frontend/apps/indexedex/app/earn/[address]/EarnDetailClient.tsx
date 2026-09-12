'use client'

import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { useEffect, useMemo, useState } from 'react'
import { useReadContract } from 'wagmi'
import { formatUnits } from 'viem'

import { DepositPanel } from '../../components/earn/DepositPanel'
import { DetfLifecycleStepper } from '../../components/earn/DetfLifecycleStepper'
import { DetfWorkspaceEmbed } from '../../components/earn/detf/DetfWorkspaceEmbed'
import { ProductTypeBadge } from '../../components/earn/ProductTypeBadge'
import { RiskBadge } from '../../components/earn/RiskBadge'
import { AddressLink } from '../../components/ui/AddressLink'
import { Badge } from '../../components/ui/Badge'
import { Button } from '../../components/ui/Button'
import { Card } from '../../components/ui/Card'
import { EmptyState } from '../../components/ui/EmptyState'
import { PageHeader } from '../../components/ui/PageHeader'
import { Stat } from '../../components/ui/Stat'
import { TabPanel, Tabs } from '../../components/ui/Tabs'
import { findEarnProduct } from '../../lib/earn/loadEarnProducts'
import { RISK_LEVEL_LABEL } from '@indexedex/protocol/earn/riskFromTags'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'
import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'
import { feeDetfStakingHref, isFeaturedFeeDetfAddress } from '@indexedex/protocol/tokenlists'

const vaultAbi = [
  {
    type: 'function',
    name: 'tokens',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address[]' }],
  },
  {
    type: 'function',
    name: 'reserves',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256[]' }],
  },
] as const

const erc20MetaAbi = [
  { type: 'function', name: 'symbol', stateMutability: 'view', inputs: [], outputs: [{ type: 'string' }] },
  { type: 'function', name: 'decimals', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint8' }] },
] as const

function isAddress(value: string): value is `0x${string}` {
  return /^0x[0-9a-fA-F]{40}$/.test(value)
}

function productKindLabel(productType: string): string {
  if (productType === 'strategy') return 'Building-block vault'
  if (productType === 'protocol-detf') return 'Protocol DETF'
  if (productType === 'detf') return 'DETF'
  return productType
}

export default function EarnDetailClient({ address }: { address: string }) {
  const router = useRouter()
  const { selectedChainId } = useSelectedNetwork()
  const { environment } = useDeploymentEnvironment()
  const [tab, setTab] = useState('overview')

  // Fee Protocol DETF only → /staking. Lab DETFs stay on /earn/[address] with their own workspace.
  const isFeeDetf = useMemo(() => {
    if (!isAddress(address)) return false
    return isFeaturedFeeDetfAddress(selectedChainId, environment, address)
  }, [address, selectedChainId, environment])

  useEffect(() => {
    if (!isFeeDetf || !isAddress(address)) return
    router.replace(feeDetfStakingHref(address))
  }, [isFeeDetf, address, router])

  const product = useMemo(() => {
    if (!isAddress(address)) return undefined
    if (isFeaturedFeeDetfAddress(selectedChainId, environment, address)) return undefined
    return findEarnProduct(selectedChainId, address, environment)
  }, [address, selectedChainId, environment])

  /** Lab / non-fee DETF — mint/bond/sell live on this page. */
  const isLabDetf = product?.productType === 'detf'
  /** Any DETF-shaped product (lab uses `detf`; fee brand would be protocol-detf but is redirected). */
  const isDetfProduct =
    product?.productType === 'detf' || product?.productType === 'protocol-detf'

  // Default lab DETF visitors to the actions workspace.
  useEffect(() => {
    if (isLabDetf) setTab('actions')
  }, [isLabDetf, address])

  const vaultAddress = product?.address

  const { data: tokens } = useReadContract({
    address: vaultAddress,
    abi: vaultAbi,
    functionName: 'tokens',
    chainId: selectedChainId,
    query: { enabled: !!vaultAddress && product?.productType === 'strategy' },
  })

  const { data: reserves } = useReadContract({
    address: vaultAddress,
    abi: vaultAbi,
    functionName: 'reserves',
    chainId: selectedChainId,
    query: { enabled: !!vaultAddress && product?.productType === 'strategy' },
  })

  const tokenList = Array.isArray(tokens) ? (tokens as `0x${string}`[]) : []
  const reserveList = Array.isArray(reserves) ? (reserves as bigint[]) : []

  if (isFeeDetf && isAddress(address)) {
    return (
      <EmptyState
        title="Redirecting to Protocol DETF"
        body="The fee Protocol DETF lives on /staking, not Earn."
        action={
          <Link href={feeDetfStakingHref(address)}>
            <Button variant="secondary" size="sm">
              Open Protocol DETF workspace
            </Button>
          </Link>
        }
      />
    )
  }

  if (!isAddress(address) || !product) {
    return (
      <EmptyState
        title="Product not found"
        body="This address is not on the Earn catalog for the active chain and environment."
        action={
          <Link href="/earn">
            <Button variant="secondary" size="sm">
              Back to Earn
            </Button>
          </Link>
        }
      />
    )
  }

  return (
    <div>
      <div className="mb-4">
        <Link href="/earn" className="text-sm text-[var(--text-muted,#9aa3b2)] hover:text-[var(--accent,#4FD44B)]">
          ← Earn
        </Link>
      </div>

      <PageHeader
        title={product.symbol || product.display || product.name}
        subtitle={
          product.display && product.display !== product.symbol
            ? `${product.display} · ${productKindLabel(product.productType)}`
            : productKindLabel(product.productType)
        }
        actions={
          <div className="flex flex-wrap gap-2 items-center">
            <ProductTypeBadge type={product.productType} />
            <RiskBadge level={product.risk} />
            <Badge tone="neutral">Chain {selectedChainId}</Badge>
          </div>
        }
      />

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <Card padding="sm">
          <Stat label="APY" value="—" hint="Not fabricated; connect indexer later" />
        </Card>
        <Card padding="sm">
          <Stat label="Type" value={productKindLabel(product.productType)} />
        </Card>
        <Card padding="sm">
          <Stat label="Decimals" value={String(product.decimals)} />
        </Card>
        <Card padding="sm">
          <div className="text-[11px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">Contract</div>
          <div className="mt-1">
            <AddressLink chainId={selectedChainId} address={product.address} />
          </div>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">
        <div className={isLabDetf ? 'lg:col-span-5' : 'lg:col-span-3'}>
          <Tabs
            tabs={[
              { id: 'overview', label: 'Overview' },
              ...(isLabDetf ? [{ id: 'actions', label: 'Mint / bond / sell' }] : []),
              { id: 'composition', label: 'Composition' },
              { id: 'risks', label: 'Risks' },
            ]}
            active={tab}
            onChange={setTab}
          />

          <TabPanel when="overview" active={tab}>
            <Card>
              {product.productType === 'strategy' ? (
                <>
                  <h3 className="text-sm font-medium text-[var(--text-primary,#EDEDED)]">Building-block vault</h3>
                  <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">
                    This vault wraps another app. Deposit to get a vault share. That share is a receipt
                    for your deposit. The mix onchain shows when we can read it.
                  </p>
                </>
              ) : (
                <>
                  <h3 className="text-sm font-medium text-[var(--text-primary,#EDEDED)]">DETF lifecycle</h3>
                  <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)] mb-4">
                    Mint to get DETF tokens. Bond to lock money in. Sell a mature bond. Claim when that
                    path is open. Use the <strong className="text-[var(--text-primary,#EDEDED)]">Mint / bond / sell</strong>{' '}
                    tab. Actions stay on this page.
                  </p>
                  <DetfLifecycleStepper activeIndex={0} />
                  {isLabDetf ? (
                    <div className="mt-4">
                      <Button variant="secondary" size="sm" onClick={() => setTab('actions')}>
                        Go to mint / bond / sell
                      </Button>
                    </div>
                  ) : null}
                </>
              )}
            </Card>
          </TabPanel>

          {isLabDetf ? (
            <TabPanel when="actions" active={tab}>
              <DetfWorkspaceEmbed detfAddress={product.address} symbol={product.symbol} />
            </TabPanel>
          ) : null}

          <TabPanel when="composition" active={tab}>
            <Card>
              <h3 className="text-sm font-medium text-[var(--text-primary,#EDEDED)] mb-3">
                Where is my money?
              </h3>
              {isDetfProduct ? (
                <p className="text-sm text-[var(--text-muted,#9aa3b2)]">
                  DETF composition is dynamic (reserve pool, bond NFT, rebasing claim token). Use mint / bond / sell
                  on this page for live thresholds and positions for this DETF.
                </p>
              ) : tokenList.length === 0 ? (
                <p className="text-sm text-[var(--text-muted,#9aa3b2)]">
                  Unable to read vault tokens (RPC or ABI). Contract still listed from tokenlist.
                </p>
              ) : (
                <ul className="space-y-2">
                  {tokenList.map((tok, i) => (
                    <CompositionRow
                      key={tok}
                      token={tok}
                      reserve={reserveList[i]}
                      chainId={selectedChainId}
                    />
                  ))}
                </ul>
              )}
            </Card>
          </TabPanel>

          <TabPanel when="risks" active={tab}>
            <Card>
              <ul className="list-disc pl-5 text-sm text-[var(--text-muted,#9aa3b2)] space-y-2">
                {product.risk ? (
                  <li>
                    Tokenlist risk label:{' '}
                    <strong className="text-[var(--text-primary,#EDEDED)]">{RISK_LEVEL_LABEL[product.risk]}</strong>
                    {' '}(from list tags only — not a guarantee or credit rating).
                  </li>
                ) : null}
                <li>Smart-contract risk on vault, router, and underlying venues.</li>
                <li>Impermanent loss and market risk for LP-based strategies.</li>
                <li>DETF bond locks may delay full redemption until unlock.</li>
                <li>APYs shown elsewhere are not guarantees; this UI does not invent APY.</li>
                <li>Always verify contract addresses on a block explorer.</li>
              </ul>
            </Card>
          </TabPanel>
        </div>

        {!isLabDetf ? (
          <div className="lg:col-span-2">
            <DepositPanel product={product} chainId={selectedChainId} />
            <p className="mt-3 text-center text-xs text-[var(--text-muted,#9aa3b2)]">
              After deposit, check{' '}
              <Link href="/portfolio" className="text-[var(--accent,#4FD44B)] hover:underline">
                Portfolio
              </Link>
              .
            </p>
          </div>
        ) : null}
      </div>
    </div>
  )
}

function CompositionRow({
  token,
  reserve,
  chainId,
}: {
  token: `0x${string}`
  reserve?: bigint
  chainId: number
}) {
  const { data: symbol } = useReadContract({
    address: token,
    abi: erc20MetaAbi,
    functionName: 'symbol',
    chainId,
  })
  const { data: decimals } = useReadContract({
    address: token,
    abi: erc20MetaAbi,
    functionName: 'decimals',
    chainId,
  })
  const dec = typeof decimals === 'number' ? decimals : 18
  const amount =
    typeof reserve === 'bigint' ? formatUnits(reserve, dec) : '—'

  return (
    <li className="flex items-center justify-between gap-2 text-sm border-b border-[var(--border-subtle,rgba(255,255,255,0.06))] pb-2">
      <div>
        <span className="text-[var(--text-primary,#EDEDED)]">{String(symbol || 'Token')}</span>
        <div>
          <AddressLink chainId={chainId} address={token} />
        </div>
      </div>
      <span className="font-mono tabular-nums text-[var(--text-muted,#9aa3b2)]">{amount}</span>
    </li>
  )
}
