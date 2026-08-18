import { Suspense } from 'react'
import StakingPageClient from './StakingPageClient'

export default function StakingPage() {
  return (
    <Suspense fallback={<div className="p-6 text-sm text-[var(--text-muted,#9aa3b2)]">Loading Protocol DETF…</div>}>
      <StakingPageClient />
    </Suspense>
  )
}
