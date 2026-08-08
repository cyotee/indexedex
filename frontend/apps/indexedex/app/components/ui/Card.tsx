import type { HTMLAttributes, ReactNode } from 'react'

export type CardProps = HTMLAttributes<HTMLDivElement> & {
  children: ReactNode
  accent?: boolean
  padding?: 'none' | 'sm' | 'md' | 'lg'
}

const pad: Record<NonNullable<CardProps['padding']>, string> = {
  none: '',
  sm: 'p-3',
  md: 'p-5',
  lg: 'p-6',
}

export function Card({
  children,
  accent = false,
  padding = 'md',
  className = '',
  ...rest
}: CardProps) {
  return (
    <div
      className={[
        'rounded-xl bg-[var(--surface-1,#14171f)] border',
        accent
          ? 'border-[var(--border-accent,rgba(79,212,75,0.45))] shadow-[0_0_0_1px_rgba(79,212,75,0.12)_inset]'
          : 'border-[var(--border-subtle,rgba(255,255,255,0.08))]',
        pad[padding],
        className,
      ].join(' ')}
      {...rest}
    >
      {children}
    </div>
  )
}

export default Card
