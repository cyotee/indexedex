import sepoliaPlatformJson from './sepolia/base_deployments.json'
import sepoliaFactoriesJson from './sepolia/sepolia-factories.contractlist.json'
import sepoliaTokensJson from './sepolia/sepolia-tokens.tokenlist.json'
import sepoliaErc4626Json from './sepolia/sepolia-erc4626.tokenlist.json'
import sepoliaStrategyVaultsJson from './sepolia/sepolia-strategy-vaults.tokenlist.json'
import sepoliaUniV2PoolsJson from './sepolia/sepolia-uniV2pool.tokenlist.json'
import sepoliaAerodromePoolsJson from './sepolia/sepolia-aerodrome-pools.tokenlist.json'
import sepoliaAerodromeStrategyVaultsJson from './sepolia/sepolia-aerodrome-strategy-vaults.tokenlist.json'
import sepoliaBalancerPoolsJson from './sepolia/sepolia-balancerv3-pools.tokenlist.json'
import sepoliaSeigniorageDetfsJson from './sepolia/sepolia-seigniorage-detfs.tokenlist.json'
import sepoliaProtocolDetfJson from './sepolia/sepolia-protocol-detf.tokenlist.json'

import publicSepoliaEthereumPlatformJson from './public_sepolia/ethereum/base_deployments.json'
import publicSepoliaEthereumTokensJson from './public_sepolia/ethereum/public_sepolia-tokens.tokenlist.json'
import publicSepoliaEthereumErc4626Json from './public_sepolia/ethereum/public_sepolia-erc4626.tokenlist.json'
import publicSepoliaEthereumStrategyVaultsJson from './public_sepolia/ethereum/public_sepolia-strategy-vaults.tokenlist.json'
import publicSepoliaEthereumUniV2PoolsJson from './public_sepolia/ethereum/public_sepolia-uniV2pool.tokenlist.json'
import publicSepoliaEthereumAerodromePoolsJson from './public_sepolia/ethereum/public_sepolia-aerodrome-pools.tokenlist.json'
import publicSepoliaEthereumAerodromeStrategyVaultsJson from './public_sepolia/ethereum/public_sepolia-aerodrome-strategy-vaults.tokenlist.json'
import publicSepoliaEthereumBalancerPoolsJson from './public_sepolia/ethereum/public_sepolia-balancerv3-pools.tokenlist.json'
import publicSepoliaEthereumSeigniorageDetfsJson from './public_sepolia/ethereum/public_sepolia-seigniorage-detfs.tokenlist.json'
import publicSepoliaEthereumProtocolDetfJson from './public_sepolia/ethereum/public_sepolia-protocol-detf.tokenlist.json'

import publicSepoliaBasePlatformJson from './public_sepolia/base/base_deployments.json'
import publicSepoliaBaseTokensJson from './public_sepolia/base/public_sepolia-tokens.tokenlist.json'
import publicSepoliaBaseErc4626Json from './public_sepolia/base/public_sepolia-erc4626.tokenlist.json'
import publicSepoliaBaseStrategyVaultsJson from './public_sepolia/base/public_sepolia-strategy-vaults.tokenlist.json'
import publicSepoliaBaseUniV2PoolsJson from './public_sepolia/base/public_sepolia-uniV2pool.tokenlist.json'
import publicSepoliaBaseAerodromePoolsJson from './public_sepolia/base/public_sepolia-aerodrome-pools.tokenlist.json'
import publicSepoliaBaseAerodromeStrategyVaultsJson from './public_sepolia/base/public_sepolia-aerodrome-strategy-vaults.tokenlist.json'
import publicSepoliaBaseBalancerPoolsJson from './public_sepolia/base/public_sepolia-balancerv3-pools.tokenlist.json'
import publicSepoliaBaseSeigniorageDetfsJson from './public_sepolia/base/public_sepolia-seigniorage-detfs.tokenlist.json'
import publicSepoliaBaseProtocolDetfJson from './public_sepolia/base/public_sepolia-protocol-detf.tokenlist.json'

import supersimEthereumPlatformJson from './supersim_sepolia/ethereum/base_deployments.json'
import supersimEthereumFactoriesJson from './supersim_sepolia/ethereum/sepolia-factories.contractlist.json'
import supersimEthereumTokensJson from './supersim_sepolia/ethereum/supersim_sepolia-tokens.tokenlist.json'
import supersimEthereumErc4626Json from './supersim_sepolia/ethereum/supersim_sepolia-erc4626.tokenlist.json'
import supersimEthereumStrategyVaultsJson from './supersim_sepolia/ethereum/supersim_sepolia-strategy-vaults.tokenlist.json'
import supersimEthereumUniV2PoolsJson from './supersim_sepolia/ethereum/supersim_sepolia-uniV2pool.tokenlist.json'
import supersimEthereumAerodromePoolsJson from './supersim_sepolia/ethereum/supersim_sepolia-aerodrome-pools.tokenlist.json'
import supersimEthereumAerodromeStrategyVaultsJson from './supersim_sepolia/ethereum/supersim_sepolia-aerodrome-strategy-vaults.tokenlist.json'
import supersimEthereumBalancerPoolsJson from './supersim_sepolia/ethereum/supersim_sepolia-balancerv3-pools.tokenlist.json'
import supersimEthereumSeigniorageDetfsJson from './supersim_sepolia/ethereum/supersim_sepolia-seigniorage-detfs.tokenlist.json'
import supersimEthereumProtocolDetfJson from './supersim_sepolia/ethereum/supersim_sepolia-protocol-detf.tokenlist.json'

import supersimBasePlatformJson from './supersim_sepolia/base/base_deployments.json'
import supersimBaseTokensJson from './supersim_sepolia/base/anvil_base_main-tokens.tokenlist.json'
import supersimBaseErc4626Json from './supersim_sepolia/base/anvil_base_main-erc4626.tokenlist.json'
import supersimBaseStrategyVaultsJson from './supersim_sepolia/base/anvil_base_main-strategy-vaults.tokenlist.json'
import supersimBaseUniV2PoolsJson from './supersim_sepolia/base/anvil_base_main-uniV2pool.tokenlist.json'
import supersimBaseAerodromePoolsJson from './supersim_sepolia/base/anvil_base_main-aerodrome-pools.tokenlist.json'
import supersimBaseAerodromeStrategyVaultsJson from './supersim_sepolia/base/anvil_base_main-aerodrome-strategy-vaults.tokenlist.json'
import supersimBaseBalancerPoolsJson from './supersim_sepolia/base/anvil_base_main-balancerv3-pools.tokenlist.json'
import supersimBaseSeigniorageDetfsJson from './supersim_sepolia/base/anvil_base_main-seigniorage-detfs.tokenlist.json'
import supersimBaseProtocolDetfJson from './supersim_sepolia/base/anvil_base_main-protocol-detf.tokenlist.json'

export const CHAIN_ID_SEPOLIA = 11155111 as const
export const CHAIN_ID_BASE_SEPOLIA = 84532 as const
const CANONICAL_PERMIT2_ADDRESS = '0x000000000022D473030F116dDEE9F6B43aC78BA3'

export type DeploymentEnvironment = 'sepolia' | 'public_sepolia' | 'supersim_sepolia'
export type ChainRole = 'ethereum' | 'base'
export type CanonicalArtifactChainId = typeof CHAIN_ID_SEPOLIA | typeof CHAIN_ID_BASE_SEPOLIA

export type ArtifactBundle = {
  environment: DeploymentEnvironment
  chainId: CanonicalArtifactChainId
  chainRole: ChainRole
  platform: any
  factories: any[]
  tokenlists: {
    tokens: any[]
    erc4626: any[]
    seigniorageDetfs: any[]
    protocolDetf: any[]
    strategyVaults: any[]
    uniV2Pools: any[]
    aerodromePools: any[]
    aerodromeStrategyVaults: any[]
    balancerPools: any[]
  }
}

const normalizePlatform = (platform: any, chainId: CanonicalArtifactChainId) => {
  const normalized = {
    ...(platform ?? {}),
    chainId,
  }

  const weth9 = normalized.weth9 ?? normalized.weth ?? null
  if (weth9) {
    normalized.weth9 = weth9
    normalized.weth = weth9
  }

  if (!normalized.permit2) {
    normalized.permit2 = CANONICAL_PERMIT2_ADDRESS
  }

  return normalized
}

const normalizeList = (list: any, chainId: CanonicalArtifactChainId) =>
  Array.isArray(list)
    ? list.map((entry) => ({
        ...(entry ?? {}),
        chainId,
      }))
    : []

const buildBundle = (
  environment: DeploymentEnvironment,
  chainId: CanonicalArtifactChainId,
  chainRole: ChainRole,
  source: {
    platform: any
    factories?: any[]
    tokens: any
    erc4626: any
    seigniorageDetfs: any
    protocolDetf: any
    strategyVaults: any
    uniV2Pools: any
    aerodromePools: any
    aerodromeStrategyVaults: any
    balancerPools: any
  }
): ArtifactBundle => ({
  environment,
  chainId,
  chainRole,
  platform: normalizePlatform(source.platform, chainId),
  factories: Array.isArray(source.factories) ? source.factories : [],
  tokenlists: {
    tokens: normalizeList(source.tokens, chainId),
    erc4626: normalizeList(source.erc4626, chainId),
    seigniorageDetfs: normalizeList(source.seigniorageDetfs, chainId),
    protocolDetf: normalizeList(source.protocolDetf, chainId),
    strategyVaults: normalizeList(source.strategyVaults, chainId),
    uniV2Pools: normalizeList(source.uniV2Pools, chainId),
    aerodromePools: normalizeList(source.aerodromePools, chainId),
    aerodromeStrategyVaults: normalizeList(source.aerodromeStrategyVaults, chainId),
    balancerPools: normalizeList(source.balancerPools, chainId),
  },
})

export const ARTIFACT_REGISTRY: Record<DeploymentEnvironment, Partial<Record<CanonicalArtifactChainId, ArtifactBundle>>> = {
  sepolia: {
    [CHAIN_ID_SEPOLIA]: buildBundle('sepolia', CHAIN_ID_SEPOLIA, 'ethereum', {
      platform: sepoliaPlatformJson,
      factories: sepoliaFactoriesJson,
      tokens: sepoliaTokensJson,
      erc4626: sepoliaErc4626Json,
      seigniorageDetfs: sepoliaSeigniorageDetfsJson,
      protocolDetf: sepoliaProtocolDetfJson,
      strategyVaults: sepoliaStrategyVaultsJson,
      uniV2Pools: sepoliaUniV2PoolsJson,
      aerodromePools: sepoliaAerodromePoolsJson,
      aerodromeStrategyVaults: sepoliaAerodromeStrategyVaultsJson,
      balancerPools: sepoliaBalancerPoolsJson,
    }),
  },
  public_sepolia: {
    [CHAIN_ID_SEPOLIA]: buildBundle('public_sepolia', CHAIN_ID_SEPOLIA, 'ethereum', {
      platform: publicSepoliaEthereumPlatformJson,
      tokens: publicSepoliaEthereumTokensJson,
      erc4626: publicSepoliaEthereumErc4626Json,
      seigniorageDetfs: publicSepoliaEthereumSeigniorageDetfsJson,
      protocolDetf: publicSepoliaEthereumProtocolDetfJson,
      strategyVaults: publicSepoliaEthereumStrategyVaultsJson,
      uniV2Pools: publicSepoliaEthereumUniV2PoolsJson,
      aerodromePools: publicSepoliaEthereumAerodromePoolsJson,
      aerodromeStrategyVaults: publicSepoliaEthereumAerodromeStrategyVaultsJson,
      balancerPools: publicSepoliaEthereumBalancerPoolsJson,
    }),
    [CHAIN_ID_BASE_SEPOLIA]: buildBundle('public_sepolia', CHAIN_ID_BASE_SEPOLIA, 'base', {
      platform: publicSepoliaBasePlatformJson,
      tokens: publicSepoliaBaseTokensJson,
      erc4626: publicSepoliaBaseErc4626Json,
      seigniorageDetfs: publicSepoliaBaseSeigniorageDetfsJson,
      protocolDetf: publicSepoliaBaseProtocolDetfJson,
      strategyVaults: publicSepoliaBaseStrategyVaultsJson,
      uniV2Pools: publicSepoliaBaseUniV2PoolsJson,
      aerodromePools: publicSepoliaBaseAerodromePoolsJson,
      aerodromeStrategyVaults: publicSepoliaBaseAerodromeStrategyVaultsJson,
      balancerPools: publicSepoliaBaseBalancerPoolsJson,
    }),
  },
  supersim_sepolia: {
    [CHAIN_ID_SEPOLIA]: buildBundle('supersim_sepolia', CHAIN_ID_SEPOLIA, 'ethereum', {
      platform: supersimEthereumPlatformJson,
      factories: supersimEthereumFactoriesJson,
      tokens: supersimEthereumTokensJson,
      erc4626: supersimEthereumErc4626Json,
      seigniorageDetfs: supersimEthereumSeigniorageDetfsJson,
      protocolDetf: supersimEthereumProtocolDetfJson,
      strategyVaults: supersimEthereumStrategyVaultsJson,
      uniV2Pools: supersimEthereumUniV2PoolsJson,
      aerodromePools: supersimEthereumAerodromePoolsJson,
      aerodromeStrategyVaults: supersimEthereumAerodromeStrategyVaultsJson,
      balancerPools: supersimEthereumBalancerPoolsJson,
    }),
    [CHAIN_ID_BASE_SEPOLIA]: buildBundle('supersim_sepolia', CHAIN_ID_BASE_SEPOLIA, 'base', {
      platform: supersimBasePlatformJson,
      tokens: supersimBaseTokensJson,
      erc4626: supersimBaseErc4626Json,
      seigniorageDetfs: supersimBaseSeigniorageDetfsJson,
      protocolDetf: supersimBaseProtocolDetfJson,
      strategyVaults: supersimBaseStrategyVaultsJson,
      uniV2Pools: supersimBaseUniV2PoolsJson,
      aerodromePools: supersimBaseAerodromePoolsJson,
      aerodromeStrategyVaults: supersimBaseAerodromeStrategyVaultsJson,
      balancerPools: supersimBaseBalancerPoolsJson,
    }),
  },
}

export const DEPLOYMENT_ENVIRONMENTS: DeploymentEnvironment[] = ['sepolia', 'public_sepolia', 'supersim_sepolia']

export function getArtifactBundle(
  environment: DeploymentEnvironment,
  chainId: CanonicalArtifactChainId
): ArtifactBundle | null {
  return ARTIFACT_REGISTRY[environment][chainId] ?? null
}
