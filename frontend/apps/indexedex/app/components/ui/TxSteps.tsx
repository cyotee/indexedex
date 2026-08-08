type Step = { id: string; label: string; status: 'pending' | 'active' | 'done' | 'error' }

export function TxSteps({ steps }: { steps: Step[] }) {
  return (
    <ol className="flex flex-col gap-1.5 text-xs">
      {steps.map((step, i) => (
        <li key={step.id} className="flex items-center gap-2 text-[var(--text-muted,#9aa3b2)]">
          <span
            className={[
              'inline-flex h-5 w-5 items-center justify-center rounded-full border text-[10px]',
              step.status === 'done'
                ? 'border-[var(--accent,#4FD44B)] text-[var(--accent,#4FD44B)]'
                : step.status === 'active'
                  ? 'border-sky-400 text-sky-300'
                  : step.status === 'error'
                    ? 'border-red-400 text-red-300'
                    : 'border-white/20',
            ].join(' ')}
          >
            {step.status === 'done' ? '✓' : i + 1}
          </span>
          <span
            className={
              step.status === 'active' || step.status === 'done'
                ? 'text-[var(--text-primary,#EDEDED)]'
                : undefined
            }
          >
            {step.label}
          </span>
        </li>
      ))}
    </ol>
  )
}

export default TxSteps
