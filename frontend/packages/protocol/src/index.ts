/**
 * @indexedex/protocol — shared addresses, ABIs, chains, registry, swap helpers.
 *
 * Prefer subpath imports for unambiguous symbols, e.g.:
 *   import { getAddressArtifacts } from '@indexedex/protocol/addressArtifacts'
 *   import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'
 */
export const PROTOCOL_PACKAGE = true as const
export const PROTOCOL_PACKAGE_NAME = '@indexedex/protocol' as const

export {
  CHAIN_ID_SEPOLIA,
  CHAIN_ID_BASE_SEPOLIA,
  CHAIN_ID_ANVIL,
  CHAIN_ID_LOCALHOST,
  CHAIN_ID_BASE,
  getAddressArtifacts,
  getArtifactBundle,
  resolveArtifactsChainId,
  isSupportedChainId,
  setDefaultDeploymentEnvironment,
  getDefaultDeploymentEnvironment,
} from './addressArtifacts'

export type {
  ArtifactBundle,
  CanonicalArtifactChainId,
  DeploymentEnvironment,
} from './addressArtifacts'

export { resolveAppChain } from './runtimeChains'
export { hasBytecode, isZeroAddress, ZERO_ADDR } from './onchain'
