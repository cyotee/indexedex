import { describe, expect, it } from 'vitest'
import { parseContractError } from './parseContractError'
import { ContractFunctionRevertedError } from 'viem'
import { FUNDED_BOND_ABI } from '../detf/bondRoute'

describe('parseContractError', () => {
  it('explains a V4 minimum-output revert nested under a generic wallet simulation error', () => {
    expect(parseContractError({ message: 'Execution reverted for an unknown reason.', cause: {
      data: { originalError: { data: '0x8b063d7300000000000000000000000000000000000000000000000000bb85f640cce4ad000000000000000000000000000000000000000000000000006b145617995c2a' } },
    } })).toMatch(/less than the displayed minimum.*Refresh the quote/)
  })
  it('explains the liquidity limit decoded by viem under a generic bond error', () => {
    const cause = new ContractFunctionRevertedError({ abi: FUNDED_BOND_ABI, data: '0x340a4533', functionName: 'bond' })
    expect(parseContractError(new Error('The contract function "bond" reverted.', { cause })))
      .toMatch(/per-transaction liquidity limit/)
  })

  it('finds MetaMask nested original revert data', () => {
    expect(parseContractError({ message: 'The contract function "bond" reverted.', cause: {
      data: { originalError: { data: '0x340a4533' } },
    } })).toMatch(/per-transaction liquidity limit/)
  })
  it('explains the weighted pool input limit even when RPC renders its selector as text', () => {
    expect(parseContractError({ message: 'execution reverted: 4', cause: { data: '0x340a4533' } }))
      .toMatch(/per-transaction liquidity limit.*smaller amount/)
  })
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
    ).toMatch(/required output/i)
  })

  it('maps InsufficientTokenOut', () => {
    expect(parseContractError({ data: '0x3dec0665', message: 'execution reverted' })).toMatch(
      /required output/i,
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

  it('maps an older deployment maturity error without assuming the funded bond is cliff-locked', () => {
    const message = parseContractError(new Error('BondNotMature(uint256)'))
    expect(message).toMatch(/early principal claim/i)
    expect(message).toMatch(/claimable amounts/i)
    expect(message).not.toMatch(/principal cannot|rewards cannot/i)
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


  it('does not mistake an ABI deadline parameter for an expired transaction', () => {
    expect(parseContractError(new Error('RPC request unavailable\nTransaction: exchangeIn(uint256 deadline)'))).toBe('RPC request unavailable')
    expect(parseContractError({ message: 'Execution reverted', cause: { data: { errorName: 'DeadlineExpired' } } })).toMatch(/deadline expired/i)
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
