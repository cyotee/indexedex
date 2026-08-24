import type { CreateDetfTypeId, CreateSeHostId } from '../detfTypes'
import { CREATE_DETF_TYPES, isCreateSeHostId } from '../detfTypes'

export type ThresholdChoice = 'policy' | 'open'

export type CreatePlan = {
  typeId: CreateDetfTypeId | ''
  name: string
  symbol: string
  claimName: string
  claimSymbol: string
  bondName: string
  bondSymbol: string
  mode: ThresholdChoice
  /** Pair per DETF at price index 1 (creationPairPerDetfWad). One string per basket leg. */
  creationPairPerDetf: string[]
  /** Pair per DETF on first bond (openingPairPerDetfWad). Blank or 0 uses the peg. */
  openingPairPerDetf: string[]
  /** Percent above 1.0 for mint (Policy). "5" → 1.05e18. */
  mintBandPct: string
  /** Percent below 1.0 for burn (Policy). "5" → 0.95e18. */
  burnBandPct: string
  vaults: `0x${string}`[]
  /** Pair-leg weight percents; used by weighted type. */
  weights: string[]
  /** DETF self-leg weight percent. Weighted reserve is DETF + pair legs. */
  detfWeight: string
  /** Per-slot strategy host for weighted baskets. Parallel to vaults. */
  seHosts: (CreateSeHostId | '')[]
  /** Per-slot pair tokens for weighted baskets. Parallel to vaults. */
  pairTokens: (`0x${string}` | '')[]
  pairToken: `0x${string}` | ''
  cashToken: `0x${string}` | ''
  /** One-strategy host. Picks the SE package. Not shown as a package name. */
  seHost: CreateSeHostId | ''
}

export const CREATE_STEPS = ['shape', 'venue', 'basket', 'name', 'gates', 'review'] as const
export type CreateStepId = (typeof CREATE_STEPS)[number]

export const CREATE_STEP_LABEL: Record<CreateStepId, string> = {
  shape: 'How many',
  venue: 'Market',
  name: 'Name',
  basket: 'Basket',
  gates: 'Mint and burn',
  review: 'Review',
}

export function stepsFor(plan: CreatePlan): CreateStepId[] {
  if (plan.typeId === 'one-vault') return [...CREATE_STEPS]
  return CREATE_STEPS.filter((id) => id !== 'venue')
}

export function emptyPlan(): CreatePlan {
  return {
    typeId: '',
    name: '',
    symbol: '',
    claimName: '',
    claimSymbol: '',
    bondName: '',
    bondSymbol: '',
    mode: 'policy',
    creationPairPerDetf: ['1'],
    openingPairPerDetf: [''],
    mintBandPct: '5',
    burnBandPct: '5',
    vaults: [],
    weights: [],
    detfWeight: '',
    seHosts: [],
    pairTokens: [],
    pairToken: '',
    cashToken: '',
    seHost: '',
  }
}

export function typeMeta(typeId: CreateDetfTypeId | '') {
  return CREATE_DETF_TYPES.find((t) => t.id === typeId)
}

export function minVaults(typeId: CreateDetfTypeId | ''): number {
  if (typeId === 'one-vault') return 1
  if (typeId === 'weighted') return 2
  if (typeId === 'stables') return 2
  if (typeId === 'grouped') return 2
  if (typeId === 'cash-buffer') return 2
  return 1
}

export function maxVaults(typeId: CreateDetfTypeId | ''): number {
  if (typeId === 'one-vault') return 1
  if (typeId === 'weighted') return 7
  if (typeId === 'stables') return 4
  if (typeId === 'grouped') return 8
  if (typeId === 'cash-buffer') return 8
  return 8
}

const SYMBOL_RE = /^[A-Za-z0-9$][A-Za-z0-9$-]{1,19}$/
const CHILD_SYMBOL_RE = /^[A-Za-z0-9$][A-Za-z0-9$-]{1,19}$/
const DETF_NAME_MAX = 40
const DETF_SYMBOL_MAX = 20
const NAME_DETF_SUFFIX = ' DETF'
const SYMBOL_DETF_SUFFIX = '-DETF'

export type UnderlyingTokenMeta = {
  name: string
  symbol: string
}

function sanitizeSymbolPart(raw: string): string {
  return raw.trim().replace(/[^A-Za-z0-9$]/g, '')
}

export type DetfDefaultHint = {
  strategyName?: string
  strategySymbol?: string
}

function nameSuffix(strategyName?: string): string {
  const strategy = strategyName?.trim() ?? ''
  return strategy ? ` ${strategy}${NAME_DETF_SUFFIX}` : NAME_DETF_SUFFIX
}

function symbolSuffix(strategySymbol?: string): string {
  const tag = sanitizeSymbolPart(strategySymbol ?? '')
  return tag ? `-${tag}${SYMBOL_DETF_SUFFIX}` : SYMBOL_DETF_SUFFIX
}

function appendNameDetf(base: string, strategyName?: string): string {
  let t = base.trim().replace(/\s+DETF$/i, '').trim()
  const strategy = strategyName?.trim() ?? ''
  const extra =
    strategy && !t.toLowerCase().includes(strategy.toLowerCase()) ? ` ${strategy}` : ''
  const suffix = `${extra}${NAME_DETF_SUFFIX}`
  if (!t) {
    return strategy ? `${strategy}${NAME_DETF_SUFFIX}`.slice(0, DETF_NAME_MAX) : ''
  }
  const room = DETF_NAME_MAX - suffix.length
  if (room < 1) return suffix.trim().slice(0, DETF_NAME_MAX)
  const head = t.length <= room ? t : t.slice(0, room).trimEnd()
  if (!head) return suffix.trim().slice(0, DETF_NAME_MAX)
  return `${head}${suffix}`
}

function appendSymbolDetf(base: string, strategySymbol?: string): string {
  const cleaned = base.trim().replace(/[^A-Za-z0-9$-]/g, '')
  const tag = sanitizeSymbolPart(strategySymbol ?? '')
  if (/-?DETF$/i.test(cleaned) && !tag) return cleaned.slice(0, DETF_SYMBOL_MAX)
  const t = cleaned.replace(/-DETF$/i, '')
  if (!t) {
    const fromTag = tag ? `${tag}${SYMBOL_DETF_SUFFIX}` : ''
    return fromTag && SYMBOL_RE.test(fromTag) ? fromTag : fromTag.slice(0, DETF_SYMBOL_MAX)
  }
  const extra = tag && !t.toUpperCase().includes(tag.toUpperCase()) ? `-${tag}` : ''
  const suffix = `${extra}${SYMBOL_DETF_SUFFIX}`
  const room = DETF_SYMBOL_MAX - suffix.length
  const head = t.length <= room ? t : t.slice(0, Math.max(1, room))
  const next = `${head}${suffix}`
  return SYMBOL_RE.test(next) ? next : next.slice(0, DETF_SYMBOL_MAX)
}

/** DETF name from SE vault underlyings, optional strategy tag, and a DETF suffix. */
export function concatDetfName(
  tokens: readonly UnderlyingTokenMeta[],
  hint?: DetfDefaultHint,
): string {
  if (tokens.length === 0 && !hint?.strategyName?.trim()) return ''
  const strategy = hint?.strategyName?.trim() ?? ''
  const suffixLen = nameSuffix(strategy).length
  const room = DETF_NAME_MAX - suffixLen
  const withBoth = tokens
    .map((t) => {
      const n = t.name.trim()
      const s = t.symbol.trim()
      if (n && s && n.toLowerCase() !== s.toLowerCase()) return `${n} (${s})`
      return n || s
    })
    .filter(Boolean)
    .join(' / ')
  const names = tokens.map((t) => t.name.trim()).filter(Boolean).join(' / ')
  const symbols = tokens.map((t) => t.symbol.trim()).filter(Boolean).join(' / ')
  const base =
    withBoth.length >= 2 && withBoth.length <= room
      ? withBoth
      : names.length >= 2 && names.length <= room
        ? names
        : symbols.length >= 2
          ? symbols.slice(0, Math.max(0, room))
          : withBoth.slice(0, Math.max(0, room))
  return appendNameDetf(base, strategy)
}

/** DETF symbol from concatenated underlying symbols, optional strategy tag, and -DETF (2–20). */
export function concatDetfSymbol(
  tokens: readonly UnderlyingTokenMeta[],
  hint?: DetfDefaultHint,
): string {
  const parts = tokens.map((t) => sanitizeSymbolPart(t.symbol)).filter((s) => s.length > 0)
  const tag = hint?.strategySymbol?.trim()
  if (parts.length === 0 && !tag) return ''
  const hyphen = parts.join('-')
  const suffixed = appendSymbolDetf(hyphen, tag)
  if (SYMBOL_RE.test(suffixed)) return suffixed
  const packed = parts.join('')
  return appendSymbolDetf(packed, tag)
}

function uniqueTokenMetas(tokens: readonly UnderlyingTokenMeta[]): UnderlyingTokenMeta[] {
  const seen = new Set<string>()
  const out: UnderlyingTokenMeta[] = []
  for (const t of tokens) {
    const key = (t.symbol.trim() || t.name.trim()).toLowerCase()
    if (!key || seen.has(key)) continue
    seen.add(key)
    out.push(t)
  }
  return out
}

function uniqueNonEmpty(values: readonly string[]): string[] {
  const seen = new Set<string>()
  const out: string[] = []
  for (const v of values) {
    const t = v.trim()
    if (!t) continue
    const key = t.toLowerCase()
    if (seen.has(key)) continue
    seen.add(key)
    out.push(t)
  }
  return out
}

export function weightPartsForName(detfWeightPct: string, pairWeightPcts: string[]): string {
  const all = [detfWeightPct, ...pairWeightPcts]
  const ints: string[] = []
  for (const raw of all) {
    const n = Math.round(Number(raw))
    if (!Number.isFinite(n) || n < 0) return ''
    ints.push(String(n))
  }
  return ints.length > 0 ? ints.join('-') : ''
}

export type WeightedNameInput = {
  tokens: readonly UnderlyingTokenMeta[]
  strategySymbols: readonly string[]
  detfWeightPct: string
  pairWeightPcts: string[]
}

/** Weighted DETF name: tokens, short strategy tags, DETF-first weights, DETF suffix. */
export function concatWeightedDetfName(input: WeightedNameInput): string {
  const tokens = uniqueTokenMetas(input.tokens)
  const strats = uniqueNonEmpty(input.strategySymbols)
  const weights = weightPartsForName(input.detfWeightPct, input.pairWeightPcts)
  const tokenSym = tokens.map((t) => t.symbol.trim() || t.name.trim()).filter(Boolean).join(' / ')
  const tokenName = tokens.map((t) => t.name.trim()).filter(Boolean).join(' / ')
  const strat = strats.join('+')
  const attempts = [
    [tokenSym, strat, weights].filter(Boolean).join(' '),
    [tokenName, strat, weights].filter(Boolean).join(' '),
    [tokenSym, strat].filter(Boolean).join(' '),
    [tokenName, strat].filter(Boolean).join(' '),
    [tokenSym, weights].filter(Boolean).join(' '),
    tokenSym,
    tokenName,
    strat,
    weights,
  ]
  const suffixLen = NAME_DETF_SUFFIX.length
  for (const base of attempts) {
    const t = base.trim().replace(/\s+DETF$/i, '').trim()
    if (t.length < 2 || t.length + suffixLen > DETF_NAME_MAX) continue
    return appendNameDetf(t)
  }
  return appendNameDetf('Weighted')
}

/** Weighted DETF symbol: unique token tickers + strategy tags + weights when they fit, then -DETF. */
export function concatWeightedDetfSymbol(input: WeightedNameInput): string {
  const tokens = uniqueTokenMetas(input.tokens)
  const tags = uniqueNonEmpty(input.strategySymbols).map(sanitizeSymbolPart).filter(Boolean)
  const tokenParts = tokens.map((t) => sanitizeSymbolPart(t.symbol)).filter((s) => s.length > 0)
  const weightHyphen = weightPartsForName(input.detfWeightPct, input.pairWeightPcts)
  const weightPacked = weightHyphen.replace(/-/g, '')
  const tokenHyphen = tokenParts.join('-')
  const tokenPacked = tokenParts.join('')
  const stratHyphen = tags.join('-')
  const stratPacked = tags.join('')
  const attempts = [
    [tokenHyphen, stratHyphen, weightHyphen].filter(Boolean).join('-'),
    [tokenHyphen, stratPacked, weightPacked].filter(Boolean).join('-'),
    [tokenHyphen, stratHyphen].filter(Boolean).join('-'),
    [tokenPacked, stratPacked].filter(Boolean).join('-'),
    tokenHyphen,
    tokenPacked,
    stratPacked,
  ]
  for (const base of attempts) {
    const cleaned = base.trim().replace(/[^A-Za-z0-9$-]/g, '').replace(/-DETF$/i, '')
    if (cleaned.length < 1) continue
    const next = `${cleaned}${SYMBOL_DETF_SUFFIX}`
    if (SYMBOL_RE.test(next)) return next
  }
  const fallback = appendSymbolDetf(tokenPacked || stratPacked || 'WTD')
  return SYMBOL_RE.test(fallback) ? fallback : fallback.slice(0, DETF_SYMBOL_MAX)
}

function validateOptionalName(raw: string, label: string): string | null {
  const name = raw.trim()
  if (!name) return null
  if (name.length < 2) return `${label} name: at least 2 characters, or leave blank for the default.`
  if (name.length > 40) return `${label} name: keep under 40 characters.`
  return null
}

function validateOptionalSymbol(raw: string, label: string): string | null {
  const symbol = raw.trim()
  if (!symbol) return null
  if (!CHILD_SYMBOL_RE.test(symbol)) return `${label} symbol: 2–20 letters, numbers, $, or hyphen, or leave blank.`
  return null
}

export function validateName(plan: CreatePlan): string | null {
  const name = plan.name.trim()
  if (name.length < 2) return 'Give the DETF a name.'
  if (name.length > 40) return 'Keep the name under 40 characters.'
  if (!SYMBOL_RE.test(plan.symbol.trim())) return 'DETF symbol: 2–20 letters, numbers, $, or hyphen.'
  return (
    validateOptionalName(plan.claimName, 'Claim') ??
    validateOptionalSymbol(plan.claimSymbol, 'Claim') ??
    validateOptionalName(plan.bondName, 'Bond') ??
    validateOptionalSymbol(plan.bondSymbol, 'Bond')
  )
}

export function priceLegCount(plan: CreatePlan): number {
  if (plan.typeId === 'one-vault') return 1
  const n = plan.vaults.length
  if (plan.typeId === 'stables') return Math.max(n, 2)
  if (plan.typeId === 'grouped') return Math.max(n, 2)
  if (plan.typeId === 'cash-buffer') return Math.max(n, 3)
  return Math.max(n, 1)
}

function fillLegs(arr: string[] | undefined, n: number, fallback: string): string[] {
  const next = (arr ?? []).slice(0, n)
  while (next.length < n) next.push(next[next.length - 1] ?? fallback)
  return next
}

export function withPriceLegs(plan: CreatePlan): CreatePlan {
  const n = priceLegCount(plan)
  return {
    ...plan,
    creationPairPerDetf: fillLegs(plan.creationPairPerDetf, n, '1'),
    openingPairPerDetf: fillLegs(plan.openingPairPerDetf, n, ''),
  }
}

/** Human decimal → 18-decimal wad string. Empty is not a number. */
/** Percent string → 18-decimal wad. "34" → 0.34e18. Integers that sum to 100 sum to 1e18. */
export function percentToWad(raw: string): string | null {
  const t = raw.trim()
  if (!t) return null
  if (!/^\d+(\.\d+)?$/.test(t)) return null
  const [whole, frac = ''] = t.split('.')
  const frac16 = (frac + '0'.repeat(16)).slice(0, 16)
  try {
    return (BigInt(whole || '0') * 10n ** 16n + BigInt(frac16)).toString()
  } catch {
    return null
  }
}

export function humanToWad(raw: string): string | null {
  const t = raw.trim()
  if (!t) return null
  if (!/^\d+(\.\d+)?$/.test(t)) return null
  const [whole, frac = ''] = t.split('.')
  const frac18 = (frac + '0'.repeat(18)).slice(0, 18)
  try {
    return (BigInt(whole || '0') * 10n ** 18n + BigInt(frac18)).toString()
  } catch {
    return null
  }
}

export function validateGates(plan: CreatePlan): string | null {
  const priced = withPriceLegs(plan)
  for (let i = 0; i < priced.creationPairPerDetf.length; i++) {
    const wad = humanToWad(priced.creationPairPerDetf[i] ?? '')
    if (wad == null || wad === '0') return 'Peg must be pair tokens per DETF, greater than 0.'
    const openRaw = (priced.openingPairPerDetf[i] ?? '').trim()
    if (openRaw) {
      const openWad = humanToWad(openRaw)
      if (openWad == null) return 'First bond must be blank, 0, or pair tokens per DETF.'
    }
  }
  if (plan.mode === 'open') return null
  const mint = Number(plan.mintBandPct)
  const burn = Number(plan.burnBandPct)
  if (!Number.isFinite(mint) || mint < 0 || mint > 50) return 'Mint line should be 0–50% above 1.'
  if (!Number.isFinite(burn) || burn < 0 || burn > 50) return 'Burn line should be 0–50% below 1.'
  return null
}

export function weightTotal(weights: string[]): number {
  let sum = 0
  for (let i = 0; i < weights.length; i++) {
    const n = Number(weights[i])
    if (Number.isFinite(n)) sum += n
  }
  return sum
}

export function validateBasket(plan: CreatePlan): string | null {
  if (!plan.typeId) return 'Pick how many strategies to include.'
  const min = minVaults(plan.typeId)
  const max = maxVaults(plan.typeId)
  if (plan.vaults.length < min) {
    return min === 1 ? 'Pick one vault for the basket.' : `Pick at least ${min} vaults.`
  }
  if (plan.vaults.length > max) return `At most ${max} vaults for this mix.`
  if (plan.typeId === 'one-vault' && !plan.pairToken) {
    return plan.vaults.length
      ? 'Pick the pair token from this SE vault.'
      : 'Pick the pair token this DETF will mint against.'
  }
  if (plan.typeId === 'cash-buffer' && !plan.cashToken) return 'Pick the cash token burns will return.'
  if (plan.typeId === 'weighted') {
    const parts = [plan.detfWeight, ...plan.weights.slice(0, plan.vaults.length)]
    for (const raw of parts) {
      const n = Number(raw)
      if (!Number.isFinite(n) || n < 1) {
        return 'Each weight, including the DETF token, must be at least 1%.'
      }
    }
    const total = weightTotal(parts)
    if (!weightsSumToHundred(total)) return 'DETF token plus strategy weights must add to 100%.'
    for (let i = 0; i < plan.vaults.length; i++) {
      if (!plan.pairTokens[i]) return 'Pick a pair token for each strategy.'
    }
    const pairKeys = plan.pairTokens.slice(0, plan.vaults.length).map((a) => a.toLowerCase())
    if (new Set(pairKeys).size !== pairKeys.length) {
      return 'Each strategy needs a different pair token.'
    }
    const vaultKeys = plan.vaults.map((a) => a.toLowerCase())
    if (new Set(vaultKeys).size !== vaultKeys.length) {
      return 'Each strategy needs a different vault.'
    }
  }
  return null
}

export function canLeaveStep(step: CreateStepId, plan: CreatePlan): string | null {
  if (step === 'shape') return plan.typeId ? null : 'Pick how many strategies to include.'
  if (step === 'venue') {
    if (plan.typeId !== 'one-vault') return null
    return plan.seHost ? null : 'Pick a Uniswap V3 pool, a Uniswap V4 pool, or a Morpho market.'
  }
  if (step === 'name') return validateName(plan)
  if (step === 'gates') return validateGates(plan)
  if (step === 'basket') return validateBasket(plan)
  return null
}

export function nextStep(step: CreateStepId, plan: CreatePlan = emptyPlan()): CreateStepId | null {
  const steps = stepsFor(plan)
  const i = steps.indexOf(step)
  if (i < 0 || i >= steps.length - 1) return null
  return steps[i + 1]!
}

export function prevStep(step: CreateStepId, plan: CreatePlan = emptyPlan()): CreateStepId | null {
  const steps = stepsFor(plan)
  const i = steps.indexOf(step)
  if (i <= 0) return null
  return steps[i - 1]!
}

export function parseStep(raw: string | null): CreateStepId {
  if (raw && (CREATE_STEPS as readonly string[]).indexOf(raw) >= 0) return raw as CreateStepId
  return 'shape'
}

export function parseType(raw: string | null): CreateDetfTypeId | '' {
  if (!raw) return ''
  const hit = CREATE_DETF_TYPES.find((t) => t.id === raw)
  return hit ? hit.id : ''
}

export function claimSymbolFrom(symbol: string): string {
  const s = symbol.trim()
  if (!s) return ''
  if (s.endsWith('IR')) return s
  return `${s}IR`
}

export function bondSymbolFrom(symbol: string): string {
  const s = symbol.trim()
  if (!s) return ''
  return `${s}-BOND`
}

export function claimNameFrom(name: string): string {
  const n = name.trim()
  if (!n) return ''
  return `${n} Claim`
}

export function bondNameFrom(name: string): string {
  const n = name.trim()
  if (!n) return ''
  return `${n} Bond`
}

export function resolvedClaimName(plan: CreatePlan): string {
  return plan.claimName.trim() || claimNameFrom(plan.name)
}

export function resolvedClaimSymbol(plan: CreatePlan): string {
  return plan.claimSymbol.trim() || claimSymbolFrom(plan.symbol)
}

export function resolvedBondName(plan: CreatePlan): string {
  return plan.bondName.trim() || bondNameFrom(plan.name)
}

export function resolvedBondSymbol(plan: CreatePlan): string {
  return plan.bondSymbol.trim() || bondSymbolFrom(plan.symbol)
}

/** Integer percents that sum to 100. Last entry takes the remainder. */
export function evenWeightPercents(n: number): string[] {
  if (n <= 0) return []
  const base = Math.floor(100 / n)
  const rem = 100 - base * n
  return Array.from({ length: n }, (_, i) => String(i === n - 1 ? base + rem : base))
}

/**
 * Even split of DETF token + m pair legs. Contract: each ≥ 1%, sum 100.
 * Leftover percent after integer division goes to the DETF token.
 */
export function evenWeightedSplit(vaultCount: number): { detfWeight: string; weights: string[] } {
  const n = vaultCount + 1
  if (n <= 0) return { detfWeight: '', weights: [] }
  const base = Math.floor(100 / n)
  const rem = 100 - base * n
  return {
    detfWeight: String(base + rem),
    weights: Array.from({ length: Math.max(0, vaultCount) }, () => String(base)),
  }
}

export function weightedWeightTotal(plan: Pick<CreatePlan, 'detfWeight' | 'weights' | 'vaults'>): number {
  return weightTotal([plan.detfWeight, ...plan.weights.slice(0, plan.vaults.length)])
}

const WEIGHT_SUM_TOLERANCE = 0.05

export function weightsSumToHundred(total: number): boolean {
  return Math.abs(total - 100) <= WEIGHT_SUM_TOLERANCE
}

export function mintPriceFromBand(pct: string): string {
  const n = Number(pct)
  if (!Number.isFinite(n)) return ''
  return (1 + n / 100).toFixed(4).replace(/\.?0+$/, '')
}

export function burnPriceFromBand(pct: string): string {
  const n = Number(pct)
  if (!Number.isFinite(n)) return ''
  return (1 - n / 100).toFixed(4).replace(/\.?0+$/, '')
}

export function applyType(plan: CreatePlan, typeId: CreatePlan['typeId']): CreatePlan {
  const next: CreatePlan = { ...plan, typeId }
  if (!typeId) return withPriceLegs(next)
  const max = maxVaults(typeId)
  if (next.vaults.length > max) {
    next.vaults = next.vaults.slice(0, max)
  }
  if (typeId === 'weighted') {
    const m = next.vaults.length
    if (m > 0) {
      const split = evenWeightedSplit(m)
      next.detfWeight = split.detfWeight
      next.weights = split.weights
    } else {
      next.detfWeight = evenWeightedSplit(minVaults('weighted')).detfWeight
      next.weights = []
    }
    next.seHosts = next.vaults.map((_, i) => next.seHosts[i] ?? '')
    next.pairTokens = next.vaults.map((_, i) => next.pairTokens[i] ?? '')
  } else {
    next.weights = []
    next.detfWeight = ''
    next.seHosts = []
    next.pairTokens = []
  }
  if (typeId !== 'one-vault') {
    next.pairToken = ''
    next.seHost = ''
  }
  if (typeId !== 'cash-buffer') next.cashToken = ''
  return withPriceLegs(next)
}

export function planReady(plan: CreatePlan): boolean {
  return (
    canLeaveStep('shape', plan) == null &&
    canLeaveStep('venue', plan) == null &&
    validateName(plan) == null &&
    validateGates(plan) == null &&
    validateBasket(plan) == null
  )
}

export function serializePlan(plan: CreatePlan): string {
  const priced = withPriceLegs(plan)
  const creationWad = priced.creationPairPerDetf.map((v) => humanToWad(v) ?? '0')
  const openingWad = priced.openingPairPerDetf.map((v) => {
    const t = v.trim()
    if (!t) return '0'
    return humanToWad(t) ?? '0'
  })
  const mintWad = humanToWad(mintPriceFromBand(plan.mintBandPct)) ?? '0'
  const burnWad = humanToWad(burnPriceFromBand(plan.burnBandPct)) ?? '0'
  return JSON.stringify(
    {
      typeId: plan.typeId,
      name: plan.name.trim(),
      symbol: plan.symbol.trim(),
      claimName: plan.claimName.trim(),
      claimSymbol: plan.claimSymbol.trim(),
      bondName: plan.bondName.trim(),
      bondSymbol: plan.bondSymbol.trim(),
      thresholdMode: plan.mode === 'open' ? 1 : 0,
      creationPairPerDetfWad: creationWad,
      openingPairPerDetfWad: openingWad,
      mintThreshold: plan.mode === 'policy' ? mintWad : '0',
      burnThreshold: plan.mode === 'policy' ? burnWad : '0',
      vaults: plan.vaults,
      weights: plan.typeId === 'weighted' ? plan.weights.slice(0, plan.vaults.length) : null,
      detfWeight: plan.typeId === 'weighted' ? plan.detfWeight : null,
      seHosts: plan.typeId === 'weighted' ? plan.seHosts.slice(0, plan.vaults.length) : null,
      pairTokens: plan.typeId === 'weighted' ? plan.pairTokens.slice(0, plan.vaults.length) : null,
      pairToken: plan.typeId === 'one-vault' ? plan.pairToken : null,
      cashToken: plan.typeId === 'cash-buffer' ? plan.cashToken : null,
      seHost: plan.typeId === 'one-vault' ? plan.seHost || null : null,
    },
    null,
    2,
  )
}

export const PLAN_STORAGE_KEY = 'indexedex.createPlan.v2'

export function loadStoredPlan(): CreatePlan | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = sessionStorage.getItem(PLAN_STORAGE_KEY)
    if (!raw) return null
    const parsed = JSON.parse(raw) as Partial<CreatePlan>
    if (!parsed || typeof parsed !== 'object') return null
    return {
      ...emptyPlan(),
      ...parsed,
      typeId: parseType(parsed.typeId ?? ''),
      seHost: isCreateSeHostId(String(parsed.seHost ?? '')) ? (parsed.seHost as CreateSeHostId) : '',
      detfWeight: typeof parsed.detfWeight === 'string' ? parsed.detfWeight : '',
      seHosts: Array.isArray(parsed.seHosts)
        ? parsed.seHosts.map((h) => (isCreateSeHostId(String(h)) ? h : ''))
        : [],
      pairTokens: Array.isArray(parsed.pairTokens)
        ? parsed.pairTokens.map((a) =>
            typeof a === 'string' && /^0x[0-9a-fA-F]{40}$/.test(a) ? (a as `0x${string}`) : '',
          )
        : [],
    }
  } catch {
    return null
  }
}

export function saveStoredPlan(plan: CreatePlan): void {
  if (typeof window === 'undefined') return
  try {
    sessionStorage.setItem(PLAN_STORAGE_KEY, JSON.stringify(plan))
  } catch {
    /* quota / private mode */
  }
}
