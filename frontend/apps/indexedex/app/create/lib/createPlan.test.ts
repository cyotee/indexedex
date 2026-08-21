import { describe, expect, it } from 'vitest'

import {
  applyType,
  bondSymbolFrom,
  burnPriceFromBand,
  canLeaveStep,
  claimSymbolFrom,
  emptyPlan,
  evenWeightPercents,
  mintPriceFromBand,
  nextStep,
  planReady,
  prevStep,
  serializePlan,
  validateBasket,
  validateName,
  weightTotal,
} from './createPlan'

describe('create plan steps', () => {
  it('walks shape → review', () => {
    expect(nextStep('shape')).toBe('name')
    expect(nextStep('review')).toBeNull()
    expect(prevStep('name')).toBe('shape')
    expect(prevStep('shape')).toBeNull()
  })
})

describe('validateName', () => {
  it('rejects a short name', () => {
    const p = emptyPlan()
    p.name = 'A'
    p.symbol = 'AA'
    expect(validateName(p)).toMatch(/name/)
  })

  it('accepts $$DETF-style symbols', () => {
    const p = emptyPlan()
    p.name = 'Double Dollar'
    p.symbol = '$$DETF'
    expect(validateName(p)).toBeNull()
  })

  it('accepts a hyphen in the symbol', () => {
    const p = emptyPlan()
    p.name = 'Nvidia single'
    p.symbol = 'NVDA-S'
    expect(validateName(p)).toBeNull()
  })
})

describe('validateBasket', () => {
  it('requires a pair token for one vault', () => {
    const p = emptyPlan()
    p.typeId = 'one-vault'
    p.vaults = ['0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099']
    expect(validateBasket(p)).toMatch(/pair token/)
  })

  it('requires weights to sum to 100', () => {
    const p = emptyPlan()
    p.typeId = 'weighted'
    p.vaults = [
      '0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099',
      '0xfb40276683454159A6b1F9aB1f7C2c3355d22EBd',
    ]
    p.weights = ['40', '40']
    expect(weightTotal(p.weights)).toBe(80)
    expect(validateBasket(p)).toMatch(/100/)
  })
})

describe('canLeaveStep', () => {
  it('blocks leaving shape with no type', () => {
    expect(canLeaveStep('shape', emptyPlan())).toMatch(/shape/)
  })
})

describe('derived names', () => {
  it('builds claim and bond symbols', () => {
    expect(claimSymbolFrom('FOO')).toBe('FOOIR')
    expect(bondSymbolFrom('FOO')).toBe('FOO-BOND')
  })
})

describe('evenWeightPercents', () => {
  it('sums to 100', () => {
    expect(evenWeightPercents(2)).toEqual(['50', '50'])
    expect(evenWeightPercents(3)).toEqual(['33', '33', '34'])
    expect(weightTotal(evenWeightPercents(8))).toBe(100)
  })
})

describe('price bands', () => {
  it('maps 5% to 1.05 and 0.95', () => {
    expect(mintPriceFromBand('5')).toBe('1.05')
    expect(burnPriceFromBand('5')).toBe('0.95')
  })
})

describe('applyType', () => {
  it('clips to one vault and drops weights', () => {
    const p = emptyPlan()
    p.vaults = [
      '0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099',
      '0xfb40276683454159A6b1F9aB1f7C2c3355d22EBd',
    ]
    p.weights = ['50', '50']
    const next = applyType(p, 'one-vault')
    expect(next.vaults).toHaveLength(1)
    expect(next.weights).toHaveLength(1)
  })
})

describe('planReady', () => {
  it('is true for a full one-vault plan', () => {
    const p = emptyPlan()
    p.typeId = 'one-vault'
    p.name = 'Nvidia single'
    p.symbol = 'NVDA-S'
    p.vaults = ['0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099']
    p.pairToken = '0xd97e3BCF599A5dbc893387680868d4Ad76E81206'
    expect(planReady(p)).toBe(true)
  })

  it('serializes claim and bond symbols', () => {
    const p = emptyPlan()
    p.typeId = 'one-vault'
    p.name = 'Foo'
    p.symbol = 'FOO'
    const json = serializePlan(p)
    expect(json).toMatch(/FOOIR/)
    expect(json).toMatch(/FOO-BOND/)
  })
})
