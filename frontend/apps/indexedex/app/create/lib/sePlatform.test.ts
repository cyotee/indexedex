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

  it('does not treat a legacy name match as permission to deploy the new family', () => {
    expect(looksLikeV4SePkg('UniswapV4StandardExchangeDFPkg')).toBe(true)
    expect(
      selectV4SePkg({
        ...namedBoth,
        uniV4SePkgName: 'UniswapV4StandardExchangeDFPkg',
        hooks: ZERO_ADDRESS,
      }),
    ).toEqual({ status: 'stale', family: 'hookless', pkg: null })
    expect(
      selectV4SePkg({
        ...namedBoth,
        uniV4PonsSePkgName: 'UniswapV4StandardExchangeDFPkg',
        hooks: PONS_HOOK,
      }),
    ).toEqual({ status: 'stale', family: 'pons', pkg: null })
  })
})

describe('selectV4SePkg', () => {
  it('selects hookless for a zero-hook key when H has the current family name', () => {
    expect(selectV4SePkg({ ...namedBoth, hooks: ZERO_ADDRESS })).toEqual({
      status: 'ready',
      family: 'hookless',
      pkg: HOOKLESS_PKG,
    })
    expect(selectV4SePkg({ ...namedBoth, hooks: '' })).toEqual({
      status: 'ready',
      family: 'hookless',
      pkg: HOOKLESS_PKG,
    })
    expect(selectV4SePkg({ ...namedBoth, hooks: null })).toEqual({
      status: 'ready',
      family: 'hookless',
      pkg: HOOKLESS_PKG,
    })
  })

  it('reports missing hookless when a zero-hook key has no H artifact', () => {
    expect(
      selectV4SePkg({
        ...namedBoth,
        hooks: ZERO_ADDRESS,
        uniV4SePkg: null,
      }),
    ).toEqual({ status: 'missing', family: 'hookless', pkg: null })
    expect(
      v4SePkgSelectionMessage({ status: 'missing', family: 'hookless', pkg: null }),
    ).toBe('No Uniswap V4 SE package on this network.')
  })

  it('rejects unnamed historical H addresses as stale, not ready', () => {
    const stale = selectV4SePkg({
      ...namedBoth,
      hooks: ZERO_ADDRESS,
      uniV4SePkgName: null,
    })
    expect(stale).toEqual({ status: 'stale', family: 'hookless', pkg: null })
    expect(v4SePkgSelectionMessage(stale)).toBe(
      'This Uniswap V4 SE package is not the current family.',
    )
  })

  it('rejects the wrong family name on a hookless address', () => {
    expect(
      selectV4SePkg({
        ...namedBoth,
        hooks: ZERO_ADDRESS,
        uniV4SePkgName: PONS_V4_SE_PKG_NAME,
      }),
    ).toEqual({ status: 'stale', family: 'hookless', pkg: null })
  })

  it('selects Pons when the exported hook binding and current P name match', () => {
    expect(selectV4SePkg({ ...namedBoth, hooks: PONS_HOOK })).toEqual({
      status: 'ready',
      family: 'pons',
      pkg: PONS_PKG,
    })
    expect(
      selectV4SePkg({
        ...namedBoth,
        hooks: '0xaAaAaAaAaAaAaAaAaAaAaAaAaAaAaAaAaAaAaAaA',
      }),
    ).toEqual({
      status: 'ready',
      family: 'pons',
      pkg: PONS_PKG,
    })
  })

  it('does not fall back to H when the Pons hook is set and P is missing', () => {
    const missingP = selectV4SePkg({
      ...namedBoth,
      hooks: PONS_HOOK,
      uniV4PonsSePkg: null,
    })
    expect(missingP).toEqual({ status: 'missing', family: 'pons', pkg: null })
    expect(missingP.pkg).not.toBe(HOOKLESS_PKG)
    expect(v4SePkgSelectionMessage(missingP)).toBe('No Pons SE package on this network.')
  })

  it('rejects missing or wrong Pons family metadata as stale', () => {
    expect(
      selectV4SePkg({
        ...namedBoth,
        hooks: PONS_HOOK,
        uniV4PonsSePkgName: null,
      }),
    ).toEqual({ status: 'stale', family: 'pons', pkg: null })
    expect(
      selectV4SePkg({
        ...namedBoth,
        hooks: PONS_HOOK,
        uniV4PonsSePkgName: HOOKLESS_V4_SE_PKG_NAME,
      }),
    ).toEqual({ status: 'stale', family: 'pons', pkg: null })
  })

  it('fails closed for a nonzero hook when the canonical hook binding is missing', () => {
    const noBinding = selectV4SePkg({
      ...namedBoth,
      uniV4PonsSeHook: null,
      hooks: PONS_HOOK,
    })
    expect(noBinding).toEqual({ status: 'unsupported', family: null, pkg: null })
    expect(noBinding.pkg).not.toBe(HOOKLESS_PKG)
    expect(v4SePkgSelectionMessage(noBinding)).toBe('This Uniswap V4 hook is not supported.')
  })

  it('rejects an unsupported hook before any family package can be used', () => {
    const unsupported = selectV4SePkg({ ...namedBoth, hooks: OTHER_HOOK })
    expect(unsupported).toEqual({ status: 'unsupported', family: null, pkg: null })
    expect(v4SePkgSelectionMessage(unsupported)).toBe('This Uniswap V4 hook is not supported.')
  })

  it('rejects a non-address hook instead of treating it as hookless', () => {
    expect(selectV4SePkg({ ...namedBoth, hooks: 'not-an-address' })).toEqual({
      status: 'unsupported',
      family: null,
      pkg: null,
    })
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
    ).toEqual({ status: 'ready', family: 'hookless', pkg: HOOKLESS_PKG })
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
    ).toEqual({ status: 'stale', family: 'hookless', pkg: null })
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
