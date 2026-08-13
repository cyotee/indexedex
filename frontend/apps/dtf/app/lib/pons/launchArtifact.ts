/**
 * Pons v1 launch artifact for the DTF buy page (chain/4663/pons-launch.json).
 * Written by Script_14_PonsLaunchRich / `pons-launch` deploy command.
 */

import ponsLaunchJson from '@indexedex/protocol/addresses/chain/4663/pons-launch.json'

export type PonsLaunchArtifact = {
  chainId: number
  token: `0x${string}`
  rich?: `0x${string}`
  pool: `0x${string}`
  factory: `0x${string}`
  locker?: `0x${string}`
  weth: `0x${string}`
  swapRouter: `0x${string}`
  restrictionsEndBlock: number
  positionId?: number
  poolFee: number
  isToken0: boolean
  name: string
  symbol: string
  description?: string
  generation?: string
  networkProfile?: string
  logo?: string
}

function asAddress(v: unknown): `0x${string}` | null {
  if (typeof v !== 'string' || !/^0x[0-9a-fA-F]{40}$/.test(v)) return null
  return v as `0x${string}`
}

/** Load committed launch artifact; returns null if token missing or invalid. */
export function getPonsLaunchArtifact(): PonsLaunchArtifact | null {
  const raw = ponsLaunchJson as Record<string, unknown>
  const token = asAddress(raw.token ?? raw.rich)
  const pool = asAddress(raw.pool)
  const factory = asAddress(raw.factory)
  const weth = asAddress(raw.weth)
  const swapRouter = asAddress(raw.swapRouter)
  if (!token || !pool || !factory || !weth || !swapRouter) return null

  const poolFee = Number(raw.poolFee ?? 10000)
  const restrictionsEndBlock = Number(raw.restrictionsEndBlock ?? 0)
  const chainId = Number(raw.chainId ?? 4663)

  return {
    chainId: Number.isFinite(chainId) ? chainId : 4663,
    token,
    rich: token,
    pool,
    factory,
    locker: asAddress(raw.locker) ?? undefined,
    weth,
    swapRouter,
    restrictionsEndBlock: Number.isFinite(restrictionsEndBlock) ? restrictionsEndBlock : 0,
    positionId: typeof raw.positionId === 'number' ? raw.positionId : undefined,
    poolFee: Number.isFinite(poolFee) && poolFee > 0 ? poolFee : 10000,
    isToken0: Boolean(raw.isToken0),
    name: typeof raw.name === 'string' && raw.name ? raw.name : 'RICH',
    symbol: typeof raw.symbol === 'string' && raw.symbol ? raw.symbol : 'RICH',
    description: typeof raw.description === 'string' ? raw.description : undefined,
    generation: typeof raw.generation === 'string' ? raw.generation : 'v1',
    networkProfile: typeof raw.networkProfile === 'string' ? raw.networkProfile : undefined,
    logo: typeof raw.logo === 'string' ? raw.logo : undefined,
  }
}

export const PONS_FACTORY_ABI = [
  {
    type: 'function',
    name: 'graduationStatus',
    stateMutability: 'view',
    inputs: [{ name: 'token', type: 'address' }],
    outputs: [
      { name: 'pairedPrincipal', type: 'uint256' },
      { name: 'threshold', type: 'uint256' },
      { name: 'graduated', type: 'bool' },
    ],
  },
  {
    type: 'function',
    name: 'getLaunchedToken',
    stateMutability: 'view',
    inputs: [{ name: 'token', type: 'address' }],
    outputs: [
      {
        type: 'tuple',
        components: [
          { name: 'token', type: 'address' },
          { name: 'deployer', type: 'address' },
          { name: 'pairedToken', type: 'address' },
          { name: 'positionManager', type: 'address' },
          { name: 'positionId', type: 'uint256' },
          { name: 'dexId', type: 'uint256' },
          { name: 'launchConfigId', type: 'uint256' },
          { name: 'restrictionsEndBlock', type: 'uint256' },
          { name: 'supply', type: 'uint256' },
          { name: 'isToken0', type: 'bool' },
          { name: 'poolFee', type: 'uint24' },
          { name: 'exists', type: 'bool' },
          { name: 'initialBuyAmount', type: 'uint256' },
        ],
      },
    ],
  },
] as const

export const SWAP_ROUTER02_EXACT_IN_ABI = [
  {
    type: 'function',
    name: 'exactInputSingle',
    stateMutability: 'payable',
    inputs: [
      {
        name: 'params',
        type: 'tuple',
        components: [
          { name: 'tokenIn', type: 'address' },
          { name: 'tokenOut', type: 'address' },
          { name: 'fee', type: 'uint24' },
          { name: 'recipient', type: 'address' },
          { name: 'amountIn', type: 'uint256' },
          { name: 'amountOutMinimum', type: 'uint256' },
          { name: 'sqrtPriceLimitX96', type: 'uint160' },
        ],
      },
    ],
    outputs: [{ name: 'amountOut', type: 'uint256' }],
  },
] as const

export const UNI_V3_POOL_SLOT0_ABI = [
  {
    type: 'function',
    name: 'slot0',
    stateMutability: 'view',
    inputs: [],
    outputs: [
      { name: 'sqrtPriceX96', type: 'uint160' },
      { name: 'tick', type: 'int24' },
      { name: 'observationIndex', type: 'uint16' },
      { name: 'observationCardinality', type: 'uint16' },
      { name: 'observationCardinalityNext', type: 'uint16' },
      { name: 'feeProtocol', type: 'uint8' },
      { name: 'unlocked', type: 'bool' },
    ],
  },
  {
    type: 'function',
    name: 'liquidity',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint128' }],
  },
  {
    type: 'function',
    name: 'token0',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
  {
    type: 'function',
    name: 'token1',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
] as const

export const WETH_ABI = [
  {
    type: 'function',
    name: 'deposit',
    stateMutability: 'payable',
    inputs: [],
    outputs: [],
  },
  {
    type: 'function',
    name: 'withdraw',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'wad', type: 'uint256' }],
    outputs: [],
  },
] as const

/** Both tokens 18 decimals: price of token in WETH from sqrtPriceX96. */
export function priceTokenInWethFromSqrt(sqrtPriceX96: bigint, tokenIsToken0: boolean): number {
  if (sqrtPriceX96 === BigInt(0)) return 0
  // price token1/token0 = (sqrtP / 2^96)^2 — display only (number path).
  const Q96 = Math.pow(2, 96)
  const sqrt = Number(sqrtPriceX96) / Q96
  const p1Over0 = sqrt * sqrt
  if (!Number.isFinite(p1Over0) || p1Over0 <= 0) return 0
  // If token is token0, price in token1; if token1, invert.
  return tokenIsToken0 ? p1Over0 : 1 / p1Over0
}
