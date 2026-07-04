'use client'

import Link from 'next/link'
import { isLaunchBannerEnabled } from '../../lib/lab'

export function LaunchBanner() {
  if (!isLaunchBannerEnabled()) return null

  return (
    <div className="border-b border-[var(--border-accent,rgba(79,212,75,0.35))] bg-[var(--accent-muted,#1A3721)]">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-2 flex flex-wrap items-center justify-between gap-2 text-sm">
        <span className="text-[var(--text-primary,#EDEDED)]">
          Token launch mode — buy then put it to work in Earn.
        </span>
        <div className="flex gap-3">
          <Link href="/token" className="font-medium text-[var(--accent,#4FD44B)] hover:underline">
            Get token
          </Link>
          <Link href="/earn" className="text-[var(--text-muted,#9aa3b2)] hover:text-[var(--text-primary,#EDEDED)]">
            Earn
          </Link>
        </div>
      </div>
    </div>
  )
}

export default LaunchBanner
