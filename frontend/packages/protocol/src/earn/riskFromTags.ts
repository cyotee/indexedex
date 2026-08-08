/**
 * Risk labels for Earn products — list/tokenlist tags only.
 * Never invent a level when tags/extensions are absent or unrecognized.
 *
 * Canonical tokenlist tag ids (prefer these):
 *   risk-conservative | risk-balanced | risk-experimental
 *
 * Also accepted (case-insensitive):
 *   risk:conservative | risk/balanced | extensions.risk = "conservative" | …
 */

export type RiskLevel = 'conservative' | 'balanced' | 'experimental'

export const RISK_LEVEL_LABEL: Record<RiskLevel, string> = {
  conservative: 'Conservative',
  balanced: 'Balanced',
  experimental: 'Experimental',
}

/** Higher number = more severe; used when multiple risk tags appear. */
const SEVERITY: Record<RiskLevel, number> = {
  conservative: 1,
  balanced: 2,
  experimental: 3,
}

const LEVEL_ALIASES: Record<string, RiskLevel> = {
  conservative: 'conservative',
  balanced: 'balanced',
  experimental: 'experimental',
  // common misspellings / synonyms we still treat as explicit risk language only
  low: 'conservative',
  medium: 'balanced',
  high: 'experimental',
  aggressive: 'experimental',
}

function normalizeToken(raw: string): string {
  return raw.trim().toLowerCase().replace(/[_/\s]+/g, '-')
}

/**
 * Parse a single tag or extension value into a RiskLevel.
 * Returns null unless the string is an explicit risk marker.
 */
export function parseRiskToken(raw: unknown): RiskLevel | null {
  if (typeof raw !== 'string') return null
  const t = normalizeToken(raw)
  if (!t) return null

  // risk-conservative | risk:conservative | risk.conservative
  const riskPrefixed = t.match(/^risk[-:.](.+)$/)
  if (riskPrefixed) {
    const level = LEVEL_ALIASES[riskPrefixed[1]]
    return level ?? null
  }

  // Bare level only when clearly a risk tag id (not product tags like "strat")
  if (t === 'conservative' || t === 'balanced' || t === 'experimental') {
    return t
  }

  return null
}

/**
 * Resolve risk from Uniswap-style tokenlist tags and optional extensions.risk.
 * Multiple levels → highest severity (experimental wins over conservative).
 */
export function resolveRiskLevel(
  tags?: readonly string[] | null,
  extensions?: Record<string, unknown> | null,
): RiskLevel | undefined {
  let best: RiskLevel | undefined

  const consider = (level: RiskLevel | null) => {
    if (!level) return
    if (!best || SEVERITY[level] > SEVERITY[best]) best = level
  }

  if (tags) {
    for (const tag of tags) {
      consider(parseRiskToken(tag))
    }
  }

  if (extensions && typeof extensions === 'object') {
    const extRisk = extensions.risk
    if (typeof extRisk === 'string') {
      consider(parseRiskToken(extRisk))
      // also accept risk-conservative form in extensions.risk
      consider(parseRiskToken(`risk-${extRisk}`))
    }
  }

  return best
}
