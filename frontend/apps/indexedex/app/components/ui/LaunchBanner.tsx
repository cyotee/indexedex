'use client'

import Link from 'next/link'
import { getLaunchTokenAddress, isLaunchBannerEnabled } from '../../lib/lab'

/**
 * Sticky TGE strip — env-gated via NEXT_PUBLIC_SHOW_LAUNCH_BANNER=true.
 * Links only to real routes; never invents claim contracts or fake APY.
 */
export function LaunchBanner() {
  if (!isLaunchBannerEnabled()) return null

  const launchToken = getLaunchTokenAddress()
  const buyHref = launchToken ? `/swap?launch=1&tokenOut=${launchToken}` : '/token'

  return (
    <div
      className="border-b border-[var(--border-accent,rgba(79,212,75,0.35))] bg-[var(--accent-muted,#1A3721)]"
      data-testid="launch-banner"
    >
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-2 flex flex-wrap items-center justify-between gap-2 text-sm">
        <span className="text-[var(--text-primary,#EDEDED)]">
          {launchToken
            ? 'Token launch is on. Buy on Swap, then put it to work.'
            : 'Token launch strip is on. Set a launch token to enable a buy path.'}
        </span>
        <div className="flex gap-3">
          <Link href={buyHref} className="font-medium text-[var(--accent,#4FD44B)] hover:underline">
            {launchToken ? 'Buy via Swap' : 'Token page'}
          </Link>
          <Link
            href="/explore"
            className="text-[var(--text-muted,#9aa3b2)] hover:text-[var(--text-primary,#EDEDED)]"
          >
            Explore
          </Link>
          <Link
            href="/create"
            className="text-[var(--text-muted,#9aa3b2)] hover:text-[var(--text-primary,#EDEDED)]"
          >
            Create
          </Link>
          <Link
            href="/learn"
            className="text-[var(--text-muted,#9aa3b2)] hover:text-[var(--text-primary,#EDEDED)]"
          >
            Learn
          </Link>
        </div>
      </div>
    </div>
  )
}

export default LaunchBanner
