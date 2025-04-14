'use client'

import type { Address } from 'viem'
import { ZERO_ADDR, type BuildArgsInput, type BuildExactOutArgsInput, type BuildArgsOutput } from './types'

export function buildExactInArgs(input: BuildArgsInput): BuildArgsOutput {
  const missing: string[] = []
  const { poolType, poolAddress, tokenInAddress, tokenOutAddress, tokenInVaultAddress, tokenOutVaultAddress, exactAmountIn, sender, useTokenInVault, useTokenOutVault } = input

  let route: string | null = null
  let finalPool: Address | null = null
  let tokenInVaultArg: Address = ZERO_ADDR
  let tokenOutVaultArg: Address = ZERO_ADDR

  const hasPool = !!poolAddress
  const hasTokenIn = !!tokenInAddress
  const hasTokenOut = !!tokenOutAddress

  if (!useTokenInVault && !useTokenOutVault && poolType === 'balancer') {
    route = 'Direct Balancer V3 Swap'
    finalPool = (poolAddress || null) as Address | null
    tokenInVaultArg = ZERO_ADDR
    tokenOutVaultArg = ZERO_ADDR
  } else if (useTokenInVault && useTokenOutVault && poolType === 'vault' && tokenInVaultAddress !== ZERO_ADDR && tokenInVaultAddress === tokenOutVaultAddress) {
    route = 'Strategy Vault Pass-Through'
    finalPool = tokenInVaultAddress
    tokenInVaultArg = tokenInVaultAddress
    tokenOutVaultArg = tokenOutVaultAddress
  } else if (useTokenInVault && !useTokenOutVault && poolType === 'vault' && tokenInVaultAddress !== ZERO_ADDR && tokenOutAddress && tokenOutAddress === tokenInVaultAddress) {
    route = 'Strategy Vault Deposit'
    finalPool = tokenInVaultAddress
    tokenInVaultArg = tokenInVaultAddress
    tokenOutVaultArg = ZERO_ADDR
  } else if (!useTokenInVault && useTokenOutVault && poolType === 'vault' && tokenOutVaultAddress !== ZERO_ADDR && tokenInAddress && tokenInAddress === tokenOutVaultAddress) {
    route = 'Strategy Vault Withdrawal'
    finalPool = tokenOutVaultAddress
    tokenInVaultArg = ZERO_ADDR
    tokenOutVaultArg = tokenOutVaultAddress
  } else if (useTokenInVault && !useTokenOutVault && poolType === 'balancer' && tokenInVaultAddress !== ZERO_ADDR) {
    route = 'Vault Deposit + Balancer Swap'
    finalPool = (poolAddress || null) as Address | null
    tokenInVaultArg = tokenInVaultAddress
    tokenOutVaultArg = ZERO_ADDR
  } else if (!useTokenInVault && useTokenOutVault && poolType === 'balancer' && tokenOutVaultAddress !== ZERO_ADDR) {
    route = 'Balancer Swap + Vault Withdrawal'
    finalPool = (poolAddress || null) as Address | null
    tokenInVaultArg = ZERO_ADDR
    tokenOutVaultArg = tokenOutVaultAddress
  } else if (useTokenInVault && useTokenOutVault && poolType === 'balancer' && tokenInVaultAddress !== ZERO_ADDR && tokenOutVaultAddress !== ZERO_ADDR) {
    route = 'Vault Deposit → Balancer Swap → Vault Withdrawal'
    finalPool = (poolAddress || null) as Address | null
    tokenInVaultArg = tokenInVaultAddress
    tokenOutVaultArg = tokenOutVaultAddress
  }

  if (!route) {
    return { route: null, finalPool: null, args: null, valid: false, missing: ['route'] }
  }

  if (!hasPool) missing.push('pool')
  if (!hasTokenIn) missing.push('tokenIn')
  if (!hasTokenOut) missing.push('tokenOut')
  if (!exactAmountIn) missing.push('exactAmountIn')
  if (!sender) missing.push('sender')

  if (route === 'Vault Deposit + Balancer Swap' && tokenOutAddress && tokenOutAddress === tokenInVaultAddress) {
    missing.push('tokenOut (must be non-vault token for this route)')
  }

  if (missing.length > 0 || !finalPool || !tokenInAddress || !tokenOutAddress || !exactAmountIn || !sender) {
    return { route, finalPool: finalPool || null, args: null, valid: false, missing }
  }

  const args: BuildArgsOutput['args'] = [
    finalPool,
    tokenInAddress,
    tokenInVaultArg,
    tokenOutAddress,
    tokenOutVaultArg,
    exactAmountIn,
    sender,
    '0x'
  ]

  return { route, finalPool, args, valid: true, missing }
}

export function buildExactOutArgs(input: BuildExactOutArgsInput): BuildArgsOutput {
  const missing: string[] = []
  const { poolType, poolAddress, tokenInAddress, tokenOutAddress, tokenInVaultAddress, tokenOutVaultAddress, exactAmountOut, sender, useTokenInVault, useTokenOutVault } = input

  let route: string | null = null
  let finalPool: Address | null = null
  let tokenInVaultArg: Address = ZERO_ADDR
  let tokenOutVaultArg: Address = ZERO_ADDR

  const hasPool = !!poolAddress
  const hasTokenIn = !!tokenInAddress
  const hasTokenOut = !!tokenOutAddress

  if (!useTokenInVault && !useTokenOutVault && poolType === 'balancer') {
    route = 'Direct Balancer V3 Swap'
    finalPool = (poolAddress || null) as Address | null
    tokenInVaultArg = ZERO_ADDR
    tokenOutVaultArg = ZERO_ADDR
  } else if (useTokenInVault && useTokenOutVault && poolType === 'vault' && tokenInVaultAddress !== ZERO_ADDR && tokenInVaultAddress === tokenOutVaultAddress) {
    route = 'Strategy Vault Pass-Through'
    finalPool = tokenInVaultAddress
    tokenInVaultArg = tokenInVaultAddress
    tokenOutVaultArg = tokenOutVaultAddress
  } else if (useTokenInVault && !useTokenOutVault && poolType === 'vault' && tokenInVaultAddress !== ZERO_ADDR && tokenOutAddress && tokenOutAddress === tokenInVaultAddress) {
    route = 'Strategy Vault Deposit'
    finalPool = tokenInVaultAddress
    tokenInVaultArg = tokenInVaultAddress
    tokenOutVaultArg = ZERO_ADDR
  } else if (!useTokenInVault && useTokenOutVault && poolType === 'vault' && tokenOutVaultAddress !== ZERO_ADDR && tokenInAddress && tokenInAddress === tokenOutVaultAddress) {
    route = 'Strategy Vault Withdrawal'
    finalPool = tokenOutVaultAddress
    tokenInVaultArg = ZERO_ADDR
    tokenOutVaultArg = tokenOutVaultAddress
  } else if (useTokenInVault && !useTokenOutVault && poolType === 'balancer' && tokenInVaultAddress !== ZERO_ADDR) {
    route = 'Vault Deposit + Balancer Swap'
    finalPool = (poolAddress || null) as Address | null
    tokenInVaultArg = tokenInVaultAddress
    tokenOutVaultArg = ZERO_ADDR
  } else if (!useTokenInVault && useTokenOutVault && poolType === 'balancer' && tokenOutVaultAddress !== ZERO_ADDR) {
    route = 'Balancer Swap + Vault Withdrawal'
    finalPool = (poolAddress || null) as Address | null
    tokenInVaultArg = ZERO_ADDR
    tokenOutVaultArg = tokenOutVaultAddress
  } else if (useTokenInVault && useTokenOutVault && poolType === 'balancer' && tokenInVaultAddress !== ZERO_ADDR && tokenOutVaultAddress !== ZERO_ADDR) {
    route = 'Vault Deposit → Balancer Swap → Vault Withdrawal'
    finalPool = (poolAddress || null) as Address | null
    tokenInVaultArg = tokenInVaultAddress
    tokenOutVaultArg = tokenOutVaultAddress
  }

  if (!route) {
    return { route: null, finalPool: null, args: null, valid: false, missing: ['route'] }
  }

  if (!hasPool) missing.push('pool')
  if (!hasTokenIn) missing.push('tokenIn')
  if (!hasTokenOut) missing.push('tokenOut')
  if (!exactAmountOut) missing.push('exactAmountOut')
  if (!sender) missing.push('sender')

  if (route === 'Vault Deposit + Balancer Swap' && tokenOutAddress && tokenOutAddress === tokenInVaultAddress) {
    missing.push('tokenOut (must be non-vault token for this route)')
  }

  if (missing.length > 0 || !finalPool || !tokenInAddress || !tokenOutAddress || !exactAmountOut || !sender) {
    return { route, finalPool: finalPool || null, args: null, valid: false, missing }
  }

  const args: BuildArgsOutput['args'] = [
    finalPool,
    tokenInAddress,
    tokenInVaultArg,
    tokenOutAddress,
    tokenOutVaultArg,
    exactAmountOut,
    sender,
    '0x'
  ]

  return { route, finalPool, args, valid: true, missing }
}
