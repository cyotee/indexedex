'use client'

import Link from 'next/link'
import { useEffect, useRef, useState } from 'react'

import { appPath } from '../../lib/siteOrigins'

export function TokenStakingOverlay() {
  const dialogRef = useRef<HTMLDialogElement>(null)
  const [visible, setVisible] = useState(true)

  useEffect(() => {
    if (!visible) return

    dialogRef.current?.showModal()
    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      document.body.style.overflow = previousOverflow
    }
  }, [visible])

  if (!visible) return null

  return (
    <dialog
      ref={dialogRef}
      className="dtf-landing__stake-panel dtf-landing__migration-dialog"
      aria-labelledby="token-staking-title"
      aria-describedby="token-staking-description"
      onClose={() => setVisible(false)}
      data-testid="token-staking-overlay"
    >
      <button
        type="button"
        className="dtf-landing__migration-close"
        aria-label="Close migration notice"
        onClick={() => dialogRef.current?.close()}
      >
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <path d="m6 6 12 12M18 6 6 18" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
        </svg>
      </button>
      <p className="dtf-landing__kicker">DTF-DETF staking</p>
      <h2 id="token-staking-title">Migration complete</h2>
      <p id="token-staking-description" className="dtf-landing__stake-lede">
        You can now view your DTF-DETF rewards on the staking page.
      </p>
      <Link
        href={appPath('/staking')}
        className="dtf-landing__btn dtf-landing__btn--primary dtf-landing__stake-cta"
      >
        Go to staking
      </Link>
    </dialog>
  )
}
