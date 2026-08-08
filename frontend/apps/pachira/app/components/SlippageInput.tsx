'use client'

interface SlippageInputProps {
  value: number
  onChange: (value: number) => void
  label?: string
  className?: string
}

const presetSlippages = [0.1, 0.5, 1]

export default function SlippageInput({
  value,
  onChange,
  label = 'Slippage (%)',
  className = '',
}: SlippageInputProps) {
  return (
    <div className={className}>
      <label className="block text-xs text-gray-400">{label}</label>
      <input
        value={Number.isFinite(value) ? String(value) : ''}
        onChange={(event) => onChange(Number(event.target.value))}
        className="mt-1 w-full rounded-md border border-gray-700 bg-gray-950 px-3 py-2 text-sm text-gray-100"
      />
      <div className="mt-2 flex gap-2">
        {presetSlippages.map((preset) => (
          <button
            key={preset}
            type="button"
            onClick={() => onChange(preset)}
            className={`rounded-md border px-2 py-1 text-xs transition-colors ${value === preset ? 'border-cyan-400 bg-cyan-500/20 text-cyan-200' : 'border-slate-600 bg-slate-800 text-gray-300 hover:border-slate-500'}`}
          >
            {preset}%
          </button>
        ))}
      </div>
    </div>
  )
}