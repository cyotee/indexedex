'use client'

import type { ReactNode } from 'react'

export type TabItem = { id: string; label: string }

export function Tabs({
  tabs,
  active,
  onChange,
}: {
  tabs: TabItem[]
  active: string
  onChange: (id: string) => void
}) {
  return (
    <div className="flex flex-wrap gap-1 border-b border-[var(--border-subtle,rgba(255,255,255,0.08))] mb-4">
      {tabs.map((tab) => {
        const isActive = tab.id === active
        return (
          <button
            key={tab.id}
            type="button"
            onClick={() => onChange(tab.id)}
            className={[
              'px-3 py-2 text-sm transition-colors border-b-2 -mb-px',
              isActive
                ? 'border-[var(--accent,#4FD44B)] text-[var(--text-primary,#EDEDED)]'
                : 'border-transparent text-[var(--text-muted,#9aa3b2)] hover:text-[var(--text-primary,#EDEDED)]',
            ].join(' ')}
          >
            {tab.label}
          </button>
        )
      })}
    </div>
  )
}

export function TabPanel({
  when,
  active,
  children,
}: {
  when: string
  active: string
  children: ReactNode
}) {
  if (when !== active) return null
  return <div>{children}</div>
}

export default Tabs
