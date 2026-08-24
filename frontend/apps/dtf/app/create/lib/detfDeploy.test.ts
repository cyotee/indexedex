import { describe, expect, it } from 'vitest'
import { zeroAddress } from 'viem'

import { emptyPlan } from './createPlan'
import {
  buildCpDetfArgs,
  buildWeightedDetfArgs,
  buildWeightedHookArgs,
  productTokensWeighted,
  sortAddresses,
  unorderedPairs,
} from './detfDeploy'

describe('buildCpDetfArgs', () => {
  it('maps a one-vault plan onto DETF PkgArgs', () => {
    const p = emptyPlan()
    p.typeId = 'one-vault'
    p.name = 'Nvidia single'
    p.symbol = 'NVDA-S'
    p.claimName = 'Nvidia Claim'
    p.claimSymbol = 'NVDAIR'
    p.bondName = 'Nvidia Bond'
    p.bondSymbol = 'NVDA-BOND'
    p.vaults = ['0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099']
    p.pairToken = '0xd97e3BCF599A5dbc893387680868d4Ad76E81206'
    p.creationPairPerDetf = ['1']
    p.openingPairPerDetf = ['']
    p.mode = 'policy'
    p.mintBandPct = '5'
    p.burnBandPct = '5'
    const creator = '0xF4c08ec327a84E08e3189ab782484298B1909984' as const
    const args = buildCpDetfArgs(p, creator)
    expect(args.name).toBe('Nvidia single')
    expect(args.symbol).toBe('NVDA-S')
    expect(args.standardExchangeVault).toBe(p.vaults[0])
    expect(args.standardExchangeVaultShare).toBe(zeroAddress)
    expect(args.pairToken).toBe(p.pairToken)
    expect(args.creationPairPerDetfWad).toBe(10n ** 18n)
    expect(args.openingPairPerDetfWad).toBe(0n)
    expect(args.mintThreshold).toBe(105n * 10n ** 16n)
    expect(args.burnThreshold).toBe(95n * 10n ** 16n)
    expect(args.thresholdMode).toBe(0)
    expect(args.creator).toBe(creator)
  })
})

describe('buildWeightedDetfArgs', () => {
  it('maps DETF weight plus pair legs onto weighted PkgArgs', () => {
    const p = emptyPlan()
    p.typeId = 'weighted'
    p.name = 'Two strat'
    p.symbol = 'TS-DETF'
    p.vaults = [
      '0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099',
      '0xfb40276683454159A6b1F9aB1f7C2c3355d22EBd',
    ]
    p.pairTokens = [
      '0xd97e3BCF599A5dbc893387680868d4Ad76E81206',
      '0x2222222222222222222222222222222222222222',
    ]
    p.detfWeight = '34'
    p.weights = ['33', '33']
    p.creationPairPerDetf = ['1', '1']
    p.openingPairPerDetf = ['', '']
    const creator = '0xF4c08ec327a84E08e3189ab782484298B1909984' as const
    const args = buildWeightedDetfArgs(p, creator)
    expect(args.pairTokens).toEqual(p.pairTokens)
    expect(args.standardExchanges).toEqual(p.vaults)
    expect(args.vaultShares).toEqual([zeroAddress, zeroAddress])
    expect(args.detfWeight).toBe(34n * 10n ** 16n)
    expect(args.pairWeights).toEqual([33n * 10n ** 16n, 33n * 10n ** 16n])
    expect(args.detfWeight + args.pairWeights[0]! + args.pairWeights[1]!).toBe(10n ** 18n)
    expect(args.creationPairPerDetfWad).toEqual([10n ** 18n, 10n ** 18n])
    expect(args.openingPairPerDetfWad).toEqual([0n, 0n])
    expect(args.thresholdMode).toBe(0)
  })
})

describe('weighted hook binding', () => {
  it('sorts DETF plus pairs and places weights on binding indices', () => {
    const detf = '0x0000000000000000000000000000000000000003' as const
    const p0 = '0x0000000000000000000000000000000000000001' as const
    const p1 = '0x0000000000000000000000000000000000000002' as const
    expect(sortAddresses([detf, p0, p1])).toEqual([p0, p1, detf])
    expect(productTokensWeighted(detf, [p0, p1])).toEqual([p0, p1, detf])
    expect(unorderedPairs([p0, p1, detf])).toHaveLength(3)
    const hook = buildWeightedHookArgs({
      detfArgs: {
        name: 'x',
        symbol: 'x',
        pairTokens: [p0, p1],
        standardExchanges: [
          '0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099',
          '0xfb40276683454159A6b1F9aB1f7C2c3355d22EBd',
        ],
        vaultShares: [zeroAddress, zeroAddress],
        rateProviders: [zeroAddress, zeroAddress],
        detfWeight: 34n * 10n ** 16n,
        pairWeights: [33n * 10n ** 16n, 33n * 10n ** 16n],
        creationPairPerDetfWad: [10n ** 18n, 10n ** 18n],
        openingPairPerDetfWad: [0n, 0n],
        mintThreshold: 0n,
        burnThreshold: 0n,
        thresholdMode: 0,
        expansionEpochLength: 0n,
        expansionClosureRatePerYearWad: 0n,
        expansionMaxCatchUpEpochs: 0n,
        creator: zeroAddress,
        claimName: '',
        claimSymbol: '',
        bondName: '',
        bondSymbol: '',
      },
      predictedDetf: detf,
      poolManager: '0x1111111111111111111111111111111111111111',
      feeOracle: '0x2222222222222222222222222222222222222222',
    })
    expect(hook.n).toBe(3)
    expect(hook.tokens).toEqual([p0, p1, detf])
    expect(hook.weights[2]).toBe(34n * 10n ** 16n)
    expect(hook.weights[0]).toBe(33n * 10n ** 16n)
    expect(hook.owner).toBe(detf)
    expect(hook.ownerOnlyLiquidity).toBe(true)
  })
})
