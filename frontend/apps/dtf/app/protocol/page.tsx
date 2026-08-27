import { Suspense } from 'react'

import ProtocolPageClient from './ProtocolPageClient'

export const metadata = {
  title: 'Protocol fees — Down To Finance',
  description: 'Vault Fee Oracle settings: usage, swap, bond, and the bond-holder pot, in human percents.',
}

export default function ProtocolPage() {
  return (
    <Suspense fallback={<p className="px-4 py-8 text-sm text-[var(--text-muted,#9aa3b2)]">Loading protocol fees…</p>}>
      <ProtocolPageClient />
    </Suspense>
  )
}
