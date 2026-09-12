import { Suspense } from 'react'

import { FirstBondClient } from '../FirstBondClient'

export const metadata = {
  title: 'Bond the DETF — IndexedEx',
}

export default function CreateBondPage() {
  return (
    <Suspense fallback={<p className="p-6 text-sm text-[var(--text-muted,#9aa3b2)]">Loading bond…</p>}>
      <FirstBondClient />
    </Suspense>
  )
}
