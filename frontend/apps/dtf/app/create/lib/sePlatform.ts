import {
  getAddressArtifacts,
  type DeploymentEnvironment,
} from '@indexedex/protocol/addressArtifacts'
import { ROBINHOOD_UNISWAP_V4 } from '../../swap/lib/v4Addresses'
import { ZERO_ADDRESS, type Address } from '../../swap/lib/v4Types'

function asAddr(value: unknown): Address | null {
  if (typeof value !== 'string') return null
  if (!/^0x[0-9a-fA-F]{40}$/.test(value)) return null
  if (value.toLowerCase() === ZERO_ADDRESS) return null
  return value as Address
}

export type SePlatform = {
  registry: Address | null
  poolManager: Address | null
  stateView: Address | null
  v3Factory: Address | null
  uniV4SePkg: Address | null
  uniV3SePkg: Address | null
  cpDetfPkg: Address | null
  cpHookPkg: Address | null
  curveQuadDetfPkg: Address | null
  weightedDetfPkg: Address | null
  weightedHookPkg: Address | null
  morpho: Address | null
  morphoBlueSePkg: Address | null
  morphoIrm: Address | null
  morphoOracle: Address | null
  hookFactory: Address | null
  diamondPackageFactory: Address | null
  feeOracle: Address | null
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
  const manager = asAddr(platform.indexedexManager) ?? asAddr(platform.vaultRegistry)
  return {
    registry: asAddr(platform.vaultRegistry) ?? manager,
    poolManager: asAddr(platform.poolManager) ?? ROBINHOOD_UNISWAP_V4.poolManager,
    stateView: asAddr(platform.v4StateView) ?? asAddr(platform.stateView) ?? ROBINHOOD_UNISWAP_V4.stateView,
    v3Factory: asAddr(platform.v3Factory) ?? asAddr(platform.uniswapV3Factory),
    uniV4SePkg: asAddr(platform.uniV4SePkg),
    uniV3SePkg: asAddr(platform.uniV3SePkg) ?? asAddr(platform.uniV3SePkg_rich),
    cpDetfPkg: asAddr(platform.cpDetfPkg) ?? asAddr(platform.chirDetfPkg),
    cpHookPkg: asAddr(platform.cpHookPkg) ?? asAddr(platform.bufferCpHookPkg),
    curveQuadDetfPkg: asAddr(platform.curveQuadDetfPkg),
    weightedDetfPkg: asAddr(platform.weightedDetfPkg),
    weightedHookPkg: asAddr(platform.weightedHookPkg),
    morpho: asAddr(platform.morpho) ?? asAddr(platform.morphoBlue),
    morphoBlueSePkg: asAddr(platform.morphoBlueSePkg),
    morphoIrm: asAddr(platform.morphoIrm) ?? asAddr(platform.morphoAdaptiveCurveIrm),
    morphoOracle: asAddr(platform.morphoOracle),
    hookFactory: asAddr(platform.hookFactory),
    diamondPackageFactory: asAddr(platform.diamondPackageFactory),
    feeOracle: asAddr(platform.indexedexManager) ?? asAddr(platform.feeOracle),
  }
}

export function looksLikeV4SePkg(name: string): boolean {
  return /UniswapV4StandardExchangeDFPkg/i.test(name) && !/DETF/i.test(name)
}

export function looksLikeV3SePkg(name: string): boolean {
  return /UniswapV3StandardExchangeDFPkg/i.test(name) && !/DETF/i.test(name)
}
