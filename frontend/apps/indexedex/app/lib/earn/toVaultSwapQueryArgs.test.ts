import { describe, expect, it } from 'vitest'
import { ZERO_ADDR } from './buildVaultSwapArgs'
import {
  isQueryEightTuple,
  toVaultDepositQueryArgs,
  toVaultWithdrawQueryArgs,
} from './toVaultSwapQueryArgs'

const VAULT = '0x1111111111111111111111111111111111111111' as const
const UNDERLYING = '0x2222222222222222222222222222222222222222' as const
const AMOUNT = BigInt(1000)

describe('toVaultDepositQueryArgs', () => {
  it('is 8-tuple with ZERO_ADDR sender (not execute 10-tuple)', () => {
    const args = toVaultDepositQueryArgs({
      vault: VAULT,
      tokenIn: UNDERLYING,
      amountIn: AMOUNT,
    })
    expect(args).toHaveLength(8)
    expect(isQueryEightTuple(args)).toBe(true)
    // pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, amount, sender, userData
    expect(args[0]).toBe(VAULT)
    expect(args[1]).toBe(UNDERLYING)
    expect(args[2]).toBe(VAULT)
    expect(args[3]).toBe(VAULT)
    expect(args[4]).toBe(ZERO_ADDR)
    expect(args[5]).toBe(AMOUNT)
    expect(args[6]).toBe(ZERO_ADDR)
    expect(args[7]).toBe('0x')
    // Must NOT look like execute (no minOut/deadline/weth in positions 6–8)
    expect(typeof args[6]).toBe('string') // sender address, not minOut bigint
  })

  it('does not embed minOut or deadline (query arity)', () => {
    const args = toVaultDepositQueryArgs({
      vault: VAULT,
      tokenIn: UNDERLYING,
      amountIn: AMOUNT,
    })
    // Execute would have bigint at index 6 (minOut); query has address
    expect(args[6]).toMatch(/^0x/)
    expect(args).toHaveLength(8)
  })
})

describe('toVaultWithdrawQueryArgs', () => {
  it('is 8-tuple strategy withdraw shape', () => {
    const args = toVaultWithdrawQueryArgs({
      vault: VAULT,
      tokenOut: UNDERLYING,
      amountIn: AMOUNT,
    })
    expect(args).toHaveLength(8)
    expect(args[1]).toBe(VAULT)
    expect(args[2]).toBe(ZERO_ADDR)
    expect(args[3]).toBe(UNDERLYING)
    expect(args[4]).toBe(VAULT)
    expect(args[6]).toBe(ZERO_ADDR)
  })
})
