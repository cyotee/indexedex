import { Suspense } from 'react'

import InsightsPageClient from '../InsightsPageClient'

export default async function InsightsDetfPage({
  params,
}: {
  params: Promise<{ address: string }>
}) {
  const { address } = await params
  return (
    <Suspense fallback={<p className="text-sm text-[var(--text-muted,#9aa3b2)]">Loading insights…</p>}>
      <InsightsPageClient pathAddress={address} />
    </Suspense>
  )
}
