'use client'

import { useCallback, useState } from 'react'

export function CopyButton({
  value,
  label = 'Copy',
  copiedLabel = 'Copied',
  ariaLabel,
  testId,
}: {
  value: string
  label?: string
  copiedLabel?: string
  ariaLabel?: string
  testId?: string
}) {
  const [copied, setCopied] = useState(false)

  const handleCopy = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(value)
      setCopied(true)
      setTimeout(() => setCopied(false), 1500)
    } catch {
      try {
        const ta = document.createElement('textarea')
        ta.value = value
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
  }, [value])

  return (
    <button
      type="button"
      data-testid={testId ?? 'copy-button'}
      onClick={() => void handleCopy()}
      className="shrink-0 rounded px-1 py-0.5 text-[10px] text-[var(--text-muted,#9aa3b2)] hover:bg-white/5 hover:text-[var(--text-primary,#EDEDED)]"
      title={ariaLabel ?? `Copy ${value}`}
      aria-label={ariaLabel ?? `Copy ${value}`}
    >
      {copied ? copiedLabel : label}
    </button>
  )
}

export default CopyButton
