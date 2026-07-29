'use client'

import { useCallback, useState } from 'react'
import { explorerAddressUrl } from '../../lib/explorer'

export function AddressLink({
  chainId,
  address,
  className = '',
  showCopy = true,
}: {
  chainId: number
  address: string
  className?: string
  /** Copy-to-clipboard control (default true). */
  showCopy?: boolean
}) {
  const url = explorerAddressUrl(chainId, address)
  const short =
    address.length === 42 ? `${address.slice(0, 6)}…${address.slice(-4)}` : address
  const [copied, setCopied] = useState(false)

  const handleCopy = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(address)
      setCopied(true)
      setTimeout(() => setCopied(false), 1500)
    } catch {
      // Fallback for environments without clipboard API
      try {
        const ta = document.createElement('textarea')
        ta.value = address
        ta.setAttribute('readonly', '')
        ta.style.position = 'absolute'
        ta.style.left = '-9999px'
        document.body.appendChild(ta)
        ta.select()
        document.execCommand('copy')
        document.body.removeChild(ta)
        setCopied(true)
        setTimeout(() => setCopied(false), 1500)
      } catch {
        /* ignore */
      }
    }
  }, [address])

  const monoClass = `font-mono text-xs text-[var(--text-muted,#9aa3b2)] ${className}`
  const linkClass = `font-mono text-xs text-[var(--accent,#4FD44B)] hover:underline ${className}`

  return (
    <span className="inline-flex items-center gap-1.5" data-testid="address-link">
      {url ? (
        <a
          href={url}
          target="_blank"
          rel="noreferrer"
          className={linkClass}
          title={address}
        >
          {short}
        </a>
      ) : (
        <span className={monoClass} title={address}>
          {short}
        </span>
      )}
      {showCopy ? (
        <button
          type="button"
          data-testid="address-link-copy"
          onClick={() => void handleCopy()}
          className="rounded px-1 py-0.5 text-[10px] text-[var(--text-muted,#9aa3b2)] hover:bg-white/5 hover:text-[var(--text-primary,#EDEDED)]"
          title="Copy address"
          aria-label="Copy address"
        >
          {copied ? 'Copied' : 'Copy'}
        </button>
      ) : null}
    </span>
  )
}

export default AddressLink
