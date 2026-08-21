import { describe, expect, it } from 'vitest'

import {
  applyType,
  bondSymbolFrom,
  burnPriceFromBand,
  canLeaveStep,
  claimSymbolFrom,
  emptyPlan,
  evenWeightPercents,
  humanToWad,
  mintPriceFromBand,
  nextStep,
  planReady,
  prevStep,
  serializePlan,
  validateBasket,
  validateGates,
  validateName,
  weightTotal,
} from './createPlan'

describe('create plan steps', () => {
  it('walks shape → name → basket → gates → review', () => {
    expect(nextStep('shape')).toBe('name')
    expect(nextStep('name')).toBe('basket')
    expect(nextStep('basket')).toBe('gates')
    expect(nextStep('gates')).toBe('review')
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

  it('accepts a one-vault plan with vault and pair token', () => {
    const p = emptyPlan()
    p.typeId = 'one-vault'
    p.vaults = ['0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099']
    p.pairToken = '0xd97e3BCF599A5dbc893387680868d4Ad76E81206'
    expect(validateBasket(p)).toBeNull()
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

  it('accepts a custom claim symbol', () => {
    const p = emptyPlan()
    p.name = 'Foo'
    p.symbol = 'FOO'
    p.claimSymbol = 'FOO-CLM'
    expect(validateName(p)).toBeNull()
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

describe('humanToWad', () => {
  it('maps 1 and 1.1 to 18-decimal wads', () => {
    expect(humanToWad('1')).toBe('1000000000000000000')
    expect(humanToWad('1.1')).toBe('1100000000000000000')
  })
})

describe('validateGates', () => {
  it('requires a peg greater than 0', () => {
    const p = emptyPlan()
    p.creationPairPerDetf = ['0']
    expect(validateGates(p)).toMatch(/Peg/)
  })

  it('accepts a blank first bond', () => {
    const p = emptyPlan()
    p.creationPairPerDetf = ['1']
    p.openingPairPerDetf = ['']
    expect(validateGates(p)).toBeNull()
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

  it('serializes claim, bond, peg, and opening package fields', () => {
    const p = emptyPlan()
    p.typeId = 'one-vault'
    p.name = 'Foo'
    p.symbol = 'FOO'
    p.claimName = 'Foo Claim'
    p.claimSymbol = 'FOOIR'
    p.bondName = 'Foo Bond'
    p.bondSymbol = 'FOO-BOND'
    p.creationPairPerDetf = ['1']
    p.openingPairPerDetf = ['1.1']
    const json = serializePlan(p)
    expect(json).toMatch(/"claimName": "Foo Claim"/)
    expect(json).toMatch(/"claimSymbol": "FOOIR"/)
    expect(json).toMatch(/"bondName": "Foo Bond"/)
    expect(json).toMatch(/"bondSymbol": "FOO-BOND"/)
    expect(json).toMatch(/"creationPairPerDetfWad"/)
    expect(json).toMatch(/1100000000000000000/)
    expect(json).toMatch(/"thresholdMode": 0/)
  })
})
