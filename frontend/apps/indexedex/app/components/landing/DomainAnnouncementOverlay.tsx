'use client'

import { useEffect, useRef, useState, type ReactNode } from 'react'

export function DomainAnnouncementOverlay({ children }: { children?: ReactNode }) {
  const dialogRef = useRef<HTMLDialogElement>(null)
  const [dismissed, setDismissed] = useState(false)

  useEffect(() => {
    if (dismissed) return
    const dialog = dialogRef.current
    dialog?.showModal()
    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      dialog?.close()
      document.body.style.overflow = previousOverflow
    }
  }, [dismissed])

  function dismiss() {
    setDismissed(true)
  }

  if (dismissed) return children ?? null

  return (
    <dialog
      ref={dialogRef}
      className="dtf-landing__stake-panel dtf-landing__migration-dialog dtf-domain-notice"
      aria-labelledby="domain-notice-title"
      aria-describedby="domain-notice-description"
      onCancel={event => { event.preventDefault(); dismiss() }}
      data-testid="domain-announcement-overlay"
    >
      <button type="button" className="dtf-landing__migration-close" aria-label="Close domain announcement" onClick={dismiss}>
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <path d="m6 6 12 12M18 6 6 18" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
        </svg>
      </button>
      <p className="dtf-landing__kicker">DTF &amp; IndexedEx</p>
      <h2 id="domain-notice-title">Same protocol. Another place to call home.</h2>
      <p id="domain-notice-description" className="dtf-landing__stake-lede">
        DTF is now also available at <strong>indexedex.com</strong>. Both domains serve the same protocol.
        You can keep using DTF here or visit IndexedEx. We’ll support both for the foreseeable future.
      </p>
      <div className="dtf-domain-notice__actions">
        <a href="https://indexedex.com" className="dtf-landing__btn dtf-landing__btn--primary">Go to indexedex.com</a>
        <button type="button" className="dtf-landing__btn dtf-landing__btn--ghost" onClick={dismiss}>Continue using DTF</button>
      </div>
      <section className="dtf-domain-notice__social" aria-labelledby="domain-notice-social">
        <h3 id="domain-notice-social">Our X account has changed.</h3>
        <p>The old DTF account on X is deprecated. Follow our new account, @Indexedex, for updates.</p>
        <a href="https://x.com/Indexedex" target="_blank" rel="noopener noreferrer" aria-label="Follow @Indexedex on X (opens in a new tab)">
          Follow @Indexedex on X <span aria-hidden="true">↗</span>
        </a>
      </section>
    </dialog>
  )
}
