import { describe, expect, it, vi } from 'vitest'
import { zeroAddress } from 'viem'

import { entriesFromAddresses, loadDetfsOfPackage, loadRegisteredVaults, selectDetfsFromVaults } from './discoverDetfs'

const REG = '0x1111111111111111111111111111111111111111' as const
const PKG = '0x2222222222222222222222222222222222222222' as const
const VAULT = '0x3333333333333333333333333333333333333333' as const
const SE = '0x4444444444444444444444444444444444444444' as const
const NFT = '0x5555555555555555555555555555555555555555' as const

describe('loadDetfsOfPackage', () => {
  it('returns registered vaults', async () => {
    const readContract = vi.fn().mockResolvedValue([VAULT, VAULT])
    await expect(loadDetfsOfPackage({ readContract } as never, REG, PKG)).resolves.toEqual([VAULT])
  })

  it('returns [] on FunctionNotFound', async () => {
    const readContract = vi.fn().mockRejectedValue(new Error('reverted 0x23dbef4b'))
    await expect(loadDetfsOfPackage({ readContract } as never, REG, PKG)).resolves.toEqual([])
  })
})

describe('loadRegisteredVaults', () => {
  it('returns the registry vault list', async () => {
    const readContract = vi.fn().mockResolvedValue([VAULT, SE])
    await expect(loadRegisteredVaults({ readContract } as never, REG)).resolves.toEqual([VAULT, SE])
    expect(readContract.mock.calls[0][0].functionName).toBe('vaults')
  })
})

describe('selectDetfsFromVaults', () => {
  it('keeps diamonds that expose a bond NFT vault', async () => {
    const readContract = vi.fn().mockImplementation(async ({ address, functionName }: { address: string; functionName: string }) => {
      if (functionName === 'bondNftVault' && address === VAULT) return NFT
      if (functionName === 'bondNftVault') throw new Error('reverted 0x23dbef4b')
      if (functionName === 'protocolNFTVault') return zeroAddress
      throw new Error(functionName)
    })
    await expect(selectDetfsFromVaults({ readContract } as never, [VAULT, SE])).resolves.toEqual([VAULT])
  })
})

describe('entriesFromAddresses', () => {
  it('reads ERC-20 metadata', async () => {
    const readContract = vi.fn().mockImplementation(async ({ functionName }: { functionName: string }) => {
      if (functionName === 'name') return 'My DETF'
      if (functionName === 'symbol') return 'MINE'
      if (functionName === 'decimals') return 18
      throw new Error(functionName)
    })
    const [row] = await entriesFromAddresses({ readContract } as never, 46630, [VAULT])
    expect(row).toMatchObject({ address: VAULT, name: 'My DETF', symbol: 'MINE', decimals: 18 })
  })
})
