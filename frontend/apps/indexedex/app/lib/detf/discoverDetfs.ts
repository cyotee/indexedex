import { erc20Abi, type Address, type PublicClient } from 'viem'

import { vaultRegistryQueryAbi } from '@indexedex/protocol/registry/vaultRegistryAbi'
import type { TokenListEntry } from '@indexedex/protocol/tokenlists'

import { isFunctionNotFound, readBondNftVault } from './bondNftVault'
import { entryFromAddress } from './createdDetfs'

type ReadClient = Pick<PublicClient, 'readContract'>

const REGISTRY_VAULT_CAP = 128

function uniqueAddresses(addresses: Address[], cap: number): Address[] {
  const seen = new Set<string>()
  const out: Address[] = []
  for (const vault of addresses) {
    const key = vault.toLowerCase()
    if (seen.has(key)) continue
    seen.add(key)
    out.push(vault)
    if (out.length >= cap) break
  }
  return out
}

export async function loadRegisteredVaults(
  client: ReadClient,
  registry: Address,
): Promise<Address[]> {
  try {
    const vaults = (await client.readContract({
      address: registry,
      abi: vaultRegistryQueryAbi,
      functionName: 'vaults',
      args: [],
    })) as Address[]
    return uniqueAddresses(vaults, REGISTRY_VAULT_CAP)
  } catch (error) {
    if (isFunctionNotFound(error)) return []
    throw error
  }
}

export async function loadDetfsOfPackage(
  client: ReadClient,
  registry: Address,
  pkg: Address,
): Promise<Address[]> {
  try {
    const vaults = (await client.readContract({
      address: registry,
      abi: vaultRegistryQueryAbi,
      functionName: 'vaultsOfPackage',
      args: [pkg],
    })) as Address[]
    return uniqueAddresses(vaults, REGISTRY_VAULT_CAP)
  } catch (error) {
    if (isFunctionNotFound(error)) return []
    throw error
  }
}

/** Keep diamonds that expose a bond NFT vault. Drops SE vaults and the NFT vaults themselves. */
export async function selectDetfsFromVaults(client: ReadClient, vaults: Address[]): Promise<Address[]> {
  const rows = await Promise.all(
    vaults.map(async (vault) => {
      try {
        const nftVault = await readBondNftVault(client, vault)
        return nftVault ? vault : null
      } catch {
        return null
      }
    }),
  )
  return rows.filter((row): row is Address => row !== null)
}

export async function entriesFromAddresses(
  client: ReadClient,
  chainId: number,
  addresses: Address[],
): Promise<TokenListEntry[]> {
  const rows = await Promise.all(
    addresses.map(async (address) => {
      try {
        const [name, symbol, decimals] = await Promise.all([
          client.readContract({ address, abi: erc20Abi, functionName: 'name' }) as Promise<string>,
          client.readContract({ address, abi: erc20Abi, functionName: 'symbol' }) as Promise<string>,
          client.readContract({ address, abi: erc20Abi, functionName: 'decimals' }) as Promise<number>,
        ])
        return {
          chainId,
          address,
          name: name?.trim() || 'DETF',
          symbol: symbol?.trim() || 'DETF',
          decimals: typeof decimals === 'number' ? decimals : 18,
          tags: ['vault', 'detf'],
        } satisfies TokenListEntry
      } catch {
        return entryFromAddress(chainId, address)
      }
    }),
  )
  return rows
}
