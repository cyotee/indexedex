import { describe, expect, it } from 'vitest'

import { CREATE_DETF_TYPES, CREATE_SE_HOSTS, platformDetfPkgKey, platformSePkgKey } from '../detfTypes'
import {
  applyType,
  bondSymbolFrom,
  burnPriceFromBand,
  canLeaveStep,
  claimSymbolFrom,
  concatDetfName,
  concatDetfSymbol,
  concatWeightedDetfName,
  concatWeightedDetfSymbol,
  emptyPlan,
  evenWeightedSplit,
  evenWeightPercents,
  humanToWad,
  percentToWad,
  maxVaults,
  minVaults,
  mintPriceFromBand,
  nextStep,
  planReady,
  prevStep,
  serializePlan,
  stepsFor,
  validateBasket,
  validateGates,
  validateName,
  weightTotal,
} from './createPlan'

describe('create plan steps', () => {
  it('walks shape → basket → name → gates → review when not one strategy', () => {
    expect(nextStep('shape')).toBe('basket')
    expect(nextStep('basket')).toBe('name')
    expect(nextStep('name')).toBe('gates')
    expect(nextStep('gates')).toBe('review')
    expect(nextStep('review')).toBeNull()
    expect(prevStep('basket')).toBe('shape')
    expect(prevStep('name')).toBe('basket')
    expect(prevStep('shape')).toBeNull()
  })

  it('inserts a market step after one strategy', () => {
    const p = emptyPlan()
    p.typeId = 'one-vault'
    expect(stepsFor(p)).toEqual(['shape', 'venue', 'basket', 'name', 'gates', 'review'])
    expect(nextStep('shape', p)).toBe('venue')
    expect(nextStep('venue', p)).toBe('basket')
    expect(prevStep('basket', p)).toBe('venue')
    expect(prevStep('venue', p)).toBe('shape')
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

  it('requires at least two vaults for several strategies', () => {
    const p = emptyPlan()
    p.typeId = 'weighted'
    p.vaults = ['0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099']
    p.weights = ['100']
    expect(validateBasket(p)).toMatch(/at least 2/)
  })

  it('caps stables at four vaults', () => {
    const p = emptyPlan()
    p.typeId = 'stables'
    p.vaults = [
      '0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099',
      '0xfb40276683454159A6b1F9aB1f7C2c3355d22EBd',
      '0x1111111111111111111111111111111111111111',
      '0x2222222222222222222222222222222222222222',
      '0x3333333333333333333333333333333333333333',
    ]
    expect(validateBasket(p)).toMatch(/At most 4/)
  })

  it('requires DETF plus pair weights to sum to 100', () => {
    const p = emptyPlan()
    p.typeId = 'weighted'
    p.vaults = [
      '0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099',
      '0xfb40276683454159A6b1F9aB1f7C2c3355d22EBd',
    ]
    p.detfWeight = '20'
    p.weights = ['40', '40']
    expect(weightTotal([p.detfWeight, ...p.weights])).toBe(100)
    p.weights = ['40', '30']
    expect(validateBasket(p)).toMatch(/100/)
  })

  it('accepts an even split of DETF plus two strategies', () => {
    const p = emptyPlan()
    p.typeId = 'weighted'
    p.vaults = [
      '0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099',
      '0xfb40276683454159A6b1F9aB1f7C2c3355d22EBd',
    ]
    p.detfWeight = '34'
    p.weights = ['33', '33']
    p.pairTokens = [
      '0xd97e3BCF599A5dbc893387680868d4Ad76E81206',
      '0x1111111111111111111111111111111111111111',
    ]
    expect(validateBasket(p)).toBeNull()
  })

  it('requires a pair token per weighted strategy', () => {
    const p = emptyPlan()
    p.typeId = 'weighted'
    p.vaults = [
      '0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099',
      '0xfb40276683454159A6b1F9aB1f7C2c3355d22EBd',
    ]
    p.detfWeight = '34'
    p.weights = ['33', '33']
    expect(validateBasket(p)).toMatch(/pair token/)
  })

  it('rejects a 0% DETF weight', () => {
    const p = emptyPlan()
    p.typeId = 'weighted'
    p.vaults = [
      '0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099',
      '0xfb40276683454159A6b1F9aB1f7C2c3355d22EBd',
    ]
    p.detfWeight = '0'
    p.weights = ['50', '50']
    expect(validateBasket(p)).toMatch(/at least 1%/)
  })
})

describe('canLeaveStep', () => {
  it('blocks leaving how-many with no include choice', () => {
    expect(canLeaveStep('shape', emptyPlan())).toMatch(/how many strategies/)
  })

  it('blocks leaving market with no host on one strategy', () => {
    const p = emptyPlan()
    p.typeId = 'one-vault'
    expect(canLeaveStep('venue', p)).toMatch(/Uniswap V3|Morpho/)
    p.seHost = 'uniswap-v4'
    expect(canLeaveStep('venue', p)).toBeNull()
  })
})

describe('include choice limits', () => {
  it('maps one / several / stables to vault counts without exposing packages', () => {
    expect(minVaults('one-vault')).toBe(1)
    expect(maxVaults('one-vault')).toBe(1)
    expect(minVaults('weighted')).toBe(2)
    expect(maxVaults('weighted')).toBe(7)
    expect(minVaults('stables')).toBe(2)
    expect(maxVaults('stables')).toBe(4)
    expect(platformDetfPkgKey('one-vault')).toBe('cpDetfPkg')
    expect(platformDetfPkgKey('weighted')).toBe('weightedDetfPkg')
    expect(platformDetfPkgKey('stables')).toBe('curveQuadDetfPkg')
    expect(platformSePkgKey('uniswap-v3')).toBe('uniV3SePkg')
    expect(platformSePkgKey('uniswap-v4')).toBe('uniV4SePkg')
    expect(platformSePkgKey('morpho')).toBe('morphoBlueSePkg')
  })

  it('marks several-strategy and stables types coming soon', () => {
    expect(CREATE_DETF_TYPES.find((t) => t.id === 'one-vault')?.comingSoon).toBeFalsy()
    expect(CREATE_DETF_TYPES.find((t) => t.id === 'weighted')?.comingSoon).toBe(true)
    expect(CREATE_DETF_TYPES.find((t) => t.id === 'stables')?.comingSoon).toBe(true)
  })

  it('keeps customer titles free of package names', () => {
    const blob = [
      ...CREATE_DETF_TYPES.map((t) => `${t.kicker} ${t.title} ${t.blurb}`),
      ...CREATE_SE_HOSTS.map((h) => `${h.kicker} ${h.title} ${h.blurb}`),
    ].join(' ')
    expect(blob).not.toMatch(/Curve Quad|Weighted Pool|Single Vault|DFPkg|cpDetf|curveQuad|uniV4SePkg|morphoBlue/i)
  })
})

describe('derived names', () => {
  it('builds claim and bond symbols', () => {
    expect(claimSymbolFrom('FOO')).toBe('FOOIR')
    expect(bondSymbolFrom('FOO')).toBe('FOO-BOND')
  })

  it('concatenates underlying token names and symbols and appends DETF', () => {
    const usd = { name: 'USD Coin', symbol: 'USDC' }
    const weth = { name: 'Wrapped Ether', symbol: 'WETH' }
    expect(concatDetfName([usd, weth])).toBe('USD Coin / Wrapped Ether DETF')
    expect(concatDetfSymbol([usd, weth])).toBe('USDC-WETH-DETF')
  })

  it('includes the selected strategy in DETF defaults', () => {
    const usd = { name: 'USD Coin', symbol: 'USDC' }
    const weth = { name: 'Wrapped Ether', symbol: 'WETH' }
    expect(
      concatDetfName([usd, weth], { strategyName: 'Uniswap V4', strategySymbol: 'V4' }),
    ).toBe('USD Coin / Wrapped Ether Uniswap V4 DETF')
    expect(
      concatDetfSymbol([usd, weth], { strategyName: 'Uniswap V4', strategySymbol: 'V4' }),
    ).toBe('USDC-WETH-V4-DETF')
    expect(
      concatDetfName([{ name: 'Test Token USDE', symbol: 'TTUSDE' }], {
        strategyName: 'Morpho Blue',
        strategySymbol: 'MB',
      }),
    ).toBe('Test Token USDE Morpho Blue DETF')
    expect(
      concatDetfSymbol([{ name: 'Test Token USDE', symbol: 'TTUSDE' }], {
        strategyName: 'Morpho Blue',
        strategySymbol: 'MB',
      }),
    ).toBe('TTUSDE-MB-DETF')
  })

  it('falls back to names when name-plus-symbol is too long, then appends DETF', () => {
    const a = { name: 'Test Token USDG', symbol: 'TTUSDG' }
    const b = { name: 'Test Token WETH', symbol: 'TTWETH' }
    expect(concatDetfName([a, b])).toBe('Test Token USDG / Test Token WETH DETF')
    expect(concatDetfSymbol([a, b])).toBe('TTUSDG-TTWETH-DETF')
  })

  it('does not double the DETF suffix', () => {
    expect(concatDetfName([{ name: 'Foo DETF', symbol: 'Foo DETF' }])).toBe('Foo DETF')
    expect(concatDetfSymbol([{ name: 'Foo DETF', symbol: 'FOODETF' }])).toBe('FOODETF')
  })

  it('composes a weighted name from tokens, strategies, and DETF-first weights', () => {
    const usd = { name: 'USD Coin', symbol: 'USDC' }
    const weth = { name: 'Wrapped Ether', symbol: 'WETH' }
    const input = {
      tokens: [usd, weth],
      strategySymbols: ['V4', 'MB'],
      detfWeightPct: '33',
      pairWeightPcts: ['33', '34'],
    }
    expect(concatWeightedDetfName(input)).toBe('USDC / WETH V4+MB 33-33-34 DETF')
    expect(concatWeightedDetfSymbol(input)).toBe('USDC-WETH-V4-MB-DETF')
  })

  it('drops extra pieces from the weighted symbol when they do not fit', () => {
    const a = { name: 'Test Token USDE', symbol: 'TTUSDE' }
    const b = { name: 'Test Token WETH', symbol: 'TTWETH' }
    const input = {
      tokens: [a, b],
      strategySymbols: ['V4', 'MB'],
      detfWeightPct: '33',
      pairWeightPcts: ['33', '34'],
    }
    expect(concatWeightedDetfName(input)).toBe('TTUSDE / TTWETH V4+MB 33-33-34 DETF')
    expect(concatWeightedDetfSymbol(input)).toBe('TTUSDE-TTWETH-DETF')
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

describe('evenWeightedSplit', () => {
  it('gives leftover percent to the DETF token', () => {
    expect(evenWeightedSplit(2)).toEqual({ detfWeight: '34', weights: ['33', '33'] })
    expect(evenWeightedSplit(1)).toEqual({ detfWeight: '50', weights: ['50'] })
    expect(evenWeightedSplit(5)).toEqual({
      detfWeight: '20',
      weights: ['16', '16', '16', '16', '16'],
    })
    const three = evenWeightedSplit(3)
    expect(Number(three.detfWeight) + weightTotal(three.weights)).toBe(100)
    expect(Number(three.detfWeight)).toBeGreaterThanOrEqual(1)
    expect(Number(three.detfWeight)).toBeGreaterThanOrEqual(Math.max(...three.weights.map(Number)))
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

describe('percentToWad', () => {
  it('maps integer percents that sum to 100 onto 1e18', () => {
    expect(percentToWad('34')).toBe((34n * 10n ** 16n).toString())
    expect(percentToWad('33')).toBe((33n * 10n ** 16n).toString())
    expect(
      BigInt(percentToWad('34')!) + BigInt(percentToWad('33')!) + BigInt(percentToWad('33')!),
    ).toBe(10n ** 18n)
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
    p.detfWeight = '33'
    const next = applyType(p, 'one-vault')
    expect(next.vaults).toHaveLength(1)
    expect(next.weights).toEqual([])
    expect(next.detfWeight).toBe('')
  })

  it('even-splits DETF plus pair legs for weighted', () => {
    const p = emptyPlan()
    p.vaults = [
      '0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099',
      '0xfb40276683454159A6b1F9aB1f7C2c3355d22EBd',
    ]
    const next = applyType(p, 'weighted')
    expect(next.detfWeight).toBe('34')
    expect(next.weights).toEqual(['33', '33'])
  })

  it('pre-fills DETF weight when weighted has no vaults yet', () => {
    const next = applyType(emptyPlan(), 'weighted')
    expect(next.detfWeight).toBe('34')
    expect(next.weights).toEqual([])
  })
})

describe('planReady', () => {
  it('is true for a full one-vault plan', () => {
    const p = emptyPlan()
    p.typeId = 'one-vault'
    p.seHost = 'uniswap-v4'
    p.name = 'Nvidia single'
    p.symbol = 'NVDA-S'
    p.vaults = ['0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099']
    p.pairToken = '0xd97e3BCF599A5dbc893387680868d4Ad76E81206'
    expect(planReady(p)).toBe(true)
  })

  it('serializes claim, bond, peg, and opening package fields', () => {
    const p = emptyPlan()
    p.typeId = 'one-vault'
    p.seHost = 'uniswap-v4'
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
    expect(json).toMatch(/"seHost": "uniswap-v4"/)
  })
})
