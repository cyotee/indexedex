export function Stat({
  label,
  value,
  hint,
}: {
  label: string
  value: string
  hint?: string
}) {
  return (
    <div className="min-w-0">
      <div className="text-[11px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">{label}</div>
      <div
        className="mt-0.5 font-mono text-lg tabular-nums text-[var(--text-primary,#EDEDED)] truncate"
        title={hint || value}
      >
        {value}
      </div>
    </div>
  )
}

export default Stat
