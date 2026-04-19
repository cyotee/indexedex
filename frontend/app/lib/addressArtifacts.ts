import {
  CHAIN_ID_BASE_SEPOLIA,
  CHAIN_ID_SEPOLIA,
  getArtifactBundle,
  type ArtifactBundle,
  type CanonicalArtifactChainId,
  type DeploymentEnvironment,
} from '../addresses'

export {
  CHAIN_ID_BASE_SEPOLIA,
  CHAIN_ID_SEPOLIA,
  getArtifactBundle,
  type ArtifactBundle,
  type CanonicalArtifactChainId,
  type DeploymentEnvironment,
}

export const CHAIN_ID_ANVIL = 31337
export const CHAIN_ID_LOCALHOST = 1337
export const CHAIN_ID_BASE = 8453

function isLocalSepoliaEnvironment(environment: DeploymentEnvironment): boolean {
  return environment === 'supersim_sepolia'
}

let defaultDeploymentEnvironment: DeploymentEnvironment =
  (process.env.NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT as DeploymentEnvironment | undefined) ?? 'supersim_sepolia'

export type AddressArtifacts = ArtifactBundle

export function setDefaultDeploymentEnvironment(environment: DeploymentEnvironment) {
  defaultDeploymentEnvironment = environment
}

export function getDefaultDeploymentEnvironment(): DeploymentEnvironment {
  return defaultDeploymentEnvironment
}

export function resolveArtifactsChainId(
  chainId: number,
  environment: DeploymentEnvironment = defaultDeploymentEnvironment,
  preferredCanonicalChainId?: CanonicalArtifactChainId
): CanonicalArtifactChainId | null {
  if (chainId === CHAIN_ID_SEPOLIA) return CHAIN_ID_SEPOLIA
  if (chainId === CHAIN_ID_BASE_SEPOLIA) return CHAIN_ID_BASE_SEPOLIA

  if (chainId === CHAIN_ID_ANVIL || chainId === CHAIN_ID_LOCALHOST) {
    return preferredCanonicalChainId ?? CHAIN_ID_SEPOLIA
  }

  if (chainId === CHAIN_ID_BASE && isLocalSepoliaEnvironment(environment)) {
    return CHAIN_ID_BASE_SEPOLIA
  }

  return null
}

export function isSupportedChainId(chainId: number, environment: DeploymentEnvironment = defaultDeploymentEnvironment): boolean {
  const resolved = resolveArtifactsChainId(chainId, environment)
  if (resolved === null) return false
  return getArtifactBundle(environment, resolved) !== null
}

export function getAddressArtifacts(
  chainId: number,
  environment: DeploymentEnvironment = defaultDeploymentEnvironment
): AddressArtifacts {
  const resolved = resolveArtifactsChainId(chainId, environment)
  if (resolved === null) {
    throw new Error(
      `Unsupported chainId ${chainId}. Supported chains resolve to ${CHAIN_ID_SEPOLIA} (Ethereum Sepolia) or ${CHAIN_ID_BASE_SEPOLIA} (Base Sepolia) for environment ${environment}.`
    )
  }

  const bundle = getArtifactBundle(environment, resolved)
  if (!bundle) {
    throw new Error(`No deployment bundle is registered for environment ${environment} on chain ${resolved}.`)
  }

  return bundle
}
