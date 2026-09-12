import { Suspense } from 'react'

import InsightsPageClient from '../InsightsPageClient'

export default function InsightsDetfPage({
  params,
}: {
  params: { address: string }
}) {
  return (
    <Suspense fallback={<p className="text-sm text-[var(--text-muted,#9aa3b2)]">Loading insights…</p>}>
      <InsightsPageClient pathAddress={params.address} />
    </Suspense>
  )
}
