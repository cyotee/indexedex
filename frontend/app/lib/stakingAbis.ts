'use client'

import { erc20Abi as viemErc20Abi } from 'viem'
import { swapParamsAbi, permitAbi, swapWithPermitAbi, swapWithPermitOutAbi, swapExactInAbi, swapExactOutAbi } from './swapAbis'

export const erc20Abi = viemErc20Abi

export const permit2Abi = [
  {
    inputs: [
      { name: 'token', type: 'address' },
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint160' },
      { name: 'expiration', type: 'uint48' }
    ],
    name: 'approve',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  }
] as const

export const STANDARD_EXCHANGE_SWAP_SINGLE_TOKEN_EXACT_IN_WITH_PERMIT_ABI = swapWithPermitAbi
export const STANDARD_EXCHANGE_SWAP_SINGLE_TOKEN_EXACT_OUT_WITH_PERMIT_ABI = swapWithPermitOutAbi
export const STANDARD_EXCHANGE_SWAP_SINGLE_TOKEN_EXACT_IN_ABI = swapExactInAbi
export const STANDARD_EXCHANGE_SWAP_SINGLE_TOKEN_EXACT_OUT_ABI = swapExactOutAbi

export type SwapParams = {
  sender: `0x${string}`
  kind: number // uint8
  pool: `0x${string}`
  tokenIn: `0x${string}`
  tokenInVault: `0x${string}`
  tokenOut: `0x${string}`
  tokenOutVault: `0x${string}`
  amountGiven: bigint
  limit: bigint
  deadline: bigint
  wethIsEth: boolean
  userData: `0x${string}`
}

export type Permit = {
  permitted: {
    token: `0x${string}`
    amount: bigint
  }
  nonce: bigint
  deadline: bigint
}

export const SELECTOR_SWAP_EXACT_IN_WITH_PERMIT = '0x7585dc3d' as `0x${string}`
export const SELECTOR_SWAP_EXACT_OUT_WITH_PERMIT = '0x5bc8b2f3' as `0x${string}`

export const MAX_UINT160 = (BigInt(1) << BigInt(160)) - BigInt(1)

export { swapParamsAbi, permitAbi }
