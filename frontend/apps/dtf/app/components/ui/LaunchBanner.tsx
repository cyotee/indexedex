'use client'

import Link from 'next/link'
import { getLaunchTokenAddress, isLaunchBannerEnabled } from '../../lib/lab'

/**
 * Sticky TGE strip. Env-gated via NEXT_PUBLIC_SHOW_LAUNCH_BANNER=true.
 * Links only to real routes; never invents claim contracts or fake APY.
 */
export function LaunchBanner() {
  if (!isLaunchBannerEnabled()) return null

  const launchToken = getLaunchTokenAddress()
  const buyHref = launchToken ? `/swap?launch=1&tokenOut=${launchToken}` : '/swap'

  return (
    <div
      className="border-b border-[var(--border-accent,rgba(79,212,75,0.35))] bg-[var(--accent-muted,#1A3721)]"
      data-testid="launch-banner"
    >
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-2 flex flex-wrap items-center justify-between gap-2 text-sm">
        <span className="text-[var(--text-primary,#EDEDED)]">
          {launchToken
            ? 'Token launch mode. Buy via Swap, then put capital to work.'
            : 'Token launch strip enabled. Set NEXT_PUBLIC_LAUNCH_TOKEN_ADDRESS for a direct buy path.'}
        </span>
        <div className="flex gap-3">
          <Link href={buyHref} className="font-medium text-[var(--accent,#4FD44B)] hover:underline">
            Buy via Swap
          </Link>
          <Link
            href="/staking"
            className="text-[var(--text-muted,#9aa3b2)] hover:text-[var(--text-primary,#EDEDED)]"
          >
            Protocol DETF
          </Link>
          <Link
            href="/earn"
            className="text-[var(--text-muted,#9aa3b2)] hover:text-[var(--text-primary,#EDEDED)]"
          >
            Earn
          </Link>
        </div>
      </div>
    </div>
  )
}

export default LaunchBanner
