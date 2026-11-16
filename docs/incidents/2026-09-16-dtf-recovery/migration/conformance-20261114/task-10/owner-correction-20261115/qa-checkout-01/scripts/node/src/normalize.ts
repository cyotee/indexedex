import type { ManifestFragment, TokenInfo } from './types.js'

const MAX_SYMBOL = 20
const MAX_NAME = 60
const MAX_EXT_STRING = 42

export interface NormalizedToken {
  token: TokenInfo
  symbolTruncated: boolean
  nameTruncated: boolean
}

export function normalizeFragmentToToken(f: ManifestFragment, tags: string[]): NormalizedToken {
  const extensions = normalizeExtensions(f.extensions)
  let symbolTruncated = false
  let nameTruncated = false

  let symbol = f.symbol
  if (symbol.length > MAX_SYMBOL) {
    if (extensions['fullSymbol'] === undefined) {
      extensions['fullSymbol'] = symbol.slice(0, MAX_EXT_STRING)
    }
    symbol = symbol.slice(0, MAX_SYMBOL)
    symbolTruncated = true
  }
  symbol = symbol.replace(/\s+/g, '')

  let name = f.name
  if (name.length > MAX_NAME) {
    if (extensions['fullName'] === undefined) {
      extensions['fullName'] = name.slice(0, MAX_EXT_STRING)
    }
    name = name.slice(0, MAX_NAME)
    nameTruncated = true
  }

  const token: TokenInfo = {
    chainId: f.chainId,
    address: f.address,
    name,
    symbol,
    decimals: f.decimals,
    ...(tags.length > 0 ? { tags } : {}),
    ...(Object.keys(extensions).length > 0 ? { extensions } : {}),
  }

  return { token, symbolTruncated, nameTruncated }
}

function normalizeExtensions(input: Record<string, unknown> | undefined): Record<string, unknown> {
  if (!input) return {}
  const out: Record<string, unknown> = {}
  for (const [k, v] of Object.entries(input)) {
    out[k] = normalizeExtensionValue(v)
  }
  return out
}

function normalizeExtensionValue(v: unknown): unknown {
  if (Array.isArray(v)) {
    const obj: Record<string, unknown> = {}
    v.forEach((item, idx) => {
      obj[String(idx)] = normalizeExtensionValue(item)
    })
    return obj
  }
  if (v !== null && typeof v === 'object') {
    const obj: Record<string, unknown> = {}
    for (const [k, vv] of Object.entries(v as Record<string, unknown>)) {
      obj[k] = normalizeExtensionValue(vv)
    }
    return obj
  }
  return v
}
