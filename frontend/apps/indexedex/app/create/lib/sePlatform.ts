import {
  getAddressArtifacts,
  type DeploymentEnvironment,
} from '@indexedex/protocol/addressArtifacts'
import { ROBINHOOD_UNISWAP_V4 } from '../../swap/lib/v4Addresses'
import { ZERO_ADDRESS, type Address } from '../../swap/lib/v4Types'

export const HOOKLESS_V4_SE_PKG_NAME = 'UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg'
export const PONS_V4_SE_PKG_NAME = 'UniswapV4FullSpreadPonsFamilyHookDFPkg'

function asAddr(value: unknown): Address | null {
  if (typeof value !== 'string') return null
  if (!/^0x[0-9a-fA-F]{40}$/.test(value)) return null
  if (value.toLowerCase() === ZERO_ADDRESS) return null
  return value as Address
}

function asName(value: unknown): string | null {
  if (typeof value !== 'string') return null
  const name = value.trim()
  return name ? name : null
}

function sameAddr(a: string, b: string): boolean {
  return a.trim().toLowerCase() === b.trim().toLowerCase()
}

export type SePlatform = {
  registry: Address | null
  poolManager: Address | null
  stateView: Address | null
  v3Factory: Address | null
  uniV4SePkg: Address | null
  uniV4SePkgName: string | null
  uniV4PonsSePkg: Address | null
  uniV4PonsSePkgName: string | null
  uniV4PonsSeHook: Address | null
  uniV3SePkg: Address | null
  uniV4DetfPkg: Address | null
  cpDetfPkg: Address | null
  cpHookPkg: Address | null
  curveQuadDetfPkg: Address | null
  curveQuadHookPkg: Address | null
  weightedDetfPkg: Address | null
  weightedHookPkg: Address | null
  orbitalHookPkg: Address | null
  morpho: Address | null
  morphoBlueSePkg: Address | null
  morphoIrm: Address | null
  morphoOracle: Address | null
  hookFactory: Address | null
  diamondPackageFactory: Address | null
  feeOracle: Address | null
  weth: Address | null
}

export function sePlatformFromRecord(platform: Record<string, unknown>): SePlatform {
  const manager = asAddr(platform.indexedexManager) ?? asAddr(platform.vaultRegistry)
  return {
    registry: asAddr(platform.vaultRegistry) ?? manager,
    poolManager: asAddr(platform.poolManager) ?? ROBINHOOD_UNISWAP_V4.poolManager,
    stateView: asAddr(platform.v4StateView) ?? asAddr(platform.stateView) ?? ROBINHOOD_UNISWAP_V4.stateView,
    v3Factory: asAddr(platform.v3Factory) ?? asAddr(platform.uniswapV3Factory),
    uniV4SePkg: asAddr(platform.uniV4SePkg),
    uniV4SePkgName: asName(platform.uniV4SePkgName),
    uniV4PonsSePkg: asAddr(platform.uniV4PonsSePkg),
    uniV4PonsSePkgName: asName(platform.uniV4PonsSePkgName),
    uniV4PonsSeHook: asAddr(platform.uniV4PonsSeHook),
    uniV3SePkg: asAddr(platform.uniV3SePkg) ?? asAddr(platform.uniV3SePkg_rich),
    uniV4DetfPkg: asAddr(platform.uniV4DetfPkg) ?? asAddr(platform.uniswapV4DetfPkg),
    cpDetfPkg: asAddr(platform.cpDetfPkg) ?? asAddr(platform.chirDetfPkg),
    cpHookPkg: asAddr(platform.cpHookPkg) ?? asAddr(platform.bufferCpHookPkg),
    curveQuadDetfPkg: asAddr(platform.curveQuadDetfPkg),
    curveQuadHookPkg: asAddr(platform.curveQuadHookPkg),
    weightedDetfPkg: asAddr(platform.weightedDetfPkg),
    weightedHookPkg: asAddr(platform.weightedHookPkg),
    orbitalHookPkg: asAddr(platform.orbitalHookPkg),
    morpho: asAddr(platform.morpho) ?? asAddr(platform.morphoBlue),
    morphoBlueSePkg: asAddr(platform.morphoBlueSePkg),
    morphoIrm: asAddr(platform.morphoIrm) ?? asAddr(platform.morphoAdaptiveCurveIrm),
    morphoOracle: asAddr(platform.morphoOracle),
    hookFactory: asAddr(platform.hookFactory),
    diamondPackageFactory: asAddr(platform.diamondPackageFactory),
    feeOracle: asAddr(platform.indexedexManager) ?? asAddr(platform.feeOracle),
    weth: asAddr(platform.weth9) ?? asAddr(platform.weth),
  }
}

export function resolveSePlatform(
  chainId: number,
  environment: DeploymentEnvironment,
): SePlatform {
  let platform: Record<string, unknown> = {}
  try {
    platform = getAddressArtifacts(chainId, environment).platform as Record<string, unknown>
  } catch {
    platform = {}
  }
  return sePlatformFromRecord(platform)
}

export type V4SeFamily = 'hookless' | 'pons'

export type V4SePkgSelection =
  | { status: 'ready'; family: V4SeFamily; pkg: Address }
  | { status: 'missing'; family: V4SeFamily; pkg: null }
  | { status: 'stale'; family: V4SeFamily; pkg: null }
  | { status: 'unsupported'; family: null; pkg: null }

function isZeroHook(hooks: string | null | undefined): boolean {
  if (hooks == null) return true
  const value = hooks.trim()
  if (!value) return true
  return value.toLowerCase() === ZERO_ADDRESS
}

export function selectV4SePkg(input: {
  hooks?: string | null
  uniV4SePkg: Address | null
  uniV4SePkgName: string | null
  uniV4PonsSePkg: Address | null
  uniV4PonsSePkgName: string | null
  uniV4PonsSeHook: Address | null
}): V4SePkgSelection {
  const hooks = input.hooks?.trim() ?? ''
  if (isZeroHook(hooks)) {
    if (!input.uniV4SePkg) return { status: 'missing', family: 'hookless', pkg: null }
    if (input.uniV4SePkgName !== HOOKLESS_V4_SE_PKG_NAME) {
      return { status: 'stale', family: 'hookless', pkg: null }
    }
    return { status: 'ready', family: 'hookless', pkg: input.uniV4SePkg }
  }
  if (!/^0x[0-9a-fA-F]{40}$/.test(hooks) || !input.uniV4PonsSeHook) {
    return { status: 'unsupported', family: null, pkg: null }
  }
  if (!sameAddr(hooks, input.uniV4PonsSeHook)) {
    return { status: 'unsupported', family: null, pkg: null }
  }
  if (!input.uniV4PonsSePkg) return { status: 'missing', family: 'pons', pkg: null }
  if (input.uniV4PonsSePkgName !== PONS_V4_SE_PKG_NAME) {
    return { status: 'stale', family: 'pons', pkg: null }
  }
  return { status: 'ready', family: 'pons', pkg: input.uniV4PonsSePkg }
}

export function v4SePkgSelectionMessage(selection: V4SePkgSelection): string | null {
  if (selection.status === 'ready') return null
  if (selection.status === 'unsupported') return 'This Uniswap V4 hook is not supported.'
  if (selection.status === 'stale') return 'This Uniswap V4 SE package is not the current family.'
  if (selection.family === 'pons') return 'No Pons SE package on this network.'
  return 'No Uniswap V4 SE package on this network.'
}

export function looksLikeV4SePkg(name: string): boolean {
  // Legacy identities remain discoverable for existing immutable deployments.
  return /UniswapV4(?:StandardExchange|FullSpread(?:StandardExchangeVault|HooklessStandardExchangeVault|PonsFamilyHook))DFPkg/i.test(name)
    && !/DETF/i.test(name)
}

export function looksLikeV3SePkg(name: string): boolean {
  return /UniswapV3StandardExchangeDFPkg/i.test(name) && !/DETF/i.test(name)
}
