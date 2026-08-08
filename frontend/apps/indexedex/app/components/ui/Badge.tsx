import type { ReactNode } from 'react'

type Tone = 'neutral' | 'accent' | 'warning' | 'danger' | 'info'

export function Badge({
  children,
  tone = 'neutral',
  className = '',
}: {
  children: ReactNode
  tone?: Tone
  className?: string
}) {
  const tones: Record<Tone, string> = {
    neutral: 'bg-white/5 text-[var(--text-muted,#9aa3b2)] border-white/10',
    accent: 'bg-[var(--accent-muted,#1A3721)] text-[var(--accent,#4FD44B)] border-[var(--border-accent,rgba(79,212,75,0.35))]',
    warning: 'bg-orange-500/10 text-orange-300 border-orange-500/30',
    danger: 'bg-red-500/10 text-red-300 border-red-500/30',
    info: 'bg-sky-500/10 text-sky-300 border-sky-500/30',
  }
  return (
    <span
      className={[
        'inline-flex items-center rounded-full border px-2 py-0.5 text-[11px] font-medium uppercase tracking-wide',
        tones[tone],
        className,
      ].join(' ')}
    >
      {children}
    </span>
  )
}

export default Badge
