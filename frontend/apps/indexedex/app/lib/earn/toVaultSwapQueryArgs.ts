/**
 * Query 8-tuple for querySwapSingleTokenExactIn (NOT execute 10-tuple).
 *
 * Query:  [pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, exactAmountIn, sender, userData]
 * Execute: [pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, exactAmountIn, minAmountOut, deadline, wethIsEth, userData]
 *
 * Never spread execute args into query. Always use sender = ZERO_ADDR for static sim.
 */

import { ZERO_ADDR, type Address } from './buildVaultSwapArgs'

export type VaultSwapQueryArgs = readonly [
  pool: Address,
  tokenIn: Address,
  tokenInVault: Address,
  tokenOut: Address,
  tokenOutVault: Address,
  exactAmountIn: bigint,
  sender: Address,
  userData: `0x${string}`,
]

/** Minimal ABI fragment for simulateContract querySwapSingleTokenExactIn */
export const querySwapExactInAbi = [
  {
    type: 'function',
    name: 'querySwapSingleTokenExactIn',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'pool', type: 'address' },
      { name: 'tokenIn', type: 'address' },
      { name: 'tokenInVault', type: 'address' },
      { name: 'tokenOut', type: 'address' },
      { name: 'tokenOutVault', type: 'address' },
      { name: 'exactAmountIn', type: 'uint256' },
      { name: 'sender', type: 'address' },
      { name: 'userData', type: 'bytes' },
    ],
    outputs: [{ name: 'amountOut', type: 'uint256' }],
  },
] as const

export function toVaultDepositQueryArgs(input: {
  vault: Address
  tokenIn: Address
  amountIn: bigint
  userData?: `0x${string}`
}): VaultSwapQueryArgs {
  const vault = input.vault
  return [
    vault,
    input.tokenIn,
    vault, // tokenInVault — Strategy Vault Deposit
    vault, // tokenOut = vault shares
    ZERO_ADDR,
    input.amountIn,
    ZERO_ADDR, // sender for query sim
    input.userData ?? '0x',
  ] as const
}

export function toVaultWithdrawQueryArgs(input: {
  vault: Address
  tokenOut: Address
  amountIn: bigint
  userData?: `0x${string}`
}): VaultSwapQueryArgs {
  const vault = input.vault
  return [
    vault,
    vault, // tokenIn = vault shares
    ZERO_ADDR,
    input.tokenOut,
    vault, // tokenOutVault — Strategy Vault Withdrawal
    input.amountIn,
    ZERO_ADDR,
    input.userData ?? '0x',
  ] as const
}

/** Assert shape is 8-tuple query, not 10-tuple execute. */
export function isQueryEightTuple(args: readonly unknown[]): args is VaultSwapQueryArgs {
  return (
    args.length === 8 &&
    typeof args[0] === 'string' &&
    typeof args[5] === 'bigint' &&
    typeof args[6] === 'string' &&
    typeof args[7] === 'string'
  )
}
