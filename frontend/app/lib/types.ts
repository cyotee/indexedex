'use client'

import type { Address } from 'viem'

// =============================================================================
// Constants
// =============================================================================

export const ZERO_ADDR = '0x0000000000000000000000000000000000000000' as Address

export const MAX_UINT160 = (BigInt(1) << BigInt(160)) - BigInt(1)

// =============================================================================
// Types
// =============================================================================

export type PoolType = 'balancer' | 'vault' | undefined

export type BuildArgsInput = {
  poolType: PoolType
  poolAddress: Address | null
  tokenInAddress: Address | null
  tokenOutAddress: Address | null
  tokenInVaultAddress: Address
  tokenOutVaultAddress: Address
  exactAmountIn: bigint | undefined
  sender: Address | undefined
  useTokenInVault: boolean
  useTokenOutVault: boolean
}

export type BuildExactOutArgsInput = {
  poolType: PoolType
  poolAddress: Address | null
  tokenInAddress: Address | null
  tokenOutAddress: Address | null
  tokenInVaultAddress: Address
  tokenOutVaultAddress: Address
  exactAmountOut: bigint | undefined
  sender: Address | undefined
  useTokenInVault: boolean
  useTokenOutVault: boolean
}

export type BuildArgsOutput = {
  route: string | null
  finalPool: Address | null
  args: readonly [
    Address,
    Address,
    Address,
    Address,
    Address,
    bigint,
    Address,
    string
  ] | null
  valid: boolean
  missing: string[]
}

// =============================================================================
// Permit Types
// =============================================================================

export type StoredPermitSignature = {
  signature: Address
  deadline: bigint
  isExactIn: boolean
}

export type ApprovalMode = 'explicit' | 'signed'

export type ApprovalState = 'idle' | 'approving' | 'success' | 'error'
