// Swap state management hook
import { useState, useMemo, useEffect, useCallback } from 'react'
import { useAccount, useChainId, useConnection, useConnectorClient, usePublicClient, useSignTypedData, useWalletClient } from 'wagmi'
import { parseUnits } from 'viem'
import { CHAIN_ID_ANVIL, CHAIN_ID_BASE, CHAIN_ID_BASE_SEPOLIA, CHAIN_ID_LOCALHOST, CHAIN_ID_SEPOLIA, getAddressArtifacts, isSupportedChainId, resolveArtifactsChainId } from '../../lib/addressArtifacts'
import { usePreferredBrowserChainId } from '../../lib/browserChain'
import {
  buildPoolOptionsForChain,
  buildTokenOptionsForChain,
  resolveTokenAddressFromOptionForChain,
  getTokenDecimalsByAddressForChain,
  resolvePoolTypeForChain,
  getStrategyVaultTokensForChain,
  type PoolOption,
  type TokenOption,
  type Address
} from '../../lib/tokenlists'
import { buildExactInArgs, buildExactOutArgs, ZERO_ADDR } from '../../lib/swap/buildArgs'
import type { PoolType, BuildArgsOutput } from '../../lib/swap/types'

export interface SwapState {
  // Wallet & chain
  address: `0x${string}` | undefined
  isConnected: boolean
  chainId: number
  resolvedChainId: number
  publicClient: any
  signTypedDataAsync: any
  platform: any
  
  // Token selection
  selectedPool: '' | Address
  tokenIn: TokenOption['value'] | ''
  tokenOut: TokenOption['value'] | ''
  amountIn: string
  amountOut: string
  lastEditedField: 'in' | 'out'
  
  // Vault options
  useEthIn: boolean
  useEthOut: boolean
  useTokenInVault: boolean
  useTokenOutVault: boolean
  selectedVaultIn: `0x${string}` | ''
  selectedVaultOut: `0x${string}` | ''
  
  // Approval settings
  approvalMode: 'explicit' | 'signed'
  approvalModeInitialized: boolean
  showApprovalSettings: boolean
  useMaxApproval: boolean
  
  // Slippage
  slippage: number
  
  // Resolved addresses
  tokenInAddress: `0x${string}` | null
  tokenOutAddress: `0x${string}` | null
  poolAddress: `0x${string}` | null
  tokenInVaultAddress: `0x${string}`
  tokenOutVaultAddress: `0x${string}`
  
  // Pool & token options
  poolOptions: PoolOption[]
  tokenOptions: TokenOption[]
  filteredVaultOptions: TokenOption[]
  
  // Build results
  builtExactIn: BuildArgsOutput
  builtExactOut: BuildArgsOutput
  ready: boolean
  routePattern: string | null
  
  // Derived values
  exactAmountInField: bigint | undefined
  exactAmountOutField: bigint | undefined
  deadline: bigint
  poolType: PoolType
  minOut: bigint | undefined
  maxIn: bigint | undefined
  
  // Setters
  setSelectedPool: (pool: '' | Address) => void
  setTokenIn: (token: TokenOption['value'] | '') => void
  setTokenOut: (token: TokenOption['value'] | '') => void
  setAmountIn: (amount: string) => void
  setAmountOut: (amount: string) => void
  setLastEditedField: (field: 'in' | 'out') => void
  setUseEthIn: (use: boolean) => void
  setUseEthOut: (use: boolean) => void
  setUseTokenInVault: (use: boolean) => void
  setUseTokenOutVault: (use: boolean) => void
  setSelectedVaultIn: (vault: `0x${string}` | '') => void
  setSelectedVaultOut: (vault: `0x${string}` | '') => void
  setApprovalMode: (mode: 'explicit' | 'signed') => void
  setApprovalModeInitialized: (initialized: boolean) => void
  setShowApprovalSettings: (show: boolean) => void
  setUseMaxApproval: (use: boolean) => void
  setSlippage: (slippage: number) => void
}

export function useSwapState(): SwapState {
  const { address, isConnected } = useAccount()
  const configChainId = useChainId()
  const connection = useConnection()
  const connectorId = connection.connector?.id
  const { data: connectorClient } = useConnectorClient()
  const { data: walletClient } = useWalletClient()
  const preferredBrowserChainIds = useMemo(
    () => [CHAIN_ID_BASE_SEPOLIA, CHAIN_ID_SEPOLIA, CHAIN_ID_ANVIL, CHAIN_ID_LOCALHOST, CHAIN_ID_BASE],
    [],
  )
  const browserChainId = usePreferredBrowserChainId(isConnected, preferredBrowserChainIds, connectorId, address)
  const walletChainId = isConnected
    ? (browserChainId ?? connectorClient?.chain?.id ?? walletClient?.chain?.id ?? connection.chainId ?? configChainId)
    : configChainId
  const resolvedChainId = resolveArtifactsChainId(walletChainId ?? 11155111) ?? walletChainId ?? 11155111
  const isUnsupportedChain = isConnected && walletChainId !== undefined && !isSupportedChainId(walletChainId)
  const wagmiPublicClient = usePublicClient({ chainId: resolvedChainId })
  const publicClient = useMemo(() => (isUnsupportedChain ? null : wagmiPublicClient), [isUnsupportedChain, wagmiPublicClient])
  const { signTypedDataAsync } = useSignTypedData()

  const artifacts = useMemo(() => {
    if (isUnsupportedChain) return null
    return getAddressArtifacts(resolvedChainId)
  }, [isUnsupportedChain, resolvedChainId])
  const platform = artifacts?.platform

  const weth9Address = useMemo(() => {
    const addr = resolveTokenAddressFromOptionForChain(resolvedChainId, 'WETH9')
    if (!addr || addr === '0x0000000000000000000000000000000000000000') return null
    return addr
  }, [resolvedChainId])

  // Pool & token options
  const poolOptions = useMemo(() => buildPoolOptionsForChain(resolvedChainId), [resolvedChainId])
  const tokenOptions: TokenOption[] = useMemo(
    () => buildTokenOptionsForChain(resolvedChainId),
    [resolvedChainId]
  )
  const filteredVaultOptions = useMemo(() => {
    return tokenOptions.filter(
      (t) => t.type === 'vault' && t.chainId === resolvedChainId
    )
  }, [tokenOptions, resolvedChainId])

  // Local state
  const [selectedPool, setSelectedPool] = useState<'' | Address>('')
  const [tokenIn, setTokenIn] = useState<TokenOption['value'] | ''>('')
  const [tokenOut, setTokenOut] = useState<TokenOption['value'] | ''>('')
  const [amountIn, setAmountIn] = useState('')
  const [amountOut, setAmountOut] = useState('')
  const [lastEditedField, setLastEditedField] = useState<'in' | 'out'>('in')
  const [useEthIn, setUseEthIn] = useState(false)
  const [useEthOut, setUseEthOut] = useState(false)
  const [slippage, setSlippage] = useState(1)
  const [useTokenInVault, setUseTokenInVault] = useState(false)
  const [useTokenOutVault, setUseTokenOutVault] = useState(false)
  const [selectedVaultIn, setSelectedVaultIn] = useState<`0x${string}` | ''>('')
  const [selectedVaultOut, setSelectedVaultOut] = useState<`0x${string}` | ''>('')

  const [approvalMode, setApprovalMode] = useState<'explicit' | 'signed'>('signed')
  const [approvalModeInitialized, setApprovalModeInitialized] = useState(false)
  const [showApprovalSettings, setShowApprovalSettings] = useState(false)
  const [useMaxApproval, setUseMaxApproval] = useState(false)

  // Resolved addresses
  const tokenInAddress = useMemo(() => {
    if (useEthIn && weth9Address) return weth9Address
    if (!tokenIn) return null
    return resolveTokenAddressFromOptionForChain(resolvedChainId, tokenIn)
  }, [resolvedChainId, tokenIn, useEthIn, weth9Address])

  const tokenOutAddress = useMemo(() => {
    if (useEthOut && weth9Address) return weth9Address
    if (!tokenOut) return null
    return resolveTokenAddressFromOptionForChain(resolvedChainId, tokenOut)
  }, [resolvedChainId, tokenOut, useEthOut, weth9Address])

  const rawPoolAddress = useMemo(() => {
    if (!selectedPool) return null
    const option = poolOptions.find((p) => p.value === selectedPool)
    return option?.value as `0x${string}` | null
  }, [selectedPool, poolOptions])

  const isWethSentinelWrapUnwrapFlow = useMemo(() => {
    return (
      useEthIn ||
      useEthOut ||
      (tokenInAddress && tokenInAddress === weth9Address) ||
      (tokenOutAddress && tokenOutAddress === weth9Address)
    )
  }, [useEthIn, useEthOut, tokenInAddress, tokenOutAddress, weth9Address])

  const effectiveUseTokenInVault = useMemo(
    () => useTokenInVault && !!selectedVaultIn,
    [useTokenInVault, selectedVaultIn]
  )

  const effectiveUseTokenOutVault = useMemo(
    () => useTokenOutVault && !!selectedVaultOut,
    [useTokenOutVault, selectedVaultOut]
  )

  const poolAddress = useMemo(() => rawPoolAddress, [rawPoolAddress])

  const tokenInVaultAddress = useMemo(() => {
    if (!effectiveUseTokenInVault) return ZERO_ADDR
    return selectedVaultIn || ZERO_ADDR
  }, [effectiveUseTokenInVault, selectedVaultIn])

  const tokenOutVaultAddress = useMemo(() => {
    if (!effectiveUseTokenOutVault) return ZERO_ADDR
    return selectedVaultOut || ZERO_ADDR
  }, [effectiveUseTokenOutVault, selectedVaultOut])

  const exactAmountInField = useMemo(() => {
    if (!amountIn || !tokenInAddress) return undefined
    const decimals = getTokenDecimalsByAddressForChain(resolvedChainId, tokenInAddress)
    return parseFloat(amountIn) > 0 ? parseUnits(amountIn, decimals) : undefined
  }, [resolvedChainId, amountIn, tokenInAddress])

  const exactAmountOutField = useMemo(() => {
    if (!amountOut || !tokenOutAddress) return undefined
    const decimals = getTokenDecimalsByAddressForChain(resolvedChainId, tokenOutAddress)
    return parseFloat(amountOut) > 0 ? parseUnits(amountOut, decimals) : undefined
  }, [resolvedChainId, amountOut, tokenOutAddress])

  const deadline = useMemo(() => {
    return BigInt(Math.floor(Date.now() / 1000) + 3600) // 1 hour
  }, [])

  const poolType: PoolType = useMemo(() => {
    if (!selectedPool) return undefined
    return resolvePoolTypeForChain(resolvedChainId, selectedPool)
  }, [resolvedChainId, selectedPool])

  // Build swap arguments
  const builtExactIn = useMemo(() => {
    if (!address || !poolAddress || !tokenInAddress || !tokenOutAddress) {
      return { route: null, finalPool: null, args: null, valid: false, missing: [] }
    }
    return buildExactInArgs({
      poolType,
      poolAddress,
      tokenInAddress,
      tokenOutAddress,
      tokenInVaultAddress,
      tokenOutVaultAddress,
      exactAmountIn: exactAmountInField,
      sender: address,
      useTokenInVault: effectiveUseTokenInVault,
      useTokenOutVault: effectiveUseTokenOutVault
    })
  }, [address, poolType, poolAddress, tokenInAddress, tokenOutAddress, tokenInVaultAddress, tokenOutVaultAddress, exactAmountInField, effectiveUseTokenInVault, effectiveUseTokenOutVault])

  const builtExactOut = useMemo(() => {
    if (!address || !poolAddress || !tokenInAddress || !tokenOutAddress) {
      return { route: null, finalPool: null, args: null, valid: false, missing: [] }
    }
    return buildExactOutArgs({
      poolType,
      poolAddress,
      tokenInAddress,
      tokenOutAddress,
      tokenInVaultAddress,
      tokenOutVaultAddress,
      exactAmountOut: exactAmountOutField,
      sender: address,
      useTokenInVault: effectiveUseTokenInVault,
      useTokenOutVault: effectiveUseTokenOutVault
    })
  }, [address, poolType, poolAddress, tokenInAddress, tokenOutAddress, tokenInVaultAddress, tokenOutVaultAddress, exactAmountOutField, effectiveUseTokenInVault, effectiveUseTokenOutVault])

  const ready = useMemo(() => {
    return (
      isConnected &&
      !!address &&
      !!poolAddress &&
      !!tokenInAddress &&
      !!tokenOutAddress &&
      !!builtExactIn.valid &&
      !!builtExactOut.valid
    )
  }, [isConnected, address, poolAddress, tokenInAddress, tokenOutAddress, builtExactIn.valid, builtExactOut.valid])

  const routePattern = useMemo(() => {
    return builtExactIn.route || builtExactOut.route || null
  }, [builtExactIn.route, builtExactOut.route])

  // Slippage calculations
  const minOut = useMemo(() => {
    if (exactAmountInField === undefined || !builtExactIn.args) return undefined
    return (exactAmountInField * BigInt(10000 - slippage * 100)) / BigInt(10000)
  }, [exactAmountInField, builtExactIn.args, slippage])

  const maxIn = useMemo(() => {
    if (exactAmountOutField === undefined || !builtExactOut.args) return undefined
    return (exactAmountOutField * BigInt(10000 + slippage * 100)) / BigInt(10000)
  }, [exactAmountOutField, builtExactOut.args, slippage])

  return {
    // Wallet & chain
    address,
    isConnected,
    chainId: walletChainId ?? configChainId,
    resolvedChainId,
    publicClient,
    signTypedDataAsync,
    platform,
    
    // Token selection
    selectedPool,
    tokenIn,
    tokenOut,
    amountIn,
    amountOut,
    lastEditedField,
    
    // Vault options
    useEthIn,
    useEthOut,
    useTokenInVault,
    useTokenOutVault,
    selectedVaultIn,
    selectedVaultOut,
    
    // Approval settings
    approvalMode,
    approvalModeInitialized,
    showApprovalSettings,
    useMaxApproval,
    
    // Slippage
    slippage,
    
    // Resolved addresses
    tokenInAddress,
    tokenOutAddress,
    poolAddress,
    tokenInVaultAddress,
    tokenOutVaultAddress,
    
    // Pool & token options
    poolOptions,
    tokenOptions,
    filteredVaultOptions,
    
    // Build results
    builtExactIn,
    builtExactOut,
    ready,
    routePattern,
    
    // Derived values
    exactAmountInField,
    exactAmountOutField,
    deadline,
    poolType,
    minOut,
    maxIn,
    
    // Setters
    setSelectedPool,
    setTokenIn,
    setTokenOut,
    setAmountIn,
    setAmountOut,
    setLastEditedField,
    setUseEthIn,
    setUseEthOut,
    setUseTokenInVault,
    setUseTokenOutVault,
    setSelectedVaultIn,
    setSelectedVaultOut,
    setApprovalMode,
    setApprovalModeInitialized,
    setShowApprovalSettings,
    setUseMaxApproval,
    setSlippage,
  }
}
