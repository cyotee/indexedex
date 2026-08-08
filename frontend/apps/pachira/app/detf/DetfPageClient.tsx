'use client'

/**
 * Legacy dual-token SeigniorageDETF UI removed.
 * True DETF UX rewrite is deferred; this route shell stays build-clean.
 */
export default function DetfPageClient() {
  return (
    <div className="p-6 max-w-xl mx-auto text-[var(--text-primary,#EDEDED)]">
      <h1 className="text-xl font-semibold mb-2">DETF (legacy route)</h1>
      <p className="text-sm text-[var(--text-muted,#9aa3b2)] mb-4">
        The dual-token SeigniorageDETF product has been removed. Browse strategy vaults and modern DETFs on Earn.
      </p>
      <a href="/earn" className="text-[var(--accent,#4FD44B)] underline text-sm">
        Go to Earn
      </a>
    </div>
  )
}
