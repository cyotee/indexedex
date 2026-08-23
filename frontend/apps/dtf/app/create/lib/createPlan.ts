import type { CreateDetfTypeId } from '../detfTypes'
import { CREATE_DETF_TYPES } from '../detfTypes'

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
  /** Weight percents as strings; used by weighted type. */
  weights: string[]
  pairToken: `0x${string}` | ''
  cashToken: `0x${string}` | ''
}

export const CREATE_STEPS = ['shape', 'basket', 'name', 'gates', 'review'] as const
export type CreateStepId = (typeof CREATE_STEPS)[number]

export const CREATE_STEP_LABEL: Record<CreateStepId, string> = {
  shape: 'Shape',
  name: 'Name',
  basket: 'Basket',
  gates: 'Mint and burn',
  review: 'Review',
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
    pairToken: '',
    cashToken: '',
  }
}

export function typeMeta(typeId: CreateDetfTypeId | '') {
  return CREATE_DETF_TYPES.find((t) => t.id === typeId)
}

export function minVaults(typeId: CreateDetfTypeId | ''): number {
  if (typeId === 'one-vault') return 1
  if (typeId === 'weighted') return 2
  if (typeId === 'grouped') return 2
  if (typeId === 'cash-buffer') return 2
  return 1
}

export function maxVaults(typeId: CreateDetfTypeId | ''): number {
  if (typeId === 'one-vault') return 1
  if (typeId === 'weighted') return 8
  if (typeId === 'grouped') return 8
  if (typeId === 'cash-buffer') return 8
  return 8
}

const SYMBOL_RE = /^[A-Za-z0-9$][A-Za-z0-9$-]{1,11}$/
const CHILD_SYMBOL_RE = /^[A-Za-z0-9$][A-Za-z0-9$-]{1,19}$/

export type UnderlyingTokenMeta = {
  name: string
  symbol: string
}

function sanitizeSymbolPart(raw: string): string {
  return raw.trim().replace(/[^A-Za-z0-9$]/g, '')
}

/** DETF name from SE vault underlyings: names, and symbols when they still fit. */
export function concatDetfName(tokens: readonly UnderlyingTokenMeta[]): string {
  if (tokens.length === 0) return ''
  const withBoth = tokens
    .map((t) => {
      const n = t.name.trim()
      const s = t.symbol.trim()
      if (n && s && n.toLowerCase() !== s.toLowerCase()) return `${n} (${s})`
      return n || s
    })
    .filter(Boolean)
    .join(' / ')
  if (withBoth.length >= 2 && withBoth.length <= 40) return withBoth
  const names = tokens.map((t) => t.name.trim()).filter(Boolean).join(' / ')
  if (names.length >= 2 && names.length <= 40) return names
  const symbols = tokens.map((t) => t.symbol.trim()).filter(Boolean).join(' / ')
  if (symbols.length >= 2) return symbols.slice(0, 40)
  return withBoth.slice(0, 40)
}

/** DETF symbol from concatenated underlying symbols (2–12, hyphen when it fits). */
export function concatDetfSymbol(tokens: readonly UnderlyingTokenMeta[]): string {
  const parts = tokens.map((t) => sanitizeSymbolPart(t.symbol)).filter((s) => s.length > 0)
  if (parts.length === 0) return ''
  const hyphen = parts.join('-')
  if (SYMBOL_RE.test(hyphen)) return hyphen
  const packed = parts.join('')
  if (packed.length >= 2) return packed.slice(0, 12)
  return ''
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
  if (!SYMBOL_RE.test(plan.symbol.trim())) return 'DETF symbol: 2–12 letters, numbers, $, or hyphen.'
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
  if (!plan.typeId) return 'Pick a basket shape first.'
  const min = minVaults(plan.typeId)
  const max = maxVaults(plan.typeId)
  if (plan.vaults.length < min) {
    return min === 1 ? 'Pick one vault for the basket.' : `Pick at least ${min} vaults.`
  }
  if (plan.vaults.length > max) return `At most ${max} vaults for this shape.`
  if (plan.typeId === 'one-vault' && !plan.pairToken) {
    return plan.vaults.length
      ? 'Pick the pair token from this SE vault.'
      : 'Pick the pair token this DETF will mint against.'
  }
  if (plan.typeId === 'cash-buffer' && !plan.cashToken) return 'Pick the cash token burns will return.'
  if (plan.typeId === 'weighted') {
    const total = weightTotal(plan.weights.slice(0, plan.vaults.length))
    if (Math.abs(total - 100) > 0.05) return 'Weights must add to 100%.'
  }
  return null
}

export function canLeaveStep(step: CreateStepId, plan: CreatePlan): string | null {
  if (step === 'shape') return plan.typeId ? null : 'Pick a basket shape.'
  if (step === 'name') return validateName(plan)
  if (step === 'gates') return validateGates(plan)
  if (step === 'basket') return validateBasket(plan)
  return null
}

export function nextStep(step: CreateStepId): CreateStepId | null {
  const i = CREATE_STEPS.indexOf(step)
  if (i < 0 || i >= CREATE_STEPS.length - 1) return null
  return CREATE_STEPS[i + 1]!
}

export function prevStep(step: CreateStepId): CreateStepId | null {
  const i = CREATE_STEPS.indexOf(step)
  if (i <= 0) return null
  return CREATE_STEPS[i - 1]!
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

/** Integer percents that sum to 100. Last vault takes the remainder. */
export function evenWeightPercents(n: number): string[] {
  if (n <= 0) return []
  const base = Math.floor(100 / n)
  const rem = 100 - base * n
  return Array.from({ length: n }, (_, i) => String(i === n - 1 ? base + rem : base))
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
  if (typeId === 'weighted' && next.vaults.length > 0) {
    next.weights = evenWeightPercents(next.vaults.length)
  } else {
    next.weights = next.weights.slice(0, next.vaults.length)
  }
  if (typeId !== 'one-vault') next.pairToken = ''
  if (typeId !== 'cash-buffer') next.cashToken = ''
  return withPriceLegs(next)
}

export function planReady(plan: CreatePlan): boolean {
  return (
    canLeaveStep('shape', plan) == null &&
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
      pairToken: plan.typeId === 'one-vault' ? plan.pairToken : null,
      cashToken: plan.typeId === 'cash-buffer' ? plan.cashToken : null,
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
    return { ...emptyPlan(), ...parsed, typeId: parseType(parsed.typeId ?? '') }
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
