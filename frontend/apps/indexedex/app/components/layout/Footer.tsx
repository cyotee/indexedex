'use client'

import Link from 'next/link'
import { getAuditUrl, getDocsUrl } from '../../lib/lab'
import { useBrand } from '../../lib/brandContext'

export function Footer() {
  const { brand } = useBrand()
  const docsUrl = getDocsUrl()
  const auditUrl = getAuditUrl()

  return (
    <footer className="mt-auto border-t border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)]/80">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex flex-col gap-6 md:flex-row md:items-start md:justify-between">
          <div>
            <p className="text-sm font-medium text-[var(--text-primary,#EDEDED)]">{brand.name}</p>
            <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)] max-w-sm">{brand.tagline}</p>
            <p className="mt-3 text-xs text-[var(--text-muted,#9aa3b2)] italic">
              One token. A basket that works.
            </p>
          </div>
          <div className="flex flex-wrap gap-x-6 gap-y-2 text-sm">
            <Link href="/explore" className="text-[var(--text-muted,#9aa3b2)] hover:text-[var(--accent,#4FD44B)]">
              Explore
            </Link>
            <Link href="/insights" className="text-[var(--text-muted,#9aa3b2)] hover:text-[var(--accent,#4FD44B)]">
              DETFs
            </Link>
            <Link href="/create" className="text-[var(--text-muted,#9aa3b2)] hover:text-[var(--accent,#4FD44B)]">
              Create
            </Link>
            <Link href="/you" className="text-[var(--text-muted,#9aa3b2)] hover:text-[var(--accent,#4FD44B)]">
              You
            </Link>
            <Link href="/learn" className="text-[var(--text-muted,#9aa3b2)] hover:text-[var(--accent,#4FD44B)]">
              Learn
            </Link>
            <Link href="/swap" className="text-[var(--text-muted,#9aa3b2)] hover:text-[var(--accent,#4FD44B)]">
              Trade
            </Link>
            <Link href="/earn" className="text-[var(--text-muted,#9aa3b2)] hover:text-[var(--accent,#4FD44B)]">
              Vaults
            </Link>
            <a
              href={docsUrl}
              target="_blank"
              rel="noreferrer"
              className="text-[var(--text-muted,#9aa3b2)] hover:text-[var(--accent,#4FD44B)]"
            >
              Docs
            </a>
            {auditUrl ? (
              <a
                href={auditUrl}
                target="_blank"
                rel="noreferrer"
                className="text-[var(--text-muted,#9aa3b2)] hover:text-[var(--accent,#4FD44B)]"
              >
                Audits
              </a>
            ) : (
              <span className="text-[var(--text-muted,#9aa3b2)] opacity-70">Audits: pending</span>
            )}
          </div>
        </div>
        <p className="mt-6 text-[10px] text-[var(--text-muted,#9aa3b2)]">
          Smart contracts involve risk. APYs are not promises. Read the notes before you deposit.
        </p>
      </div>
    </footer>
  )
}

export default Footer
