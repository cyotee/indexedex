import {
  getAddressArtifacts,
  getDefaultDeploymentEnvironment,
  type DeploymentEnvironment,
} from '../addressArtifacts'

export type Address = `0x${string}`

function isAddress(value: unknown): value is Address {
  return typeof value === 'string' && /^0x[0-9a-fA-F]{40}$/.test(value)
}

/**
 * Vault registry is the IndexedexManager diamond (vault query facets live there).
 * Prefer platform.vaultRegistry, fall back to indexedexManager.
 */
export function getVaultRegistryAddress(
  chainId: number,
  environment: DeploymentEnvironment = getDefaultDeploymentEnvironment(),
): Address | null {
  try {
    const platform = getAddressArtifacts(chainId, environment).platform as Record<string, unknown>
    const reg = platform.vaultRegistry
    if (isAddress(reg) && reg.toLowerCase() !== '0x0000000000000000000000000000000000000000') {
      return reg
    }
    const manager = platform.indexedexManager
    if (isAddress(manager) && manager.toLowerCase() !== '0x0000000000000000000000000000000000000000') {
      return manager
    }
  } catch {
    return null
  }
  return null
}
