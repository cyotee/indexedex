import { explorerAddressUrl } from '../../lib/explorer'

export function AddressLink({
  chainId,
  address,
  className = '',
}: {
  chainId: number
  address: string
  className?: string
}) {
  const url = explorerAddressUrl(chainId, address)
  const short =
    address.length === 42 ? `${address.slice(0, 6)}…${address.slice(-4)}` : address

  if (!url) {
    return (
      <span className={`font-mono text-xs text-[var(--text-muted,#9aa3b2)] ${className}`} title={address}>
        {short}
      </span>
    )
  }

  return (
    <a
      href={url}
      target="_blank"
      rel="noreferrer"
      className={`font-mono text-xs text-[var(--accent,#4FD44B)] hover:underline ${className}`}
      title={address}
    >
      {short}
    </a>
  )
}

export default AddressLink
