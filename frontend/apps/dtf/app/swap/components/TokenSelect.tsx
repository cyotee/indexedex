'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import { isAddress, type PublicClient } from 'viem'

import {
  ERC20_IMPORT_ABI,
  filterTokens,
  isImportableAddress,
  type SearchToken,
} from '../lib/tokenSearch'
import { ZERO_ADDRESS } from '../lib/v4Types'

export function TokenSelect({
  tokens,
  value,
  onChange,
  onImport,
  readClient,
  disabled,
  'data-testid': testId = 'token-select',
}: {
  tokens: SearchToken[]
  value: string
  onChange: (value: string) => void
  onImport?: (token: SearchToken) => void
  readClient?: PublicClient | null
  disabled?: boolean
  'data-testid'?: string
}) {
  const [open, setOpen] = useState(false)
  const [query, setQuery] = useState('')
  const [importing, setImporting] = useState(false)
  const [importError, setImportError] = useState<string | null>(null)
  const rootRef = useRef<HTMLDivElement>(null)

  const selected = tokens.find((t) => t.value === value) ?? tokens.find((t) => t.address.toLowerCase() === value.toLowerCase())
  const filtered = useMemo(() => filterTokens(tokens, query), [tokens, query])
  const canImport =
    isImportableAddress(query.trim()) &&
    !tokens.some((t) => t.address.toLowerCase() === query.trim().toLowerCase())

  useEffect(() => {
    if (!open) return
    const onDoc = (e: MouseEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', onDoc)
    return () => document.removeEventListener('mousedown', onDoc)
  }, [open])

  async function importToken() {
    const addr = query.trim()
    if (!isAddress(addr) || !readClient) return
    setImporting(true)
    setImportError(null)
    try {
      const [symbol, name, decimals] = await Promise.all([
        readClient.readContract({ address: addr, abi: ERC20_IMPORT_ABI, functionName: 'symbol' }) as Promise<string>,
        readClient.readContract({ address: addr, abi: ERC20_IMPORT_ABI, functionName: 'name' }) as Promise<string>,
        readClient.readContract({ address: addr, abi: ERC20_IMPORT_ABI, functionName: 'decimals' }) as Promise<number>,
      ])
      const token: SearchToken = {
        value: addr,
        label: symbol || addr.slice(0, 8),
        symbol: symbol || 'TOKEN',
        name: name || symbol || addr,
        address: addr,
        decimals: Number(decimals) || 18,
      }
      onImport?.(token)
      onChange(addr)
      setOpen(false)
      setQuery('')
    } catch {
      setImportError('Could not read that token on this network')
    } finally {
      setImporting(false)
    }
  }

  return (
    <div ref={rootRef} className="relative">
      <button
        type="button"
        data-testid={testId}
        disabled={disabled}
        onClick={() => setOpen((v) => !v)}
        className="min-w-[7.5rem] rounded-full border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm font-semibold text-[var(--text-primary,#EDEDED)] disabled:opacity-50"
      >
        {selected?.symbol ?? 'Select'}
      </button>
      {open ? (
        <div className="absolute right-0 z-30 mt-2 w-72 rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] p-2 shadow-xl">
          <input
            autoFocus
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search name or paste address"
            data-testid={`${testId}-search`}
            className="w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm text-[var(--text-primary,#EDEDED)]"
          />
          <ul className="mt-2 max-h-56 overflow-y-auto">
            {filtered.map((t) => (
              <li key={t.address === ZERO_ADDRESS ? 'ETH' : t.address}>
                <button
                  type="button"
                  className="flex w-full flex-col items-start rounded-lg px-3 py-2 text-left hover:bg-white/5"
                  onClick={() => {
                    onChange(String(t.value))
                    setOpen(false)
                    setQuery('')
                  }}
                >
                  <span className="text-sm font-medium text-[var(--text-primary,#EDEDED)]">{t.symbol}</span>
                  <span className="text-[11px] text-[var(--text-muted,#9aa3b2)]">{t.name}</span>
                </button>
              </li>
            ))}
          </ul>
          {filtered.length === 0 && !canImport ? (
            <p className="px-3 py-2 text-xs text-[var(--text-muted,#9aa3b2)]">No tokens match</p>
          ) : null}
          {canImport ? (
            <button
              type="button"
              className="mt-1 w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] px-3 py-2 text-left text-sm"
              onClick={() => void importToken()}
              disabled={importing || !readClient}
            >
              {importing ? 'Importing…' : `Import ${query.trim().slice(0, 10)}…`}
            </button>
          ) : null}
          {importError ? <p className="mt-1 px-3 text-xs text-[var(--danger,#E6386A)]">{importError}</p> : null}
        </div>
      ) : null}
    </div>
  )
}
