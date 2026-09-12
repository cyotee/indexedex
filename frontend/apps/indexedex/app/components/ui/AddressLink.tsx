'use client'

import { getAddress } from 'viem'

import { explorerAddressUrl } from '../../lib/explorer'
import { isLocalRobinhoodTestnet } from '../../lib/localRpc'
import { CopyButton } from './CopyButton'

function checksum(addr: string): string {
  try {
    return getAddress(addr)
  } catch {
    return addr
  }
}

function shortAddr(addr: string): string {
  if (addr.length === 42) return `${addr.slice(0, 6)}…${addr.slice(-4)}`
  if (addr.length === 66) return `${addr.slice(0, 10)}…${addr.slice(-8)}`
  return addr
}

export function AddressLink({
  chainId,
  address,
  className = '',
  showCopy = true,
  display = 'short',
}: {
  chainId: number
  address: string
  className?: string
  /** Copy-to-clipboard control (default true). */
  showCopy?: boolean
  /** `short` is 0x1234…abcd. `full` is the checksummed address. */
  display?: 'short' | 'full'
}) {
  const full = checksum(address)
  const url = explorerAddressUrl(chainId, full, isLocalRobinhoodTestnet())
  const shown = display === 'full' ? full : shortAddr(full)

  const monoClass = `break-all font-mono text-xs text-[var(--text-muted,#9aa3b2)] ${className}`
  const linkClass = `break-all font-mono text-xs text-[var(--accent,#4FD44B)] underline-offset-2 hover:underline ${className}`

  return (
    <span className="inline-flex max-w-full flex-wrap items-center gap-1.5" data-testid="address-link">
      {url ? (
        <a href={url} target="_blank" rel="noreferrer" className={linkClass} title={full}>
          {shown}
        </a>
      ) : (
        <span className={monoClass} title={full}>
          {shown}
        </span>
      )}
      {showCopy ? <CopyButton value={full} testId="address-link-copy" ariaLabel={`Copy ${full}`} /> : null}
    </span>
  )
}

export default AddressLink
