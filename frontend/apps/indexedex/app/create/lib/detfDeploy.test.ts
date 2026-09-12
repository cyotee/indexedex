import { readFileSync } from 'node:fs'
import { CP_HOOK_ARGS_COMPONENTS, WEIGHTED_HOOK_ARGS_COMPONENTS, QUAD_HOOK_ARGS_COMPONENTS, UNI_V4_DETF_PKG_ARGS_COMPONENTS } from './detfAbi'
import { describe, expect, it } from 'vitest'
import { decodeAbiParameters, zeroAddress } from 'viem'

import { emptyPlan } from './createPlan'
import {
  QUAD_BASE_AMP,
  ROUTE_TABLE_DEFAULT,
  buildCpHookArgs,
  buildQuadHookArgs,
  buildUniV4DetfArgs,
  buildWeightedHookArgs,
  encodeHookArgsForPlan,
  encodeCpHookArgs,
  encodeQuadHookArgs,
  encodeUniV4DetfPkgArgs,
  encodeWeightedHookArgs,
  hookPkgForPlan,
  productTokensWeighted,
  sortAddresses,
  unorderedPairs,
} from './detfDeploy'
import type { SePlatform } from './sePlatform'

const CREATOR = '0xF4c08ec327a84E08e3189ab782484298B1909984' as const
const VAULT_A = '0xCc4A3951D3569c987Ef9742F29E5b61Cb483d099' as const
const VAULT_B = '0xfb40276683454159A6b1F9aB1f7C2c3355d22EBd' as const
const VAULT_C = '0x1111111111111111111111111111111111111111' as const
const PAIR_A = '0xd97e3BCF599A5dbc893387680868d4Ad76E81206' as const
const PAIR_B = '0x2222222222222222222222222222222222222222' as const
const PAIR_C = '0x3333333333333333333333333333333333333333' as const

describe('buildUniV4DetfArgs', () => {
  it('maps a one-vault plan onto unified DETF PkgArgs with Default routes', () => {
    const p = emptyPlan()
    p.typeId = 'one-vault'
    p.name = 'Nvidia single'
    p.symbol = 'NVDA-S'
    p.vaults = [VAULT_A]
    p.pairToken = PAIR_A
    p.creationPairPerDetf = ['1']
    p.openingPairPerDetf = ['']
    p.mintBandPct = '5'
    p.burnBandPct = '5'
    const args = buildUniV4DetfArgs(p, CREATOR)
    expect(args.name).toBe('Nvidia single')
    expect(args.symbol).toBe('NVDA-S')
    expect(args.hook).toBe(zeroAddress)
    expect(args.creationPairPerDetfWad).toEqual([10n ** 18n])
    expect(args.openingPairPerDetfWad).toEqual([])
    expect(args.mintThreshold).toBe(105n * 10n ** 16n)
    expect(args.burnThreshold).toBe(95n * 10n ** 16n)
    expect(args).not.toHaveProperty('thresholdMode')
    expect(args).not.toHaveProperty('expansionEpochLength')
    expect(args).not.toHaveProperty('expansionMaxCatchUpEpochs')
    expect(args.mintRouteMode).toBe(ROUTE_TABLE_DEFAULT)
    expect(args.mintRoutes).toEqual([])
    expect(args).not.toHaveProperty('closeRouteMode')
    expect(args).not.toHaveProperty('closeRoutes')
    expect(args.creator).toBe(CREATOR)
    expect(encodeUniV4DetfPkgArgs(args).startsWith('0x')).toBe(true)
  })

  it('orders creation rates to match sorted hook pair tokens', () => {
    const p = emptyPlan()
    p.typeId = 'weighted'
    p.name = 'Two strat'
    p.symbol = 'TS-DETF'
    p.vaults = [VAULT_A, VAULT_B]
    p.pairTokens = [PAIR_B, PAIR_A]
    p.detfWeight = '34'
    p.weights = ['33', '33']
    p.creationPairPerDetf = ['2', '3']
    p.openingPairPerDetf = ['', '']
    const args = buildUniV4DetfArgs(p, CREATOR)
    const sorted = sortAddresses([PAIR_B, PAIR_A])
    expect(sorted).toEqual([PAIR_B, PAIR_A])
    expect(args.creationPairPerDetfWad).toEqual([2n * 10n ** 18n, 3n * 10n ** 18n])
  })
})

describe('hook bindings', () => {
  it('binds CP hook owner and raw token to the predicted DETF', () => {
    const detf = '0x0000000000000000000000000000000000000009' as const
    const hook = buildCpHookArgs({
      predictedDetf: detf,
      ownerOnlyLiquidity: true,
      pairToken: PAIR_A,
      standardExchange: VAULT_A,
      poolManager: '0x1111111111111111111111111111111111111111',
      feeOracle: '0x2222222222222222222222222222222222222222',
      pairTokenDecimals: 6,
    })
    expect(hook.rawToken).toBe(detf)
    expect(hook.owner).toBe(detf)
    expect(hook.ownerOnlyLiquidity).toBe(true)
    expect(hook.pairToken).toBe(PAIR_A)
    expect(hook.pairTokenDecimals).toBe(6)
    expect(hook.rawTokenDecimals).toBe(9)
    expect(encodeCpHookArgs(hook).startsWith('0x')).toBe(true)
  })

  it('sorts DETF plus pairs and places weights on binding indices', () => {
    const detf = '0x0000000000000000000000000000000000000003' as const
    const p0 = '0x0000000000000000000000000000000000000001' as const
    const p1 = '0x0000000000000000000000000000000000000002' as const
    expect(sortAddresses([detf, p0, p1])).toEqual([p0, p1, detf])
    expect(productTokensWeighted(detf, [p0, p1])).toEqual([p0, p1, detf])
    expect(unorderedPairs([p0, p1, detf])).toHaveLength(3)
    const hook = buildWeightedHookArgs({
      predictedDetf: detf,
      ownerOnlyLiquidity: true,
      pairTokens: [p0, p1],
      standardExchanges: [VAULT_A, VAULT_B],
      detfWeight: 34n * 10n ** 16n,
      pairWeights: [33n * 10n ** 16n, 33n * 10n ** 16n],
      poolManager: '0x1111111111111111111111111111111111111111',
      feeOracle: '0x2222222222222222222222222222222222222222',
      pairTokenDecimals: [6, 18],
      seShareDecimals: [18, 18],
    })
    expect(hook.n).toBe(3)
    expect(hook.tokens).toEqual([p0, p1, detf])
    expect(hook.weights[2]).toBe(34n * 10n ** 16n)
    expect(hook.weights[0]).toBe(33n * 10n ** 16n)
    expect(hook.owner).toBe(detf)
    expect(hook.ownerOnlyLiquidity).toBe(true)
    expect(hook.tokenDecimals).toEqual([6, 18, 9])
    expect(hook.seDecimals).toEqual([18, 18, 0])
    expect(encodeWeightedHookArgs(hook).startsWith('0x')).toBe(true)
  })

  it('sorts quad tokens and parks a zero SE on the DETF slot', () => {
    const detf = '0x0000000000000000000000000000000000000009' as const
    const hook = buildQuadHookArgs({
      predictedDetf: detf,
      ownerOnlyLiquidity: true,
      pairTokens: [PAIR_A, PAIR_B, PAIR_C],
      standardExchanges: [VAULT_A, VAULT_B, VAULT_C],
      poolManager: '0x1111111111111111111111111111111111111111',
      feeOracle: '0x2222222222222222222222222222222222222222',
      pairTokenDecimals: [6, 6, 18],
      seShareDecimals: [18, 18, 18],
    })
    expect(hook.tokens).toHaveLength(4)
    expect(hook.tokens.slice().sort((a, b) => (BigInt(a) < BigInt(b) ? -1 : 1))).toEqual(hook.tokens)
    expect(hook.baseAmp).toBe(QUAD_BASE_AMP)
    const detfIdx = hook.tokens.findIndex((t) => t.toLowerCase() === detf.toLowerCase())
    expect(hook.standardExchanges[detfIdx]).toBe(zeroAddress)
    expect(hook.standardExchanges.filter((a) => a !== zeroAddress)).toHaveLength(3)
    expect(hook.owner).toBe(detf)
    expect(hook.tokenDecimals[detfIdx]).toBe(9)
    expect(hook.seDecimals[detfIdx]).toBe(0)
    expect(hook.tokenDecimals).toHaveLength(4)
    expect(hook.seDecimals).toHaveLength(4)
    expect(encodeQuadHookArgs(hook).startsWith('0x')).toBe(true)
  })
})

describe('hookPkgForPlan', () => {
  it('maps basket shape to hook packages, not family DETF packages', () => {
    const platform = {
      cpHookPkg: VAULT_A,
      weightedHookPkg: VAULT_B,
      curveQuadHookPkg: VAULT_C,
    } as unknown as SePlatform
    const one = emptyPlan()
    one.typeId = 'one-vault'
    expect(hookPkgForPlan(one, platform)).toBe(VAULT_A)
    const w = emptyPlan()
    w.typeId = 'weighted'
    expect(hookPkgForPlan(w, platform)).toBe(VAULT_B)
    const s = emptyPlan()
    s.typeId = 'stables'
    expect(hookPkgForPlan(s, platform)).toBe(VAULT_C)
  })
})


describe('deployment ABI agreement', () => {
  it('matches the funded Solidity PkgArgs field order and types, including the still-pending close config', () => {
    const source = readFileSync(new URL('../../../../../../contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol', import.meta.url), 'utf8')
    const body = source.match(/struct PkgArgs\s*\{([\s\S]*?)\}/)?.[1]
    expect(body).toBeDefined()
    const fields = body!.split(';').map((line) => line.trim()).filter(Boolean).map((line) => {
      const [type, name] = line.split(/\s+/)
      return { name, type: type === 'RouteTableMode' ? 'uint8' : type === 'IoRoute[]' ? 'tuple[]' : type }
    })
    expect(UNI_V4_DETF_PKG_ARGS_COMPONENTS.map(({ name, type }) => ({ name, type }))).toEqual(fields)
  })
})


describe('reserve liquidity policy deployment', () => {
  it.each([true, false])('carries ownerOnlyLiquidity=%s through every UI reserve family and DETF payload', (policy) => {
    const detf = '0x0000000000000000000000000000000000000009' as const
    for (const typeId of ['one-vault', 'weighted', 'stables'] as const) {
      const plan = { ...emptyPlan(), typeId, ownerOnlyLiquidity: policy,
        name: 'Policy DETF', symbol: 'DETF', pairToken: PAIR_A,
        vaults: typeId === 'one-vault' ? [VAULT_A] : typeId === 'weighted' ? [VAULT_A, VAULT_B] : [VAULT_A, VAULT_B, VAULT_C],
        pairTokens: typeId === 'weighted' ? [PAIR_A, PAIR_B] : [PAIR_A, PAIR_B, PAIR_C],
        detfWeight: '34', weights: ['33', '33'],
      }
      const encoded = encodeHookArgsForPlan({ plan, predictedDetf: detf, poolManager: PAIR_B, feeOracle: PAIR_C,
        scales: { pairTokenDecimals: [6, 18, 6], seShareDecimals: [18, 18, 18] } })
      const components = typeId === 'one-vault' ? CP_HOOK_ARGS_COMPONENTS : typeId === 'weighted' ? WEIGHTED_HOOK_ARGS_COMPONENTS : QUAD_HOOK_ARGS_COMPONENTS
      const [hook] = decodeAbiParameters([{ type: 'tuple', components }], encoded)
      const [args] = decodeAbiParameters([{ type: 'tuple', components: UNI_V4_DETF_PKG_ARGS_COMPONENTS }], encodeUniV4DetfPkgArgs(buildUniV4DetfArgs(plan, CREATOR)))
      expect(hook.ownerOnlyLiquidity).toBe(policy)
      expect(args.ownerOnlyLiquidity).toBe(policy)
      expect(hook.owner.toLowerCase()).toBe(detf.toLowerCase())
      expect(args.creator.toLowerCase()).toBe(CREATOR.toLowerCase())
    }
  })
})
