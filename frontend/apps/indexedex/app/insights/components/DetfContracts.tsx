'use client'

import type { Hex } from 'viem'

import { AddressLink } from '../../components/ui/AddressLink'
import { Card } from '../../components/ui/Card'
import { CopyButton } from '../../components/ui/CopyButton'
import type { DetfRelatedAddress } from '../lib/relatedAddresses'
import type { DetfPoolIdRow } from '../lib/useDetfPoolIds'

export type ContractRow = DetfRelatedAddress & {
  symbol: string
  name: string
}

function PoolIdRow({
  label,
  id,
}: {
  label: string
  id: Hex
}) {
  return (
    <li className="flex flex-col gap-1 py-3 sm:flex-row sm:items-start sm:justify-between sm:gap-4">
      <div>
        <div className="text-sm text-[var(--text-primary,#EDEDED)]">
          {label}{' '}
          <span className="text-[11px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">
            Pool ID
          </span>
        </div>
        <div className="text-[11px] text-[var(--text-muted,#9aa3b2)]">
          Uniswap v4 pool ID. Not a contract address.
        </div>
      </div>
      <span className="inline-flex max-w-full flex-wrap items-center gap-1.5" data-testid="insights-pool-id">
        <span className="break-all font-mono text-xs text-[var(--text-muted,#9aa3b2)]" title={id}>
          {id}
        </span>
        <CopyButton value={id} testId="insights-pool-id-copy" ariaLabel={`Copy ${id}`} />
      </span>
    </li>
  )
}

export function DetfContracts({
  rows,
  chainId,
  reservePoolId,
  sePoolIds,
}: {
  rows: ContractRow[]
  chainId: number
  reservePoolId?: Hex
  sePoolIds?: DetfPoolIdRow[]
}) {
  const ids = sePoolIds ?? []
  if (rows.length === 0 && !reservePoolId && ids.length === 0) return null
  return (
    <Card>
      <p className="text-[11px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">Contracts</p>
      <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)]">
        Every address this DETF uses. Copy the full address, or open it on the explorer when this
        network has one.
      </p>
      <ul className="mt-4 divide-y divide-[var(--border-subtle,rgba(255,255,255,0.08))]" data-testid="insights-contracts">
        {rows.map((row) => (
          <li key={`${row.role}-${row.address}`} className="flex flex-col gap-1 py-3 sm:flex-row sm:items-start sm:justify-between sm:gap-4">
            <div>
              <div className="text-sm text-[var(--text-primary,#EDEDED)]">
                {row.symbol}{' '}
                <span className="text-[11px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">
                  {row.role}
                </span>
              </div>
              <div className="text-[11px] text-[var(--text-muted,#9aa3b2)]">{row.name}</div>
            </div>
            <AddressLink chainId={chainId} address={row.address} display="full" />
          </li>
        ))}
        {reservePoolId ? <PoolIdRow label="Reserve pool" id={reservePoolId} /> : null}
        {ids.map((row) => (
          <PoolIdRow key={`${row.role}-${row.id}`} label={row.role} id={row.id} />
        ))}
      </ul>
    </Card>
  )
}
