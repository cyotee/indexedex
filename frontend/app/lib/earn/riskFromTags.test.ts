import { describe, expect, it } from 'vitest'
import { parseRiskToken, resolveRiskLevel } from './riskFromTags'

describe('parseRiskToken', () => {
  it('accepts canonical risk-* tag ids', () => {
    expect(parseRiskToken('risk-conservative')).toBe('conservative')
    expect(parseRiskToken('risk-balanced')).toBe('balanced')
    expect(parseRiskToken('Risk-Experimental')).toBe('experimental')
  })

  it('accepts risk: / risk. separators and bare levels', () => {
    expect(parseRiskToken('risk:balanced')).toBe('balanced')
    expect(parseRiskToken('risk.experimental')).toBe('experimental')
    expect(parseRiskToken('conservative')).toBe('conservative')
  })

  it('rejects non-risk product tags and empty values', () => {
    expect(parseRiskToken('strat')).toBeNull()
    expect(parseRiskToken('vault')).toBeNull()
    expect(parseRiskToken('detf')).toBeNull()
    expect(parseRiskToken('')).toBeNull()
    expect(parseRiskToken(null)).toBeNull()
    expect(parseRiskToken(12)).toBeNull()
  })
})

describe('resolveRiskLevel', () => {
  it('returns undefined when tags are absent or only product tags', () => {
    expect(resolveRiskLevel(undefined)).toBeUndefined()
    expect(resolveRiskLevel(null)).toBeUndefined()
    expect(resolveRiskLevel([])).toBeUndefined()
    expect(resolveRiskLevel(['vault', 'strat', 'detf'])).toBeUndefined()
  })

  it('resolves a single risk tag', () => {
    expect(resolveRiskLevel(['vault', 'risk-balanced', 'strat'])).toBe('balanced')
  })

  it('picks highest severity when multiple risk tags appear', () => {
    expect(resolveRiskLevel(['risk-conservative', 'risk-experimental'])).toBe('experimental')
    expect(resolveRiskLevel(['risk-balanced', 'risk-conservative'])).toBe('balanced')
  })

  it('reads extensions.risk without inventing when missing', () => {
    expect(resolveRiskLevel([], { risk: 'conservative' })).toBe('conservative')
    expect(resolveRiskLevel([], { risk: 'risk-experimental' })).toBe('experimental')
    expect(resolveRiskLevel([], { display: 'foo' })).toBeUndefined()
    expect(resolveRiskLevel([], { risk: 1 as unknown as string })).toBeUndefined()
  })

  it('does not invent risk from product type tags alone', () => {
    expect(resolveRiskLevel(['strat'])).toBeUndefined()
    expect(resolveRiskLevel(['erc4626', 'vault'])).toBeUndefined()
  })
})
