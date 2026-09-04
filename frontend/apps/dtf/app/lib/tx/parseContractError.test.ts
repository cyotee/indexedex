import { describe, expect, it } from 'vitest'
import { parseContractError } from './parseContractError'

describe('parseContractError', () => {
  it('maps Provider not found', () => {
    const err = new Error('Provider not found.')
    err.name = 'ProviderNotFoundError'
    expect(parseContractError(err)).toMatch(/No browser wallet found/)
  })

  it('maps user rejection (code 4001)', () => {
    expect(parseContractError({ code: 4001, message: 'User rejected the request' })).toBe(
      'Transaction rejected in wallet',
    )
  })

  it('maps user rejected message without code', () => {
    expect(parseContractError(new Error('User denied transaction signature'))).toMatch(
      /rejected/i,
    )
  })

  it('maps ACTION_REJECTED', () => {
    expect(parseContractError({ code: 'ACTION_REJECTED', message: 'denied' })).toBe(
      'Transaction rejected in wallet',
    )
  })

  it('maps insufficient funds', () => {
    expect(parseContractError(new Error('insufficient funds for gas'))).toMatch(/balance/i)
  })

  it('does not treat a revert selector as missing ETH', () => {
    expect(
      parseContractError({
        message: 'insufficient funds for gas',
        data: '0x3dec0665',
      }),
    ).toMatch(/pair-side book/i)
  })

  it('maps InsufficientTokenOut', () => {
    expect(parseContractError({ data: '0x3dec0665', message: 'execution reverted' })).toMatch(
      /could not add that token/i,
    )
  })

  it('maps TransferFromFailed', () => {
    expect(parseContractError({ data: '0x7939f424', message: 'execution reverted' })).toMatch(
      /approve/i,
    )
  })

  it('maps bond claim authorization errors', () => {
    expect(parseContractError(new Error('NotBondHolder()'))).toMatch(/does not own that bond/i)
    expect(parseContractError(new Error('NotAuthorized(address)'))).toMatch(/does not own that bond/i)
  })

  it('maps BondNotMature without blocking reward claims in copy', () => {
    expect(parseContractError(new Error('BondNotMature(uint256)'))).toMatch(/still locked/i)
  })

  it('maps an already-initialized pool', () => {
    expect(parseContractError(new Error('PoolAlreadyInitialized()'))).toMatch(/already exists/i)
    expect(parseContractError({ data: '0x7983c051', message: 'execution reverted' })).toMatch(/already exists/i)
  })

  it('keeps a long factory error instead of the generic fallback', () => {
    const msg =
      'The connected wallet has no vault factory at this address. The app sees it on a different node. Point the wallet at the same RPC as the app, then try again.'
    expect(parseContractError(new Error(msg))).toBe(msg)
  })

  it('maps MetaMask interaction-failed simulation', () => {
    expect(parseContractError(new Error('MetaMask - Interaction Failed'))).toMatch(/simulate/i)
    expect(parseContractError({ shortMessage: 'Internal JSON-RPC error.' })).toMatch(/simulate/i)
  })


  it('returns safe fallback for unknown errors', () => {
    const msg = parseContractError({ weird: true })
    expect(msg.length).toBeGreaterThan(0)
    expect(msg).not.toMatch(/^0x[a-f0-9]{8}$/i)
  })

  it('prefers shortMessage when present', () => {
    expect(
      parseContractError({
        shortMessage: 'Execution reverted',
        message: 'long stack…',
      }),
    ).toBe('Execution reverted')
  })

  it('handles null/undefined safely', () => {
    expect(parseContractError(null)).toMatch(/failed|try again/i)
    expect(parseContractError(undefined)).toMatch(/failed|try again/i)
  })
})
