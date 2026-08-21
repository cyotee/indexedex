import { Suspense } from 'react'

import { CreateWizard } from './CreateWizard'
import type { CreateDetfTypeId } from './detfTypes'

export function CreatePageFrame({ initialTypeId }: { initialTypeId?: CreateDetfTypeId }) {
  return (
    <Suspense fallback={<p className="text-sm text-[var(--text-muted,#9aa3b2)]">Loading create…</p>}>
      <CreateWizard initialTypeId={initialTypeId} />
    </Suspense>
  )
}
