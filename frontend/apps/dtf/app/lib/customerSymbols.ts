/** DTF customer labels: on-chain/list ticker CHIR is shown as DTF-DETF. */
const CHIR_KEYS = new Set(['CHIR', 'TTCHIR'])
/** Retired IndexedEx brands. DTF does not list these as DETFs. */
const RICH_KEYS = new Set(['RICH', 'TTRICH', 'RICHIR', 'TTRICHIR'])

function strippedTicker(value: string): string {
  return value.replace(/^\$/, '').trim().toUpperCase()
}

/** True when a list label is the retired RICH / RICHIR ticker. */
export function isRetiredRichBrand(value: string | undefined | null): boolean {
  if (!value) return false
  return RICH_KEYS.has(strippedTicker(value))
}

export function isRetiredRichEntry(entry: {
  symbol?: string
  name?: string
  display?: string
}): boolean {
  return (
    isRetiredRichBrand(entry.symbol) ||
    isRetiredRichBrand(entry.display) ||
    isRetiredRichBrand(entry.name)
  )
}

export function omitRetiredRichEntries<T extends { symbol?: string; name?: string; display?: string }>(
  list: T[],
): T[] {
  return list.filter((entry) => !isRetiredRichEntry(entry))
}

export function displayTokenSymbol(symbol: string | undefined | null): string {
  if (!symbol) return ''
  const stripped = symbol.replace(/^\$/, '')
  const key = stripped.toUpperCase()
  if (CHIR_KEYS.has(key)) return 'DTF-DETF'
  if (key === 'RICHIR' || key === 'TTRICHIR') return 'DTF-CLAIM'
  if (RICH_KEYS.has(key)) return 'DTF'
  return stripped
}

export function displayTokenTicker(symbol: string | undefined | null): string {
  const s = displayTokenSymbol(symbol)
  return s ? `$${s}` : '$DTF-DETF'
}

export function relabelChirEntry<T extends { symbol?: string; name?: string; display?: string }>(
  entry: T,
): T {
  const symbol = displayTokenSymbol(entry.symbol)
  const display = entry.display ? displayTokenSymbol(entry.display) || entry.display : entry.display
  let name = entry.name
  if (name) {
    if (/protocol\s+detf\s+(tt)?chir/i.test(name)) name = 'Protocol DETF'
    else {
      name = name
        .replace(/\bTTCHIR\b/gi, 'DTF-DETF')
        .replace(/\bCHIR\b/gi, 'DTF-DETF')
        .replace(/\bTTRICHIR\b/gi, 'DTF-CLAIM')
        .replace(/\bRICHIR\b/gi, 'DTF-CLAIM')
        .replace(/\bTTRICH\b/gi, 'DTF')
        .replace(/\bRICH\b/gi, 'DTF')
    }
  }
  return {
    ...entry,
    ...(symbol ? { symbol } : {}),
    ...(display ? { display } : {}),
    ...(name ? { name } : {}),
  }
}

export function relabelChirList<T extends { symbol?: string; name?: string; display?: string }>(
  list: T[],
): T[] {
  return list.map(relabelChirEntry)
}

export function displayTokenLabel(label: string): string {
  return label
    .replace(/\$CHIR\b/gi, '$DTF-DETF')
    .replace(/\bTTCHIR\b/gi, 'DTF-DETF')
    .replace(/\bCHIR\b/gi, 'DTF-DETF')
    .replace(/\$RICHIR\b/gi, '$DTF-CLAIM')
    .replace(/\bTTRICHIR\b/gi, 'DTF-CLAIM')
    .replace(/\bRICHIR\b/gi, 'DTF-CLAIM')
    .replace(/\$RICH\b/gi, '$DTF')
    .replace(/\bTTRICH\b/gi, 'DTF')
    .replace(/\bRICH\b/gi, 'DTF')
}
