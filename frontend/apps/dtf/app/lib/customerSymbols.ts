/** DTF customer labels: on-chain/list ticker CHIR is shown as DTF-DETF. */
const CHIR_KEYS = new Set(['CHIR', 'TTCHIR'])

export function displayTokenSymbol(symbol: string | undefined | null): string {
  if (!symbol) return ''
  const stripped = symbol.replace(/^\$/, '')
  if (CHIR_KEYS.has(stripped.toUpperCase())) return 'DTF-DETF'
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
    else name = name.replace(/\bTTCHIR\b/gi, 'DTF-DETF').replace(/\bCHIR\b/gi, 'DTF-DETF')
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
}
