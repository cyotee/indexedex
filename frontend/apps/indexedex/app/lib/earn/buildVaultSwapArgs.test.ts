import { describe, expect, it } from 'vitest'
import {
  ZERO_ADDR,
  buildStrategyVaultDepositArgs,
  buildStrategyVaultWithdrawArgs,
} from './buildVaultSwapArgs'

const VAULT = '0x1111111111111111111111111111111111111111' as const
const UNDERLYING = '0x2222222222222222222222222222222222222222' as const
const AMOUNT = BigInt(1000)
const DEADLINE = BigInt(1_700_000_000)

describe('buildStrategyVaultDepositArgs', () => {
  it('matches Strategy Vault Deposit: tokenInVault=vault, tokenOut=vault shares, tokenOutVault=0', () => {
    const args = buildStrategyVaultDepositArgs({
      vault: VAULT,
      tokenIn: UNDERLYING,
      amountIn: AMOUNT,
      deadline: DEADLINE,
    })

    // [pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, amount, minOut, deadline, wethIsEth, userData]
    expect(args[0]).toBe(VAULT)
    expect(args[1]).toBe(UNDERLYING)
    expect(args[2]).toBe(VAULT)
    expect(args[3]).toBe(VAULT)
    expect(args[4]).toBe(ZERO_ADDR)
    expect(args[5]).toBe(AMOUNT)
    expect(args[6]).toBe(BigInt(0))
    expect(args[7]).toBe(DEADLINE)
    expect(args[8]).toBe(false)
    expect(args[9]).toBe('0x')
  })

  it('does not zero tokenInVault (wrong path that InvalidRoute-reverts)', () => {
    const args = buildStrategyVaultDepositArgs({
      vault: VAULT,
      tokenIn: UNDERLYING,
      amountIn: AMOUNT,
      deadline: DEADLINE,
    })
    expect(args[2]).not.toBe(ZERO_ADDR)
    expect(args[2].toLowerCase()).toBe(VAULT.toLowerCase())
  })
})

describe('buildStrategyVaultWithdrawArgs', () => {
  it('matches Strategy Vault Withdrawal: tokenIn=vault shares, tokenOutVault=vault, tokenInVault=0', () => {
    const args = buildStrategyVaultWithdrawArgs({
      vault: VAULT,
      tokenOut: UNDERLYING,
      amountIn: AMOUNT,
      minAmountOut: BigInt(1),
      deadline: DEADLINE,
    })

    expect(args[0]).toBe(VAULT)
    expect(args[1]).toBe(VAULT)
    expect(args[2]).toBe(ZERO_ADDR)
    expect(args[3]).toBe(UNDERLYING)
    expect(args[4]).toBe(VAULT)
    expect(args[5]).toBe(AMOUNT)
    expect(args[6]).toBe(BigInt(1))
    expect(args[7]).toBe(DEADLINE)
  })

  it('does not zero tokenOutVault (wrong path that InvalidRoute-reverts)', () => {
    const args = buildStrategyVaultWithdrawArgs({
      vault: VAULT,
      tokenOut: UNDERLYING,
      amountIn: AMOUNT,
      deadline: DEADLINE,
    })
    expect(args[4]).not.toBe(ZERO_ADDR)
    expect(args[4].toLowerCase()).toBe(VAULT.toLowerCase())
  })
})
