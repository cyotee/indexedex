import type { ReactNode } from 'react'
import { Card } from './Card'

export function EmptyState({
  title,
  body,
  action,
}: {
  title: string
  body?: string
  action?: ReactNode
}) {
  return (
    <Card className="text-center py-10">
      <h3 className="text-base font-medium text-[var(--text-primary,#EDEDED)]">{title}</h3>
      {body ? <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)] max-w-md mx-auto">{body}</p> : null}
      {action ? <div className="mt-4 flex justify-center">{action}</div> : null}
    </Card>
  )
}

export default EmptyState
