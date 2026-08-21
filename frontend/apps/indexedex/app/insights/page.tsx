import { Suspense } from 'react'

import InsightsPageClient from './InsightsPageClient'

export const metadata = {
  title: 'DETFs — IndexedEx',
  description: 'DETFs from the vault registry: basket, mint and burn, then live price when the RPC can read them.',
}

export default function InsightsPage() {
  return (
    <Suspense fallback={<p className="text-sm text-[var(--text-muted,#9aa3b2)]">Loading insights…</p>}>
      <InsightsPageClient />
    </Suspense>
  )
}
