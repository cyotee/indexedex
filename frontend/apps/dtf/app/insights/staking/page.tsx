'use client'

import { Suspense, useEffect } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'

import { insightsStakingHref } from '../lib/claimMint'

function RedirectToInsightsStake() {
  const router = useRouter()
  const searchParams = useSearchParams()

  useEffect(() => {
    const detf = searchParams.get('detf')
    router.replace(detf ? insightsStakingHref(detf) : '/insights?tab=stake')
  }, [router, searchParams])

  return <p className="text-sm text-[var(--text-muted,#9aa3b2)]">Opening stake…</p>
}

export default function InsightsStakingRedirectPage() {
  return (
    <Suspense fallback={<p className="text-sm text-[var(--text-muted,#9aa3b2)]">Opening stake…</p>}>
      <RedirectToInsightsStake />
    </Suspense>
  )
}
