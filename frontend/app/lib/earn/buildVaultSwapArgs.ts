/**
 * ExactIn router args for pure strategy-vault deposit / withdraw.
 *
 * Mirrors Swap route branches (swap/page.tsx + routeMatcher):
 *   Strategy Vault Deposit:
 *     pool = vault, tokenInVault = vault, tokenOut = vault shares, tokenOutVault = 0
 *   Strategy Vault Withdrawal:
 *     pool = vault, tokenIn = vault shares, tokenInVault = 0, tokenOutVault = vault
 */

export type Address = `0x${string}`

export const ZERO_ADDR = '0x0000000000000000000000000000000000000000' as Address

export type VaultSwapExactInArgs = readonly [
  pool: Address,
  tokenIn: Address,
  tokenInVault: Address,
  tokenOut: Address,
  tokenOutVault: Address,
  exactAmountIn: bigint,
  minAmountOut: bigint,
  deadline: bigint,
  wethIsEth: boolean,
  userData: `0x${string}`,
]

export function buildStrategyVaultDepositArgs(input: {
  vault: Address
  /** Underlying asset deposited into the vault. */
  tokenIn: Address
  amountIn: bigint
  minAmountOut?: bigint
  deadline: bigint
  wethIsEth?: boolean
  userData?: `0x${string}`
}): VaultSwapExactInArgs {
  const vault = input.vault
  return [
    vault,
    input.tokenIn,
    vault, // tokenInVault — Strategy Vault Deposit requires vault, not zero
    vault, // tokenOut = vault share token
    ZERO_ADDR,
    input.amountIn,
    input.minAmountOut ?? BigInt(0),
    input.deadline,
    input.wethIsEth ?? false,
    input.userData ?? '0x',
  ] as const
}

export function buildStrategyVaultWithdrawArgs(input: {
  vault: Address
  /** Underlying asset received on withdraw. */
  tokenOut: Address
  amountIn: bigint
  minAmountOut?: bigint
  deadline: bigint
  wethIsEth?: boolean
  userData?: `0x${string}`
}): VaultSwapExactInArgs {
  const vault = input.vault
  return [
    vault,
    vault, // tokenIn = vault share token
    ZERO_ADDR,
    input.tokenOut,
    vault, // tokenOutVault — Strategy Vault Withdrawal requires vault, not zero
    input.amountIn,
    input.minAmountOut ?? BigInt(0),
    input.deadline,
    input.wethIsEth ?? false,
    input.userData ?? '0x',
  ] as const
}
