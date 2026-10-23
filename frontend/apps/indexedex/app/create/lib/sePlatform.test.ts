import { describe, expect, it } from 'vitest'

import { ZERO_ADDRESS, type Address } from '../../swap/lib/v4Types'
import {
  HOOKLESS_V4_SE_PKG_NAME,
  looksLikeV3SePkg,
  looksLikeV4SePkg,
  PONS_V4_SE_PKG_NAME,
  resolveSePlatform,
  sePlatformFromRecord,
  selectV4SePkg,
  v4SePkgSelectionMessage,
} from './sePlatform'

const HOOKLESS_PKG = '0x1111111111111111111111111111111111111111' as Address
const PONS_PKG = '0x2222222222222222222222222222222222222222' as Address
const PONS_HOOK = '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' as Address
const OTHER_HOOK = '0x3333333333333333333333333333333333333333'
const V3_PKG = '0x4444444444444444444444444444444444444444'
const MORPHO_PKG = '0x5555555555555555555555555555555555555555'

const namedBoth = {
  uniV4SePkg: HOOKLESS_PKG,
  uniV4SePkgName: HOOKLESS_V4_SE_PKG_NAME,
  uniV4PonsSePkg: PONS_PKG,
  uniV4PonsSePkgName: PONS_V4_SE_PKG_NAME,
  uniV4PonsSeHook: PONS_HOOK,
}

describe('Standard Exchange package identities', () => {
  it.each([
    'UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg',
    'UniswapV4FullSpreadPonsFamilyHookDFPkg',
    'UniswapV4StandardExchangeDFPkg',
    'UniswapV4FullSpreadStandardExchangeVaultDFPkg',
  ])('recognizes %s without treating it as V3', (name) => {
    expect(looksLikeV4SePkg(name)).toBe(true)
    expect(looksLikeV4SePkg(name.toLowerCase())).toBe(true)
    expect(looksLikeV3SePkg(name)).toBe(false)
  })

  it.each([
    '',
    'UniswapV4DetfDFPkg',
    'UniswapV4FullSpreadHooklessStandardExchangeVaultInFacet',
    'UniswapV4FullSpreadPonsFamilyHookDFPkgDETF',
    'UniswapV3StandardExchangeDFPkg',
  ])('does not identify %s as a V4 SE package', (name) => {
    expect(looksLikeV4SePkg(name)).toBe(false)
  })

  it('preserves V3 package recognition', () => {
    expect(looksLikeV3SePkg('UniswapV3StandardExchangeDFPkg')).toBe(true)
  })

  it('does not treat a historical name as permission to deploy a deprecated family', () => {
    expect(looksLikeV4SePkg('UniswapV4StandardExchangeDFPkg')).toBe(true)
    expect(selectV4SePkg({ ...namedBoth, hooks: ZERO_ADDRESS })).toEqual({
      status: 'unsupported',
      family: null,
      pkg: null,
    })
    expect(v4SePkgSelectionMessage({ status: 'unsupported', family: null, pkg: null })).
      toBe('Uniswap V4 FullSpread vaults were removed.')
  })
})

describe('selectV4SePkg', () => {
  it.each([ZERO_ADDRESS, '', null, PONS_HOOK, OTHER_HOOK, 'not-an-address'])(
    'rejects FullSpread deployment for %s',
    (hooks) => {
      expect(selectV4SePkg({ ...namedBoth, hooks })).toEqual({
        status: 'unsupported',
        family: null,
        pkg: null,
      })
      expect(selectV4SePkg({ ...namedBoth, hooks }).pkg).not.toBe(HOOKLESS_PKG)
      expect(selectV4SePkg({ ...namedBoth, hooks }).pkg).not.toBe(PONS_PKG)
    },
  )

  it('uses the deprecation message for the unsupported selection', () => {
    expect(v4SePkgSelectionMessage({ status: 'unsupported', family: null, pkg: null })).toBe(
      'Uniswap V4 FullSpread vaults were removed.',
    )
  })
})


describe('resolveSePlatform FullSpread packages', () => {
  it('exposes P package, hook binding, and family names from backend export metadata', () => {
    const platform = sePlatformFromRecord({
      uniV4SePkg: HOOKLESS_PKG,
      uniV4SePkgName: HOOKLESS_V4_SE_PKG_NAME,
      uniV4PonsSePkg: PONS_PKG,
      uniV4PonsSePkgName: PONS_V4_SE_PKG_NAME,
      uniV4PonsSeHook: PONS_HOOK,
      uniV3SePkg: V3_PKG,
      morphoBlueSePkg: MORPHO_PKG,
    })
    expect(platform.uniV4SePkg).toBe(HOOKLESS_PKG)
    expect(platform.uniV4PonsSePkg).toBe(PONS_PKG)
    expect(platform.uniV4PonsSeHook).toBe(PONS_HOOK)
    expect(platform.uniV4SePkgName).toBe(HOOKLESS_V4_SE_PKG_NAME)
    expect(platform.uniV4PonsSePkgName).toBe(PONS_V4_SE_PKG_NAME)
    expect(platform.uniV3SePkg).toBe(V3_PKG)
    expect(platform.morphoBlueSePkg).toBe(MORPHO_PKG)
    expect(
      selectV4SePkg({
        hooks: ZERO_ADDRESS,
        uniV4SePkg: platform.uniV4SePkg,
        uniV4SePkgName: platform.uniV4SePkgName,
        uniV4PonsSePkg: platform.uniV4PonsSePkg,
        uniV4PonsSePkgName: platform.uniV4PonsSePkgName,
        uniV4PonsSeHook: platform.uniV4PonsSeHook,
      }),
    ).toEqual({ status: 'unsupported', family: null, pkg: null })
  })

  it('rejects a zero hook binding as missing, not a Pons identity', () => {
    const platform = sePlatformFromRecord({
      uniV4PonsSeHook: ZERO_ADDRESS,
      uniV4PonsSePkg: PONS_PKG,
      uniV4PonsSePkgName: PONS_V4_SE_PKG_NAME,
    })
    expect(platform.uniV4PonsSeHook).toBeNull()
  })

  it('keeps 46630 hookless-only: H present, P and hook binding absent', () => {
    const platform = resolveSePlatform(46630, 'anvil_robinhood_testnet')
    expect(platform.uniV4SePkg).toBeTruthy()
    expect(platform.uniV4PonsSePkg).toBeNull()
    expect(platform.uniV4PonsSeHook).toBeNull()
    expect(platform.uniV4PonsSePkgName).toBeNull()
    expect(
      selectV4SePkg({
        hooks: ZERO_ADDRESS,
        uniV4SePkg: platform.uniV4SePkg,
        uniV4SePkgName: platform.uniV4SePkgName,
        uniV4PonsSePkg: platform.uniV4PonsSePkg,
        uniV4PonsSePkgName: platform.uniV4PonsSePkgName,
        uniV4PonsSeHook: platform.uniV4PonsSeHook,
      }),
    ).toEqual({ status: 'unsupported', family: null, pkg: null })
    expect(
      selectV4SePkg({
        hooks: OTHER_HOOK,
        uniV4SePkg: platform.uniV4SePkg,
        uniV4SePkgName: HOOKLESS_V4_SE_PKG_NAME,
        uniV4PonsSePkg: platform.uniV4PonsSePkg,
        uniV4PonsSePkgName: platform.uniV4PonsSePkgName,
        uniV4PonsSeHook: platform.uniV4PonsSeHook,
      }),
    ).toEqual({ status: 'unsupported', family: null, pkg: null })
  })

  it('keeps 4663 V3 and Morpho packages independent of V4 family selection', () => {
    const platform = resolveSePlatform(4663, 'anvil_robinhood_main')
    expect(platform.uniV4SePkg).toBeTruthy()
    expect(platform.morphoBlueSePkg).toBeTruthy()
    expect(
      selectV4SePkg({
        hooks: OTHER_HOOK,
        uniV4SePkg: platform.uniV4SePkg,
        uniV4SePkgName: platform.uniV4SePkgName,
        uniV4PonsSePkg: platform.uniV4PonsSePkg,
        uniV4PonsSePkgName: platform.uniV4PonsSePkgName,
        uniV4PonsSeHook: platform.uniV4PonsSeHook,
      }),
    ).toEqual({ status: 'unsupported', family: null, pkg: null })
  })
})
