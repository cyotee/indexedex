import { describe, expect, it, vi } from 'vitest'
import { zeroAddress } from 'viem'

import { isFunctionNotFound, readBondNftVault, readBondPosition, readDetfNftId } from './bondNftVault'

const DETF = '0x1111111111111111111111111111111111111111' as const
const VAULT = '0x2222222222222222222222222222222222222222' as const

function fnNotFound(name: string) {
  return new Error(
    `The contract function "${name}" reverted with the following signature: 0x23dbef4b Unable to decode signature "0x23dbef4b"`,
  )
}

describe('isFunctionNotFound', () => {
  it('matches diamond FunctionNotFound selector 0x23dbef4b', () => {
    expect(isFunctionNotFound(fnNotFound('protocolNFTVault'))).toBe(true)
    expect(isFunctionNotFound(new Error('oops'))).toBe(false)
  })
})

describe('readBondNftVault', () => {
  it('uses bondNftVault when present', async () => {
    const readContract = vi.fn().mockResolvedValue(VAULT)
    await expect(readBondNftVault({ readContract } as never, DETF)).resolves.toBe(VAULT)
    expect(readContract).toHaveBeenCalledTimes(1)
    expect(readContract.mock.calls[0][0].functionName).toBe('bondNftVault')
  })

  it('falls back to protocolNFTVault after FunctionNotFound', async () => {
    const readContract = vi.fn().mockImplementation(async ({ functionName }: { functionName: string }) => {
      if (functionName === 'bondNftVault') throw fnNotFound(functionName)
      return VAULT
    })
    await expect(readBondNftVault({ readContract } as never, DETF)).resolves.toBe(VAULT)
  })

  it('returns null when both getters are missing', async () => {
    const readContract = vi.fn().mockRejectedValue(fnNotFound('protocolNFTVault'))
    await expect(readBondNftVault({ readContract } as never, DETF)).resolves.toBeNull()
  })

  it('skips the zero address', async () => {
    const readContract = vi.fn().mockResolvedValue(zeroAddress)
    await expect(readBondNftVault({ readContract } as never, DETF)).resolves.toBeNull()
  })

  it('rethrows real reverts', async () => {
    const readContract = vi.fn().mockRejectedValue(new Error('execution reverted'))
    await expect(readBondNftVault({ readContract } as never, DETF)).rejects.toThrow('execution reverted')
  })
})

describe('readDetfNftId', () => {
  it('prefers detfNFTId', async () => {
    const readContract = vi.fn().mockResolvedValue(1n)
    await expect(readDetfNftId({ readContract } as never, VAULT)).resolves.toBe(1n)
    expect(readContract.mock.calls[0][0].functionName).toBe('detfNFTId')
  })

  it('falls back to protocolNFTId', async () => {
    const readContract = vi.fn().mockImplementation(async ({ functionName }: { functionName: string }) => {
      if (functionName === 'detfNFTId') throw fnNotFound(functionName)
      return 7n
    })
    await expect(readDetfNftId({ readContract } as never, VAULT)).resolves.toBe(7n)
  })
})

describe('readBondPosition', () => {
  const sample = {
    originalShares: 10n,
    effectiveShares: 12n,
    bonusMultiplier: 1n,
    unlockTime: 99n,
    rewardDebt: 3n,
  }

  it('uses getPosition when present', async () => {
    const readContract = vi.fn().mockResolvedValue(sample)
    await expect(readBondPosition({ readContract } as never, VAULT, 2n)).resolves.toEqual(sample)
  })

  it('falls back to positionOf', async () => {
    const readContract = vi.fn().mockImplementation(async ({ functionName }: { functionName: string }) => {
      if (functionName === 'getPosition') throw fnNotFound(functionName)
      return sample
    })
    await expect(readBondPosition({ readContract } as never, VAULT, 2n)).resolves.toEqual(sample)
  })
})
