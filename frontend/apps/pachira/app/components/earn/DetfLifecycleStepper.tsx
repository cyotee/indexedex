/**
 * DETF lifecycle steps — role names only (no RICH/RICHIR product brands).
 */
const STEPS = [
  { id: 'mint', label: 'Mint / exchange in' },
  { id: 'bond', label: 'Bond NFT' },
  { id: 'sell', label: 'Sell to protocol' },
  { id: 'claim', label: 'Claim / redeem' },
] as const

export function DetfLifecycleStepper({ activeIndex = 0 }: { activeIndex?: number }) {
  return (
    <ol className="grid grid-cols-2 md:grid-cols-4 gap-2" data-testid="detf-lifecycle-stepper">
      {STEPS.map((step, i) => {
        const active = i === activeIndex
        const done = i < activeIndex
        return (
          <li
            key={step.id}
            className={[
              'rounded-lg border px-3 py-2 text-xs',
              active
                ? 'border-[var(--border-accent,rgba(79,212,75,0.45))] bg-[var(--accent-muted,#1A3721)] text-[var(--text-primary,#EDEDED)]'
                : done
                  ? 'border-white/10 text-[var(--accent,#4FD44B)]'
                  : 'border-[var(--border-subtle,rgba(255,255,255,0.08))] text-[var(--text-muted,#9aa3b2)]',
            ].join(' ')}
          >
            <div className="font-mono text-[10px] opacity-70">0{i + 1}</div>
            <div className="mt-0.5 font-medium">{step.label}</div>
          </li>
        )
      })}
    </ol>
  )
}

export default DetfLifecycleStepper
