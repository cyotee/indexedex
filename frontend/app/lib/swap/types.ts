// Shared types and constants for the swap module

export const ZERO_ADDR = '0x0000000000000000000000000000000000000000' as `0x${string}`

export const MAX_UINT160 = (BigInt(1) << BigInt(160)) - BigInt(1)

export type PoolType = 'balancer' | 'vault' | undefined

export type BuildArgsInput = {
  poolType: PoolType
  poolAddress: `0x${string}` | null
  tokenInAddress: `0x${string}` | null
  tokenOutAddress: `0x${string}` | null
  tokenInVaultAddress: `0x${string}`
  tokenOutVaultAddress: `0x${string}`
  exactAmountIn: bigint | undefined
  sender: `0x${string}` | undefined
  useTokenInVault: boolean
  useTokenOutVault: boolean
}

export type BuildExactOutArgsInput = {
  poolType: PoolType
  poolAddress: `0x${string}` | null
  tokenInAddress: `0x${string}` | null
  tokenOutAddress: `0x${string}` | null
  tokenInVaultAddress: `0x${string}`
  tokenOutVaultAddress: `0x${string}`
  exactAmountOut: bigint | undefined
  sender: `0x${string}` | undefined
  useTokenInVault: boolean
  useTokenOutVault: boolean
}

export type BuildArgsOutput = {
  route: string | null
  finalPool: `0x${string}` | null
  args: readonly [
    `0x${string}`,
    `0x${string}`,
    `0x${string}`,
    `0x${string}`,
    `0x${string}`,
    bigint,
    `0x${string}`,
    `0x${string}`
  ] | null
  valid: boolean
  missing: string[]
}
