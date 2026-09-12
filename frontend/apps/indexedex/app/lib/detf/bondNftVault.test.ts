import { describe, expect, it, vi } from 'vitest'
import { zeroAddress } from 'viem'

import { isFunctionNotFound, readBondNftVault, readBondPosition, readBondClaim, asBondPosition, asBondClaim, requireFundedBondSupport } from './bondNftVault'

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

describe('funded bond views', () => {
  const position = { principal: 100_000_000_000n, claimedPrincipal: 0n, stakingGons: 110_000_000_000_000n, startTimestamp: 1_000n, vestingDuration: 100n }
  const claim = { vestedPrincipal: 50_000_000_000n, principalRemaining: 100_000_000_000n, principalDue: 50_000_000_000n, rewardsDue: 10_000_000_000n }

  it('reads purchased principal and funded reward claims separately', async () => {
    const readContract = vi.fn().mockImplementation(async ({ functionName }: { functionName: string }) => functionName === 'positionOf' ? position : claim)
    await expect(readBondPosition({ readContract } as never, VAULT, 3n)).resolves.toEqual(position)
    await expect(readBondClaim({ readContract } as never, VAULT, 3n)).resolves.toEqual(claim)
    expect(readContract.mock.calls.map(([args]) => args.functionName)).toEqual(['positionOf', 'previewClaim'])
  })

  it('does not fall back to old LP-valued getters', async () => {
    const readContract = vi.fn().mockRejectedValue(fnNotFound('positionOf'))
    await expect(readBondPosition({ readContract } as never, VAULT, 3n)).resolves.toBeNull()
    expect(readContract).toHaveBeenCalledTimes(1)
  })

  it('requires funded preview support to distinguish the reused positionOf selector', async () => {
    const readContract = vi.fn().mockRejectedValue(fnNotFound('previewClaim'))
    await expect(readBondClaim({ readContract } as never, VAULT, 3n)).resolves.toBeNull()
  })

  it('rejects incomplete, negative, inconsistent and old position shapes', () => {
    expect(asBondPosition({ originalShares: 100n, effectiveShares: 120n })).toBeNull()
    expect(asBondPosition({ ...position, claimedPrincipal: position.principal + 1n })).toBeNull()
    expect(asBondPosition({ ...position, stakingGons: -1n })).toBeNull()
    expect(asBondClaim({ ...claim, principalDue: claim.principalRemaining + 1n })).toBeNull()
    expect(asBondClaim({ ...claim, rewardsDue: undefined })).toBeNull()
  })

  it('retains zero-valued standing roles without inventing principal', () => {
    expect(asBondPosition({ principal: 0n, claimedPrincipal: 0n, stakingGons: 0n, startTimestamp: 0n, vestingDuration: 0n })).not.toBeNull()
    expect(asBondClaim({ vestedPrincipal: 0n, principalRemaining: 0n, principalDue: 0n, rewardsDue: 0n })).not.toBeNull()
  })

  it('propagates genuine errors instead of trying another getter', async () => {
    const readContract = vi.fn().mockRejectedValue(new Error('RPC unavailable'))
    await expect(readBondClaim({ readContract } as never, VAULT, 3n)).rejects.toThrow('RPC unavailable')
  })
})


describe('funded bond purchase preflight', () => {
  it('requires the new funded claim view even when the old purchase selector exists', async () => {
    const readContract = vi.fn().mockImplementation(async ({ functionName }: { functionName: string }) => {
      if (functionName === 'bondNftVault') return VAULT
      throw fnNotFound(functionName)
    })
    await expect(requireFundedBondSupport({ readContract } as never, DETF)).rejects.toThrow('funded staking bonds')
    expect(readContract.mock.calls.map(([args]) => args.functionName)).toEqual(['bondNftVault', 'previewClaim'])
  })

  it('identifies funded support before any purchased NFT exists using the protocol role', async () => {
    const readContract = vi.fn().mockImplementation(async ({ functionName }: { functionName: string }) =>
      functionName === 'bondNftVault' ? VAULT : { vestedPrincipal: 0n, principalRemaining: 0n, principalDue: 0n, rewardsDue: 0n })
    await expect(requireFundedBondSupport({ readContract } as never, DETF)).resolves.toBe(VAULT)
    expect(readContract.mock.calls[1][0].args).toEqual([0n])
  })
})
