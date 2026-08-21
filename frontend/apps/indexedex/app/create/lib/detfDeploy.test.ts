import { describe, expect, it } from 'vitest'
import { zeroAddress } from 'viem'

import { emptyPlan } from './createPlan'
import { buildCpDetfArgs } from './detfDeploy'

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
