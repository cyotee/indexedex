import type { ButtonHTMLAttributes, ReactNode } from 'react'

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger'
type Size = 'sm' | 'md' | 'lg'

export type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: Variant
  size?: Size
  loading?: boolean
  children: ReactNode
}

const variantClass: Record<Variant, string> = {
  primary:
    'bg-[var(--accent,#4FD44B)] text-black hover:brightness-110 border border-transparent font-semibold',
  secondary:
    'bg-[var(--surface-2,#1c2030)] text-[var(--text-primary,#EDEDED)] border border-[var(--border-subtle,rgba(255,255,255,0.08))] hover:border-[var(--border-accent,rgba(79,212,75,0.45))]',
  ghost:
    'bg-transparent text-[var(--text-muted,#9aa3b2)] border border-transparent hover:text-[var(--text-primary,#EDEDED)] hover:bg-white/5',
  danger: 'bg-[var(--danger,#E6386A)] text-white border border-transparent hover:brightness-110',
}

const sizeClass: Record<Size, string> = {
  sm: 'px-2.5 py-1 text-xs rounded-md',
  md: 'px-3.5 py-2 text-sm rounded-lg',
  lg: 'px-5 py-2.5 text-base rounded-lg',
}

export function Button({
  variant = 'primary',
  size = 'md',
  loading = false,
  disabled,
  className = '',
  children,
  type = 'button',
  ...rest
}: ButtonProps) {
  return (
    <button
      type={type}
      disabled={disabled || loading}
      className={[
        'inline-flex items-center justify-center gap-2 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--accent,#4FD44B)] focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--surface-0,#0a0a0a)] disabled:opacity-50 disabled:cursor-not-allowed',
        variantClass[variant],
        sizeClass[size],
        className,
      ].join(' ')}
      {...rest}
    >
      {loading ? <span className="opacity-80">…</span> : null}
      {children}
    </button>
  )
}

export default Button
