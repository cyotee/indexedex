'use client'

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useAccount, useChainId, useConnection, useConnectorClient, usePublicClient, useWalletClient } from 'wagmi'
import { useReadContract, useWriteContract } from 'wagmi'
import { useSignTypedData } from 'wagmi'
import { erc20Abi } from 'viem'
import { formatUnits, parseUnits } from 'viem'
import DebugPanel from '../components/DebugPanel'
import { debugError, debugLog } from '../lib/debug'
import { usePreferredBrowserChainId } from '../lib/browserChain'
import { useSelectedNetwork } from '../lib/networkSelection'

// Import generated hooks
import { 
  balancerV3StandardExchangeBatchRouterExactInFacetAddress,
  balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
  balancerV3StandardExchangeBatchRouterExactInFacetAbi,
  balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
  useWriteBalancerV3StandardExchangeBatchRouterExactInFacetSwapExactIn,
  useWriteBalancerV3StandardExchangeBatchRouterExactInFacetSwapExactInWithPermit,
  useWriteBalancerV3StandardExchangeBatchRouterExactOutFacetSwapExactOut,
  useWriteBalancerV3StandardExchangeBatchRouterExactOutFacetSwapExactOutWithPermit,
  useReadBetterPermit2Allowance
} from '../generated'

// Import addresses from the new structure
import { CHAIN_ID_ANVIL, CHAIN_ID_BASE, CHAIN_ID_BASE_SEPOLIA, CHAIN_ID_LOCALHOST, CHAIN_ID_SEPOLIA, getAddressArtifacts, isSupportedChainId, resolveArtifactsChainId } from '../lib/addressArtifacts'
import {
  buildPoolOptionsForChain,
  buildTokenOptionsForChain,
  resolveTokenAddressFromOptionForChain,
  resolvePoolTypeForChain,
  getTokenDecimalsByAddressForChain,
  type PoolOption,
  type TokenOption,
  type Address
} from '../lib/tokenlists'
import { resolveAppChain } from '../lib/runtimeChains'

// Types for batch swap operations
interface SwapPathStep {
  id: string
  pool: string
  tokenOut: string
  isBuffer: boolean
  isStrategyVault: boolean
}

interface SwapPath {
  id: string
  tokenIn: string
  // tokenOut is computed from the last step's tokenOut
  exactAmountIn?: string
  exactAmountOut?: string
  minAmountOut?: string
  maxAmountIn?: string
  steps: SwapPathStep[]
}

type SESwapPathStep = {
  pool: Address
  tokenOut: Address
  isBuffer: boolean
  isStrategyVault: boolean
}

type SESwapPathExactIn = {
  tokenIn: Address
  steps: SESwapPathStep[]
  exactAmountIn: bigint
  minAmountOut: bigint
}

type SESwapPathExactOut = {
  tokenIn: Address
  steps: SESwapPathStep[]
  maxAmountIn: bigint
  exactAmountOut: bigint
}

type SwapMode = 'exactIn' | 'exactOut'

type PermitTransferFromInput = {
  permitted: {
    token: `0x${string}`
    amount: bigint
  }
  nonce: bigint
  deadline: bigint
}

type StoredBatchPermitPayload = {
  permits: PermitTransferFromInput[]
  signatures: `0x${string}`[]
  deadline: bigint
  swapMode: SwapMode
  intentKey: string
  signaturePath: 'typedData'
  exactInPaths: SESwapPathExactIn[] | null
  exactOutPaths: SESwapPathExactOut[] | null
}

// Helper to get the computed tokenOut from a path's last step
function getPathTokenOut(path: SwapPath): string {
  return path.steps.length > 0 ? path.steps[path.steps.length - 1].tokenOut : ''
}

// Helper functions
const ZERO_ADDR = '0x0000000000000000000000000000000000000000' as `0x${string}`
const MAX_UINT160 = (BigInt(1) << BigInt(160)) - BigInt(1)
const MAX_UINT256 = (BigInt(1) << BigInt(256)) - BigInt(1)

const PERMIT2_TOKEN_PERMISSIONS_TYPE = [
  { name: 'token', type: 'address' },
  { name: 'amount', type: 'uint256' },
] as const

const PERMIT2_TRANSFER_FROM_TYPE = [
  { name: 'permitted', type: 'TokenPermissions' },
  { name: 'spender', type: 'address' },
  { name: 'nonce', type: 'uint256' },
  { name: 'deadline', type: 'uint256' },
] as const

function nextAvailableNonces(bitmap: bigint, count: number): bigint[] {
  const nonces: bigint[] = []
  for (let i = 0; i < 256 && nonces.length < count; i++) {
    const nonce = BigInt(i)
    if (((bitmap >> nonce) & BigInt(1)) === BigInt(0)) {
      nonces.push(nonce)
    }
  }
  return nonces
}

function getPoolAddress(poolKey: string): `0x${string}` | null {
  // In batch UI we store poolKey as address directly in options
  return (poolKey as unknown as `0x${string}`) || null
}

function normalizeAddress(value: unknown): `0x${string}` | null {
  if (typeof value !== 'string') return null
  if (!value.startsWith('0x')) return null
  if (value.length !== 42) return null
  if (value.toLowerCase() === ZERO_ADDR) return null
  return value as `0x${string}`
}

function applySlippageFloor(amount: bigint, slippagePercent: number): bigint {
  const slippageBps = BigInt(Math.max(0, Math.round(slippagePercent * 10)))
  return (amount * (BigInt(1000) - slippageBps)) / BigInt(1000)
}

function applySlippageCeil(amount: bigint, slippagePercent: number): bigint {
  const slippageBps = BigInt(Math.max(0, Math.round(slippagePercent * 10)))
  return (amount * (BigInt(1000) + slippageBps) + BigInt(999)) / BigInt(1000)
}

function serializeBatchSteps(steps: SESwapPathStep[]): string {
  return steps
    .map((step) => [
      step.pool.toLowerCase(),
      step.tokenOut.toLowerCase(),
      step.isBuffer ? '1' : '0',
      step.isStrategyVault ? '1' : '0',
    ].join(':'))
    .join('>')
}

function buildBatchPermitIntentKey(params: {
  chainId: number
  owner: `0x${string}`
  spender: `0x${string}`
  swapMode: SwapMode
  wethIsEth: boolean
  exactInPaths?: SESwapPathExactIn[] | null
  exactOutPaths?: SESwapPathExactOut[] | null
}): string {
  const prefix = [
    params.chainId.toString(),
    params.owner.toLowerCase(),
    params.spender.toLowerCase(),
    params.swapMode,
    params.wethIsEth ? '1' : '0',
  ].join('|')

  if (params.swapMode === 'exactIn') {
    return `${prefix}|${(params.exactInPaths ?? [])
      .map((path) => [
        path.tokenIn.toLowerCase(),
        serializeBatchSteps(path.steps),
        path.exactAmountIn.toString(),
        path.minAmountOut.toString(),
      ].join('|'))
      .join('||')}`
  }

  return `${prefix}|${(params.exactOutPaths ?? [])
    .map((path) => [
      path.tokenIn.toLowerCase(),
      serializeBatchSteps(path.steps),
      path.maxAmountIn.toString(),
      path.exactAmountOut.toString(),
    ].join('|'))
    .join('||')}`
}

export default function BatchSwapPage() {
  const { address, isConnected } = useAccount()
  const configChainId = useChainId()
  const { selectedChainId } = useSelectedNetwork()
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
    : selectedChainId
  const resolvedChainId = resolveArtifactsChainId(walletChainId ?? selectedChainId, undefined, selectedChainId) ?? selectedChainId ?? 11155111
  const isUnsupportedChain = isConnected && walletChainId !== undefined && !isSupportedChainId(walletChainId)
  const activeChain = useMemo(() => resolveAppChain(resolvedChainId), [resolvedChainId])
  const wagmiPublicClient = usePublicClient({ chainId: resolvedChainId })
  const publicClient = useMemo(() => (isUnsupportedChain ? null : wagmiPublicClient), [isUnsupportedChain, wagmiPublicClient])
  const { signTypedDataAsync } = useSignTypedData()

  const artifacts = useMemo(() => {
    if (isUnsupportedChain) return null
    return getAddressArtifacts(resolvedChainId)
  }, [isUnsupportedChain, resolvedChainId])
  const platform = artifacts?.platform
  const batchRouterAddress = useMemo(() => {
    const generatedExactIn = (balancerV3StandardExchangeBatchRouterExactInFacetAddress as Record<number, string | undefined>)[resolvedChainId]
    const generatedExactOut = (balancerV3StandardExchangeBatchRouterExactOutFacetAddress as Record<number, string | undefined>)[resolvedChainId]

    return (
      normalizeAddress((platform as any)?.balancerV3StandardExchangeBatchRouter) ??
      normalizeAddress((platform as any)?.balancerV3StandardExchangeRouter) ??
      normalizeAddress(generatedExactIn) ??
      normalizeAddress(generatedExactOut)
    )
  }, [platform, resolvedChainId])
  const batchRouterSpenderAddress = useMemo(() => {
    return (
      batchRouterAddress ??
      normalizeAddress((platform as any)?.balancerV3StandardExchangeBatchRouter) ??
      normalizeAddress((platform as any)?.balancerV3StandardExchangeRouter)
    )
  }, [batchRouterAddress, platform])

  const filteredPoolOptions: PoolOption[] = useMemo(() => buildPoolOptionsForChain(resolvedChainId), [resolvedChainId])
  const tokenOptions: TokenOption[] = useMemo(
    () => buildTokenOptionsForChain(resolvedChainId, true, true),
    [resolvedChainId]
  )
  const filteredTokenOptions = tokenOptions
  const weth9Address = useMemo(
    () => resolveTokenAddressFromOptionForChain(resolvedChainId, 'WETH9'),
    [resolvedChainId]
  )

  const getTokenAddress = useCallback(
    (tokenKey: string): `0x${string}` | null => {
      return resolveTokenAddressFromOptionForChain(resolvedChainId, tokenKey as TokenOption['value'])
    },
    [resolvedChainId]
  )

  const getBoundaryTokenAddress = useCallback(
    (tokenKey: string): `0x${string}` | null => {
      if (tokenKey === 'ETH') return weth9Address
      return resolveTokenAddressFromOptionForChain(resolvedChainId, tokenKey as TokenOption['value'])
    },
    [resolvedChainId, weth9Address]
  )

  const normalizeBoundaryWethSteps = useCallback(
    (path: SwapPath): SwapPathStep[] => {
      if (!weth9Address) return path.steps

      return path.steps.filter((step, stepIndex) => {
        const poolAddr = getPoolAddress(step.pool)
        if (!poolAddr || poolAddr.toLowerCase() !== weth9Address.toLowerCase()) return true
        if (step.isBuffer || step.isStrategyVault) return true

        const isFirstStep = stepIndex === 0
        const isLastStep = stepIndex === path.steps.length - 1
        const prevTokenKey = isFirstStep ? path.tokenIn : path.steps[stepIndex - 1]?.tokenOut ?? ''
        const prevTokenAddr = getBoundaryTokenAddress(prevTokenKey)
        const nextTokenAddr = getBoundaryTokenAddress(step.tokenOut)

        const prevIsWethBoundary = prevTokenKey === 'ETH'
          || prevTokenKey === 'WETH9'
          || (!!prevTokenAddr && prevTokenAddr.toLowerCase() === weth9Address.toLowerCase())
        const nextIsWethBoundary = step.tokenOut === 'ETH'
          || step.tokenOut === 'WETH9'
          || (!!nextTokenAddr && nextTokenAddr.toLowerCase() === weth9Address.toLowerCase())

        // Batch mode already handles native ETH <-> WETH at settlement boundaries.
        // Strip explicit sentinel wrap/unwrap steps so the route is encoded correctly.
        if (isFirstStep && path.tokenIn === 'ETH' && nextIsWethBoundary) {
          return false
        }

        if (isLastStep && prevIsWethBoundary && step.tokenOut === 'ETH') {
          return false
        }

        if (prevIsWethBoundary && nextIsWethBoundary) {
          throw new Error('WETH (Wrap/Unwrap) is only valid as the first ETH -> WETH step or the last WETH -> ETH step in batch mode')
        }

        return true
      })
    },
    [weth9Address, getBoundaryTokenAddress]
  )

  const getTokenDecimals = useCallback(
    (tokenAddressOrSpecial: string): number => {
      if (tokenAddressOrSpecial === 'ETH') return 18
      const addr = resolveTokenAddressFromOptionForChain(resolvedChainId, tokenAddressOrSpecial as TokenOption['value'])
      return getTokenDecimalsByAddressForChain(resolvedChainId, addr)
    },
    [resolvedChainId]
  )

  const canonicalizeStep = useCallback((step: SwapPathStep): SwapPathStep => {
    const poolAddr = getPoolAddress(step.pool)
    const poolType = resolvePoolTypeForChain(resolvedChainId, poolAddr ?? step.pool)

    if (poolType !== 'vault') {
      return {
        ...step,
        isBuffer: false,
        isStrategyVault: false,
      }
    }

    if (step.isBuffer) {
      return {
        ...step,
        isBuffer: true,
        isStrategyVault: false,
      }
    }

    return {
      ...step,
      isBuffer: false,
      isStrategyVault: true,
    }
  }, [getPoolAddress, resolvedChainId])
  
  // Core state
  const [swapMode, setSwapMode] = useState<SwapMode>('exactIn')
  
  // Wagmi hooks for contract interactions
  const { writeContract: writeExactIn } = useWriteBalancerV3StandardExchangeBatchRouterExactInFacetSwapExactIn()
  const { writeContract: writeExactInWithPermit } = useWriteBalancerV3StandardExchangeBatchRouterExactInFacetSwapExactInWithPermit()
  const { writeContract: writeExactOut } = useWriteBalancerV3StandardExchangeBatchRouterExactOutFacetSwapExactOut()
  const { writeContract: writeExactOutWithPermit } = useWriteBalancerV3StandardExchangeBatchRouterExactOutFacetSwapExactOutWithPermit()
  const [paths, setPaths] = useState<SwapPath[]>(() => {
    // Initialize with one empty path by default, including one step
    return [{
      id: `path-${Date.now()}`,
      tokenIn: '',
      exactAmountIn: '',
      exactAmountOut: '',
      minAmountOut: '',
      maxAmountIn: '',
      steps: [{
        id: `step-${Date.now()}`,
        pool: '',
        tokenOut: '',
        isBuffer: false,
        isStrategyVault: false
      }]
    }]
  })
  const [slippage, setSlippage] = useState(1)
  const [deadline, setDeadline] = useState(3600) // 1 hour
  const [approvalMode, setApprovalMode] = useState<'explicit' | 'signed'>('signed')
  const [approvalModeInitialized, setApprovalModeInitialized] = useState(false)

  // Load approval mode from localStorage on mount
  useEffect(() => {
    try {
      const saved = localStorage.getItem('batchSwapApprovalMode')
      if (saved === 'explicit' || saved === 'signed') {
        setApprovalMode(saved)
      }
    } catch {
      // ignore
    }
    setApprovalModeInitialized(true)
  }, [])

  const handleApprovalModeChange = useCallback((mode: 'explicit' | 'signed') => {
    setApprovalMode(mode)
    try {
      localStorage.setItem('batchSwapApprovalMode', mode)
    } catch {
      // ignore
    }
  }, [])

  const hasEthInput = useMemo(
    () => paths.some((path) => path.tokenIn === 'ETH'),
    [paths]
  )
  const hasEthOutput = useMemo(
    () => paths.some((path) => getPathTokenOut(path) === 'ETH'),
    [paths]
  )
  const wethIsEth = hasEthInput || hasEthOutput

  const effectiveApprovalMode = useMemo<'explicit' | 'signed'>(
    () => (hasEthInput ? 'explicit' : approvalMode),
    [hasEthInput, approvalMode]
  )

  // Approval state management
  const [approvalState, setApprovalState] = useState<'idle' | 'approving' | 'success' | 'error'>('idle')
  const [approvalError, setApprovalError] = useState<string>('')
  const [allowancesReady, setAllowancesReady] = useState<boolean>(false)
  const [permit2SpendingLimit, setPermit2SpendingLimit] = useState(MAX_UINT256.toString())
  const [routerSpendingLimit, setRouterSpendingLimit] = useState(MAX_UINT256.toString())

  // Permit2 nonce bitmap for signed mode (word position 0)
  const { data: permit2NonceBitmap, refetch: refetchPermit2Nonce } = useReadContract({
    address: platform.permit2 as `0x${string}`,
    abi: [
      {
        type: 'function',
        name: 'nonceBitmap',
        inputs: [
          { name: 'owner', type: 'address' },
          { name: 'wordPos', type: 'uint256' },
        ],
        outputs: [{ name: 'bitmap', type: 'uint256' }],
        stateMutability: 'view',
      },
    ],
    functionName: 'nonceBitmap',
    args: [address as `0x${string}`, BigInt(0)],
    scopeKey: `batchPermit2Nonce:${address}`,
    query: {
      enabled: !!address,
      staleTime: 0,
      gcTime: 0,
      refetchOnWindowFocus: true,
      refetchOnReconnect: true,
    },
  })

  // Add a new empty path with one default step
  const addPath = useCallback(() => {
    const newPath: SwapPath = {
      id: `path-${Date.now()}`,
      tokenIn: '',
      exactAmountIn: '',
      exactAmountOut: '',
      minAmountOut: '',
      maxAmountIn: '',
      steps: [{
        id: `step-${Date.now()}`,
        pool: '',
        tokenOut: '',
        isBuffer: false,
        isStrategyVault: false
      }]
    }
    setPaths(prev => [...prev, newPath])
  }, [])

  // Remove a path
  const removePath = useCallback((pathId: string) => {
    setPaths(prev => prev.filter(p => p.id !== pathId))
  }, [])

  // Update a path
  const updatePath = useCallback((pathId: string, updates: Partial<SwapPath>) => {
    setPaths(prev => prev.map(p => p.id === pathId ? { ...p, ...updates } : p))
  }, [])

  // Add a step to a path
  const addStep = useCallback((pathId: string) => {
    const newStep: SwapPathStep = {
      id: `step-${Date.now()}`,
      pool: '',
      tokenOut: '',
      isBuffer: false,
      isStrategyVault: false
    }
    setPaths(prev => prev.map(p => 
      p.id === pathId 
        ? { ...p, steps: [...p.steps, newStep] }
        : p
    ))
  }, [])

  // Remove a step from a path
  const removeStep = useCallback((pathId: string, stepId: string) => {
    setPaths(prev => prev.map(p => 
      p.id === pathId 
        ? { ...p, steps: p.steps.filter(s => s.id !== stepId) }
        : p
    ))
  }, [])

  // Update a step
  const updateStep = useCallback((pathId: string, stepId: string, updates: Partial<SwapPathStep>) => {
    setPaths(prev => prev.map(p => 
      p.id === pathId 
        ? { 
            ...p, 
            steps: p.steps.map(s => s.id === stepId ? canonicalizeStep({ ...s, ...updates }) : s)
          }
        : p
    ))
  }, [canonicalizeStep])

  // Paths are now initialized with one empty path by default

  // Validation
  const isValid = useMemo(() => {
    return paths.every(path => {
      if (!path.tokenIn || path.steps.length === 0) return false
      if (swapMode === 'exactIn' && !path.exactAmountIn) return false
      if (swapMode === 'exactOut' && !path.exactAmountOut) return false
      // Ensure all steps have pool and tokenOut (last step's tokenOut is the path's tokenOut)
      return path.steps.every(step => step.pool && step.tokenOut)
    })
  }, [paths, swapMode])

  // Calculate exact-in input amount for legacy/debug approval checks.
  const totalInputAmount = useMemo(() => {
    if (swapMode === 'exactIn') {
      return paths.reduce((sum, path) => {
        if (path.exactAmountIn) {
          try {
            return sum + parseUnits(path.exactAmountIn, 18) // All test tokens use 18 decimals
          } catch {
            return sum
          }
        }
        return sum
      }, BigInt(0))
    }
    return BigInt(0)
  }, [paths, swapMode])

  // Get the first token address for allowance checks using generic resolver
  const approvalPathIndex = useMemo(
    () => paths.findIndex((path) => path.tokenIn && path.tokenIn !== 'ETH'),
    [paths]
  )
  const approvalPath = useMemo(
    () => (approvalPathIndex >= 0 ? paths[approvalPathIndex] : null),
    [approvalPathIndex, paths]
  )

  const tokenInAddress = useMemo(() => {
    if (!approvalPath?.tokenIn) return null
    return getTokenAddress(approvalPath.tokenIn)
  }, [approvalPath, getTokenAddress])

  // Reset allowancesReady when inputs that affect approval requirements change
  useEffect(() => {
    setAllowancesReady(false)
  }, [address, tokenInAddress, totalInputAmount])

  // Token allowance check (token -> permit2)
  const { data: tokenAllowance, refetch: refetchAllowance } = useReadContract({
    address: tokenInAddress as `0x${string}`,
    abi: erc20Abi,
    functionName: 'allowance',
    args: [address as `0x${string}`, platform.permit2 as `0x${string}`],
    scopeKey: `tokenAllowance:${tokenInAddress}:${address}:${approvalState}`,
    query: { enabled: !!tokenInAddress && !!address, staleTime: 0, gcTime: 0, refetchOnWindowFocus: true, refetchOnReconnect: true }
  })

  // Permit2 allowance check (permit2 -> batch router)
  const { data: permit2Allowance, refetch: refetchPermit2Allowance } = useReadBetterPermit2Allowance({
    args: [address as `0x${string}`, tokenInAddress as `0x${string}`, batchRouterSpenderAddress as `0x${string}`],
    scopeKey: `permit2Allowance:${tokenInAddress}:${address}:${approvalState}`,
    query: { enabled: !!tokenInAddress && !!address && !!batchRouterSpenderAddress, staleTime: 0, gcTime: 0, refetchOnWindowFocus: true, refetchOnReconnect: true }
  })

  // Generic write contract hook for approvals
  const { writeContract: writeContract, writeContractAsync } = useWriteContract()

  // Build swap parameters for the contract
  const buildExactInPaths = useCallback((forPreview = false): SESwapPathExactIn[] => {
    return paths.map((path) => {
      const tokenInAddr = getBoundaryTokenAddress(path.tokenIn)
      if (!tokenInAddr) {
        throw new Error(`Invalid tokenIn for path: ${path.tokenIn}`)
      }

      const normalizedSteps = normalizeBoundaryWethSteps(path)
      if (normalizedSteps.length === 0) {
        throw new Error('Batch swap paths need at least one non-WETH-sentinel step')
      }

      const steps: SESwapPathStep[] = normalizedSteps.map((step, stepIndex) => {
        const canonicalStep = canonicalizeStep(step)
        const isLastStep = stepIndex === normalizedSteps.length - 1
        const poolAddr = getPoolAddress(canonicalStep.pool)
        const stepTokenOutAddr = canonicalStep.tokenOut === 'ETH'
          ? (isLastStep ? weth9Address : null)
          : getTokenAddress(canonicalStep.tokenOut)
        if (!poolAddr || !stepTokenOutAddr) {
          if (canonicalStep.tokenOut === 'ETH' && !isLastStep) {
            throw new Error('ETH is only supported as the final token out of a path')
          }
          throw new Error(`Invalid pool or tokenOut for step: ${canonicalStep.pool} -> ${canonicalStep.tokenOut}`)
        }
        return {
          pool: poolAddr,
          tokenOut: stepTokenOutAddr,
          isBuffer: canonicalStep.isBuffer,
          isStrategyVault: canonicalStep.isStrategyVault
        }
      })

      const amount = path.exactAmountIn
      const pathTokenOut = normalizedSteps[normalizedSteps.length - 1]?.tokenOut ?? getPathTokenOut(path)
      if (!amount) {
        throw new Error(`Missing amount for path: ${path.tokenIn} -> ${pathTokenOut}`)
      }

      const tokenInDecimals = getTokenDecimals(path.tokenIn)
      const tokenOutDecimals = getTokenDecimals(pathTokenOut)

      return {
        tokenIn: tokenInAddr,
        steps,
        exactAmountIn: parseUnits(amount, tokenInDecimals),
        minAmountOut: forPreview
          ? BigInt(0)
          : path.minAmountOut
            ? parseUnits(path.minAmountOut, tokenOutDecimals)
            : BigInt(0)
      }
    })
  }, [paths, getTokenAddress, getBoundaryTokenAddress, normalizeBoundaryWethSteps, getTokenDecimals, weth9Address, canonicalizeStep])

  const buildExactOutPaths = useCallback((forPreview = false): SESwapPathExactOut[] => {
    return paths.map((path) => {
      const tokenInAddr = getBoundaryTokenAddress(path.tokenIn)
      if (!tokenInAddr) {
        throw new Error(`Invalid tokenIn for path: ${path.tokenIn}`)
      }

      const normalizedSteps = normalizeBoundaryWethSteps(path)
      if (normalizedSteps.length === 0) {
        throw new Error('Batch swap paths need at least one non-WETH-sentinel step')
      }

      const steps: SESwapPathStep[] = normalizedSteps.map((step, stepIndex) => {
        const canonicalStep = canonicalizeStep(step)
        const isLastStep = stepIndex === normalizedSteps.length - 1
        const poolAddr = getPoolAddress(canonicalStep.pool)
        const stepTokenOutAddr = canonicalStep.tokenOut === 'ETH'
          ? (isLastStep ? weth9Address : null)
          : getTokenAddress(canonicalStep.tokenOut)
        if (!poolAddr || !stepTokenOutAddr) {
          if (canonicalStep.tokenOut === 'ETH' && !isLastStep) {
            throw new Error('ETH is only supported as the final token out of a path')
          }
          throw new Error(`Invalid pool or tokenOut for step: ${canonicalStep.pool} -> ${canonicalStep.tokenOut}`)
        }
        return {
          pool: poolAddr,
          tokenOut: stepTokenOutAddr,
          isBuffer: canonicalStep.isBuffer,
          isStrategyVault: canonicalStep.isStrategyVault
        }
      })

      const amount = path.exactAmountOut
      const pathTokenOut = normalizedSteps[normalizedSteps.length - 1]?.tokenOut ?? getPathTokenOut(path)
      if (!amount) {
        throw new Error(`Missing amount for path: ${path.tokenIn} -> ${pathTokenOut}`)
      }

      const tokenInDecimals = getTokenDecimals(path.tokenIn)
      const tokenOutDecimals = getTokenDecimals(pathTokenOut)

      return {
        tokenIn: tokenInAddr,
        steps,
        maxAmountIn: forPreview
          ? path.tokenIn === 'ETH'
            ? path.maxAmountIn
              ? parseUnits(path.maxAmountIn, tokenInDecimals)
              : (() => { throw new Error('Enter Max Amount In to preview exact-output ETH paths') })()
            : MAX_UINT256
          : path.maxAmountIn
            ? parseUnits(path.maxAmountIn, tokenInDecimals)
            : BigInt(0),
        exactAmountOut: parseUnits(amount, tokenOutDecimals)
      }
    })
  }, [paths, getTokenAddress, getBoundaryTokenAddress, normalizeBoundaryWethSteps, getTokenDecimals, weth9Address, canonicalizeStep])

  const previewExactInBuild = useMemo(() => {
    if (swapMode !== 'exactIn' || !isValid) {
      return { valid: false, paths: null as SESwapPathExactIn[] | null, error: null as string | null }
    }

    try {
      return { valid: true, paths: buildExactInPaths(true), error: null as string | null }
    } catch (error) {
      return {
        valid: false,
        paths: null as SESwapPathExactIn[] | null,
        error: error instanceof Error ? error.message : 'Failed to build exact-in preview paths',
      }
    }
  }, [swapMode, isValid, buildExactInPaths])

  const previewExactOutBuild = useMemo(() => {
    if (swapMode !== 'exactOut' || !isValid) {
      return { valid: false, paths: null as SESwapPathExactOut[] | null, error: null as string | null }
    }

    try {
      return { valid: true, paths: buildExactOutPaths(true), error: null as string | null }
    } catch (error) {
      return {
        valid: false,
        paths: null as SESwapPathExactOut[] | null,
        error: error instanceof Error ? error.message : 'Failed to build exact-out preview paths',
      }
    }
  }, [swapMode, isValid, buildExactOutPaths])

  const previewExactInKey = useMemo(() => {
    if (!previewExactInBuild.paths) return null
    return previewExactInBuild.paths
      .map((path) => [
        path.tokenIn.toLowerCase(),
        path.exactAmountIn.toString(),
        path.steps
          .map((step) => [step.pool.toLowerCase(), step.tokenOut.toLowerCase(), step.isBuffer ? '1' : '0', step.isStrategyVault ? '1' : '0'].join(':'))
          .join('>'),
      ].join('|'))
      .join('||')
  }, [previewExactInBuild.paths])

  const previewExactOutKey = useMemo(() => {
    if (!previewExactOutBuild.paths) return null
    return previewExactOutBuild.paths
      .map((path) => [
        path.tokenIn.toLowerCase(),
        path.exactAmountOut.toString(),
        path.steps
          .map((step) => [step.pool.toLowerCase(), step.tokenOut.toLowerCase(), step.isBuffer ? '1' : '0', step.isStrategyVault ? '1' : '0'].join(':'))
          .join('>'),
      ].join('|'))
      .join('||')
  }, [previewExactOutBuild.paths])

  const [previewExactInAmountsOut, setPreviewExactInAmountsOut] = useState<bigint[] | null>(null)
  const [previewExactOutAmountsIn, setPreviewExactOutAmountsIn] = useState<bigint[] | null>(null)
  const [previewExactInPending, setPreviewExactInPending] = useState(false)
  const [previewExactOutPending, setPreviewExactOutPending] = useState(false)
  const [previewExactInError, setPreviewExactInError] = useState<string>('')
  const [previewExactOutError, setPreviewExactOutError] = useState<string>('')
  const [accurateExactInAmountsOut, setAccurateExactInAmountsOut] = useState<bigint[] | null>(null)
  const [accurateExactOutAmountsIn, setAccurateExactOutAmountsIn] = useState<bigint[] | null>(null)
  const [accuratePreviewLoading, setAccuratePreviewLoading] = useState(false)
  const [accuratePreviewError, setAccuratePreviewError] = useState<string>('')
  const [executionError, setExecutionError] = useState<string>('')
  const [accuratePreviewSignaturePath, setAccuratePreviewSignaturePath] = useState<'typedData' | null>(null)
  const [storedBatchPermitPayload, setStoredBatchPermitPayload] = useState<StoredBatchPermitPayload | null>(null)
  const previewDebounceTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const lastCompletedPreviewKeyRef = useRef<string | null>(null)
  const latestDesiredPreviewKeyRef = useRef<string | null>(null)
  const previewRequestSeqRef = useRef(0)

  const nativeExactInValue = useCallback(
    (builtPaths: SESwapPathExactIn[]) => builtPaths.reduce(
      (sum, path, index) => sum + (paths[index]?.tokenIn === 'ETH' ? path.exactAmountIn : BigInt(0)),
      BigInt(0)
    ),
    [paths]
  )

  const nativeExactOutValue = useCallback(
    (builtPaths: SESwapPathExactOut[]) => builtPaths.reduce(
      (sum, path, index) => sum + (paths[index]?.tokenIn === 'ETH' ? path.maxAmountIn : BigInt(0)),
      BigInt(0)
    ),
    [paths]
  )

  const approvalCheckAmount = useMemo(() => {
    if (!approvalPath?.tokenIn) return BigInt(0)

    const decimals = getTokenDecimals(approvalPath.tokenIn)

    if (swapMode === 'exactIn') {
      if (!approvalPath.exactAmountIn) return BigInt(0)
      try {
        return parseUnits(approvalPath.exactAmountIn, decimals)
      } catch {
        return BigInt(0)
      }
    }

    if (approvalPath.maxAmountIn) {
      try {
        return parseUnits(approvalPath.maxAmountIn, decimals)
      } catch {
        return BigInt(0)
      }
    }

    if (approvalPathIndex < 0) return BigInt(0)
    return accurateExactOutAmountsIn?.[approvalPathIndex] ?? previewExactOutAmountsIn?.[approvalPathIndex] ?? BigInt(0)
  }, [approvalPath, approvalPathIndex, swapMode, getTokenDecimals, accurateExactOutAmountsIn, previewExactOutAmountsIn])

  const hasTokenApprovalRequirement = useMemo(() => {
    if (!approvalPath?.tokenIn) return false
    if (swapMode === 'exactIn') return !!approvalPath.exactAmountIn && approvalCheckAmount > BigInt(0)
    return (!!approvalPath.maxAmountIn
      || (approvalPathIndex >= 0 && !!previewExactOutAmountsIn?.[approvalPathIndex])
      || (approvalPathIndex >= 0 && !!accurateExactOutAmountsIn?.[approvalPathIndex]))
      && approvalCheckAmount > BigInt(0)
  }, [approvalPath, approvalPathIndex, swapMode, approvalCheckAmount, previewExactOutAmountsIn, accurateExactOutAmountsIn])

  const permit2AllowanceExpired = useMemo(() => {
    if (!permit2Allowance) return false
    const expiration = Number(permit2Allowance[1] ?? 0)
    if (!Number.isFinite(expiration) || expiration === 0) return true
    const nowSec = Math.floor(Date.now() / 1000)
    return expiration <= nowSec
  }, [permit2Allowance])

  const previewNeedsPermit2Approval = useMemo(() => {
    if (!isValid) return false
    if (!hasTokenApprovalRequirement || approvalCheckAmount <= BigInt(0)) return false
    if (tokenAllowance === undefined || tokenAllowance === null) return false
    if (tokenAllowance < approvalCheckAmount) return false
    if (!permit2Allowance) return false
    return permit2Allowance[0] < approvalCheckAmount || permit2AllowanceExpired
  }, [
    isValid,
    hasTokenApprovalRequirement,
    approvalCheckAmount,
    tokenAllowance,
    permit2Allowance,
    permit2AllowanceExpired,
  ])

  const normalizePreviewError = useCallback((error: unknown) => {
    const message = error instanceof Error ? error.message : 'Preview failed'
    if (
      message.includes('AllowanceExpired')
      || message.includes('InsufficientAllowance')
      || message.includes('0xd81b2f2e')
    ) {
      return 'Issue Permit2 -> Router approval first.'
    }
    if (
      message.includes('PoolNotRegistered')
      || message.includes('0x9e51bd5c')
    ) {
      return 'Selected a vault step without vault routing. Re-select the vault pool or mark the step as Strategy Vault.'
    }
    return message
  }, [])

  const previewBlockedMessage = useMemo(() => {
    if (!isValid) return ''
    if (!hasTokenApprovalRequirement) return ''
    if (tokenAllowance === undefined || tokenAllowance === null) {
      return 'Issue Token -> Permit2 approval first.'
    }
    if (tokenAllowance < approvalCheckAmount) {
      return 'Issue Token -> Permit2 approval first.'
    }
    if (previewNeedsPermit2Approval) {
      return 'Issue Permit2 -> Router approval first.'
    }
    return ''
  }, [isValid, hasTokenApprovalRequirement, tokenAllowance, approvalCheckAmount, previewNeedsPermit2Approval])

  const simulatePreviewExactIn = useCallback(
    async (previewPaths: SESwapPathExactIn[]) => {
      if (!publicClient) throw new Error('RPC client unavailable')
      if (!batchRouterAddress) throw new Error('Batch router address unavailable for this chain')
      if (!address) throw new Error('Wallet not connected')

      if (hasEthInput) {
        const deadlineTimestamp = BigInt(Math.floor(Date.now() / 1000) + deadline)
        const { result } = await publicClient.simulateContract({
          address: batchRouterAddress,
          abi: balancerV3StandardExchangeBatchRouterExactInFacetAbi,
          functionName: 'swapExactIn',
          args: [previewPaths, deadlineTimestamp, wethIsEth, '0x'],
          account: address,
          value: nativeExactInValue(previewPaths),
        } as const)

        return result[0] as bigint[]
      }

      const { result } = await publicClient.simulateContract({
        address: batchRouterAddress,
        abi: balancerV3StandardExchangeBatchRouterExactInFacetAbi,
        functionName: 'querySwapExactIn',
        args: [previewPaths, address, '0x'],
        account: ZERO_ADDR,
      } as const)

      return result[0] as bigint[]
    },
    [publicClient, batchRouterAddress, address, hasEthInput, deadline, wethIsEth, nativeExactInValue]
  )

  const simulatePreviewExactOut = useCallback(
    async (previewPaths: SESwapPathExactOut[]) => {
      if (!publicClient) throw new Error('RPC client unavailable')
      if (!batchRouterAddress) throw new Error('Batch router address unavailable for this chain')
      if (!address) throw new Error('Wallet not connected')

      if (hasEthInput) {
        const deadlineTimestamp = BigInt(Math.floor(Date.now() / 1000) + deadline)
        const { result } = await publicClient.simulateContract({
          address: batchRouterAddress,
          abi: balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
          functionName: 'swapExactOut',
          args: [previewPaths, deadlineTimestamp, wethIsEth, '0x'],
          account: address,
          value: nativeExactOutValue(previewPaths),
        } as const)

        return result[0] as bigint[]
      }

      const { result } = await publicClient.simulateContract({
        address: batchRouterAddress,
        abi: balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
        functionName: 'querySwapExactOut',
        args: [previewPaths, address, '0x'],
        account: ZERO_ADDR,
      } as const)

      return result[0] as bigint[]
    },
    [publicClient, batchRouterAddress, address, hasEthInput, deadline, wethIsEth, nativeExactOutValue]
  )

  useEffect(() => {
    if (!isValid) {
      if (swapMode === 'exactIn') {
        setPreviewExactInAmountsOut(null)
        setPreviewExactInPending(false)
        setPreviewExactInError('')
      } else {
        setPreviewExactOutAmountsIn(null)
        setPreviewExactOutPending(false)
        setPreviewExactOutError('')
      }
      lastCompletedPreviewKeyRef.current = null
      latestDesiredPreviewKeyRef.current = null
      if (previewDebounceTimerRef.current) {
        clearTimeout(previewDebounceTimerRef.current)
        previewDebounceTimerRef.current = null
      }
      return
    }

    const isExactInMode = swapMode === 'exactIn'
    const desiredKeyBase = isExactInMode ? previewExactInKey : previewExactOutKey
    const desiredKey = desiredKeyBase ? `${swapMode}:${desiredKeyBase}` : null

    latestDesiredPreviewKeyRef.current = desiredKey

    if (!desiredKey) return
    if (lastCompletedPreviewKeyRef.current === desiredKey) return

    const previewError = isExactInMode ? previewExactInBuild.error : previewExactOutBuild.error
    if (previewError) {
      if (isExactInMode) {
        setPreviewExactInError(previewError)
        setPreviewExactInAmountsOut(null)
      } else {
        setPreviewExactOutError(previewError)
        setPreviewExactOutAmountsIn(null)
      }
      return
    }

    if (previewBlockedMessage) {
      if (isExactInMode) {
        setPreviewExactInError(previewBlockedMessage)
        setPreviewExactInAmountsOut(null)
        setPreviewExactInPending(false)
      } else {
        setPreviewExactOutError(previewBlockedMessage)
        setPreviewExactOutAmountsIn(null)
        setPreviewExactOutPending(false)
      }
      lastCompletedPreviewKeyRef.current = null
      return
    }

    if (previewDebounceTimerRef.current) {
      clearTimeout(previewDebounceTimerRef.current)
      previewDebounceTimerRef.current = null
    }

    previewDebounceTimerRef.current = setTimeout(() => {
      const requestId = ++previewRequestSeqRef.current
      void (async () => {
        try {
          if (isExactInMode) {
            if (!previewExactInBuild.paths) return
            setPreviewExactInPending(true)
            setPreviewExactInError('')
            const amountsOut = await simulatePreviewExactIn(previewExactInBuild.paths)
            if (previewRequestSeqRef.current !== requestId) return
            if (latestDesiredPreviewKeyRef.current !== desiredKey) return
            setPreviewExactInAmountsOut(amountsOut)
          } else {
            if (!previewExactOutBuild.paths) return
            setPreviewExactOutPending(true)
            setPreviewExactOutError('')
            const amountsIn = await simulatePreviewExactOut(previewExactOutBuild.paths)
            if (previewRequestSeqRef.current !== requestId) return
            if (latestDesiredPreviewKeyRef.current !== desiredKey) return
            setPreviewExactOutAmountsIn(amountsIn)
          }
          lastCompletedPreviewKeyRef.current = desiredKey
        } catch (error) {
          if (previewRequestSeqRef.current !== requestId) return
          const message = normalizePreviewError(error)
          if (isExactInMode) {
            setPreviewExactInAmountsOut(null)
            setPreviewExactInError(message)
          } else {
            setPreviewExactOutAmountsIn(null)
            setPreviewExactOutError(message)
          }
        } finally {
          if (previewRequestSeqRef.current !== requestId) return
          if (isExactInMode) {
            setPreviewExactInPending(false)
          } else {
            setPreviewExactOutPending(false)
          }
        }
      })()
    }, 450)

    return () => {
      if (previewDebounceTimerRef.current) {
        clearTimeout(previewDebounceTimerRef.current)
        previewDebounceTimerRef.current = null
      }
    }
  }, [
    isValid,
    swapMode,
    previewExactInKey,
    previewExactOutKey,
    previewExactInBuild,
    previewExactOutBuild,
    previewBlockedMessage,
    normalizePreviewError,
    simulatePreviewExactIn,
    simulatePreviewExactOut,
  ])

  const previewPending = swapMode === 'exactIn' ? previewExactInPending : previewExactOutPending
  const previewError = swapMode === 'exactIn' ? previewExactInError : previewExactOutError
  const showSignedPreviewControls = effectiveApprovalMode === 'signed' && !hasEthInput && isValid

  useEffect(() => {
    setAccurateExactInAmountsOut(null)
    setAccurateExactOutAmountsIn(null)
    setAccuratePreviewError('')
    setAccuratePreviewSignaturePath(null)
    setStoredBatchPermitPayload(null)
  }, [paths, swapMode, slippage, effectiveApprovalMode, hasEthInput, address, resolvedChainId, batchRouterSpenderAddress])

  // Check if token approval is needed
  const needsTokenApproval = useMemo(() => {
    if (!approvalCheckAmount || tokenAllowance === undefined || tokenAllowance === null) return false
    return tokenAllowance < approvalCheckAmount
  }, [approvalCheckAmount, tokenAllowance])

  // Check if permit2 approval is needed
  const needsPermit2Approval = previewNeedsPermit2Approval

  // Overall approval needed
  const needsApproval = useMemo(() => {
    return effectiveApprovalMode === 'signed'
      ? needsTokenApproval
      : needsTokenApproval || needsPermit2Approval
  }, [effectiveApprovalMode, needsTokenApproval, needsPermit2Approval])

  const showTokenToPermit2Prompt = useMemo(() => {
    if (!approvalPath?.tokenIn) return false
    if (hasTokenApprovalRequirement && approvalState === 'approving') return true
    if (hasTokenApprovalRequirement && (tokenAllowance === undefined || tokenAllowance === null)) return true
    if (needsTokenApproval) return true
    if (previewBlockedMessage.includes('Issue Token -> Permit2 approval first')) return true
    if (previewError.includes('Issue Token -> Permit2 approval first')) return true
    return accuratePreviewError.includes('Insufficient token approval to Permit2')
      || accuratePreviewError.includes('Issue Token → Permit2 approval first')
      || accuratePreviewError.includes('Issue Token -> Permit2 approval first')
  }, [
    approvalPath,
    hasTokenApprovalRequirement,
    tokenAllowance,
    approvalState,
    needsTokenApproval,
    previewBlockedMessage,
    previewError,
    accuratePreviewError,
  ])

  const showPermit2RouterPrompt = useMemo(() => {
    if (!approvalPath?.tokenIn) return false
    if (previewNeedsPermit2Approval && approvalState === 'approving') return true
    if (previewBlockedMessage.includes('Issue Permit2 -> Router approval first')) return true
    if (previewError.includes('Issue Permit2 -> Router approval first')) return true
    return false
  }, [approvalPath, previewNeedsPermit2Approval, approvalState, previewBlockedMessage, previewError])

  const setTokenAllowance = useCallback(async (token: `0x${string}`, spender: `0x${string}`, amount: bigint) => {
    if (!publicClient) throw new Error('RPC client unavailable')

    try {
      const hash = await writeContractAsync({
        address: token,
        abi: erc20Abi,
        functionName: 'approve',
        args: [spender, amount],
        chain: activeChain,
        account: address,
      })
      await publicClient.waitForTransactionReceipt({ hash })
      return
    } catch (error) {
      debugError('[Batch Token Approval] Direct approve failed, trying reset-to-zero flow', error)
    }

    const resetHash = await writeContractAsync({
      address: token,
      abi: erc20Abi,
      functionName: 'approve',
      args: [spender, BigInt(0)],
      chain: activeChain,
      account: address,
    })
    await publicClient.waitForTransactionReceipt({ hash: resetHash })

    const setHash = await writeContractAsync({
      address: token,
      abi: erc20Abi,
      functionName: 'approve',
      args: [spender, amount],
      chain: activeChain,
      account: address,
    })
    await publicClient.waitForTransactionReceipt({ hash: setHash })
  }, [publicClient, writeContractAsync, activeChain, address])

  const handleSetPermit2SpendingLimit = useCallback((amount: bigint) => {
    setPermit2SpendingLimit(amount.toString())
  }, [])

  const handleSetRouterSpendingLimit = useCallback((amount: bigint) => {
    setRouterSpendingLimit(amount.toString())
  }, [])

  const handleIssuePermit2Approval = useCallback(async () => {
    if (!tokenInAddress || !address) return
    if (!publicClient) {
      setApprovalState('error')
      setApprovalError('RPC client unavailable')
      return
    }

    const amount = permit2SpendingLimit ? BigInt(permit2SpendingLimit) : MAX_UINT256

    setApprovalState('approving')
    setApprovalError('')
    setAllowancesReady(false)

    try {
      await setTokenAllowance(tokenInAddress, platform.permit2 as `0x${string}`, amount)
      let tokenOk = false
      for (let attempt = 0; attempt < 3; attempt++) {
        if (attempt > 0) {
          await new Promise((resolve) => setTimeout(resolve, 1000))
        }
        const refreshed = await refetchAllowance()
        tokenOk = (refreshed.data ?? tokenAllowance ?? BigInt(0)) >= amount
        if (tokenOk) break
      }
      setAllowancesReady(tokenOk)
      if (!tokenOk) {
        debugLog('[Batch Permit2 Approval] Warning: token allowance verification still stale after receipt')
      }
      setAccuratePreviewError('')
      setApprovalState('success')
      setTimeout(() => setApprovalState('idle'), 3000)
    } catch (error) {
      setApprovalState('error')
      setApprovalError(error instanceof Error ? error.message : 'Permit2 approval failed')
      setTimeout(() => {
        setApprovalState('idle')
        setApprovalError('')
      }, 5000)
    }
  }, [tokenInAddress, address, publicClient, permit2SpendingLimit, setTokenAllowance, platform.permit2, refetchAllowance, tokenAllowance])

  const handleIssueRouterPermit2Approval = useCallback(async () => {
    if (!tokenInAddress || !address || !approvalCheckAmount || !batchRouterSpenderAddress) return
    if (!publicClient) {
      setApprovalState('error')
      setApprovalError('RPC client unavailable')
      return
    }

    const requestedAmount = routerSpendingLimit ? BigInt(routerSpendingLimit) : MAX_UINT256
    const amount = requestedAmount > MAX_UINT160 ? MAX_UINT160 : requestedAmount
    const expiration = Math.floor(Date.now() / 1000) + (3 * 24 * 60 * 60)

    setApprovalState('approving')
    setApprovalError('')
    setAllowancesReady(false)

    try {
      const hash = await writeContractAsync({
        address: platform.permit2 as `0x${string}`,
        abi: [
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
        ],
        functionName: 'approve',
        args: [tokenInAddress, batchRouterSpenderAddress, amount, expiration],
        chain: activeChain,
        account: address,
      })

      await publicClient.waitForTransactionReceipt({ hash })
      await refetchPermit2Allowance()
      setPreviewExactInError('')
      setPreviewExactOutError('')
      setApprovalState('success')
      setTimeout(() => setApprovalState('idle'), 3000)
    } catch (error) {
      setApprovalState('error')
      setApprovalError(error instanceof Error ? error.message : 'Permit2 router approval failed')
      setTimeout(() => {
        setApprovalState('idle')
        setApprovalError('')
      }, 5000)
    }
  }, [
    tokenInAddress,
    address,
    approvalCheckAmount,
    batchRouterSpenderAddress,
    publicClient,
    routerSpendingLimit,
    writeContractAsync,
    platform.permit2,
    activeChain,
    refetchPermit2Allowance,
  ])

  // Handle approval process
  const handleApproval = useCallback(async () => {
    if (!tokenInAddress || !approvalCheckAmount || !address) return
    if (!publicClient) {
      setApprovalState('error')
      setApprovalError('RPC client unavailable')
      return
    }
    if (!batchRouterSpenderAddress && effectiveApprovalMode === 'explicit') {
      setApprovalState('error')
      setApprovalError('Batch router address unavailable for approval')
      return
    }

    setApprovalState('approving')
    setApprovalError('')
    setAllowancesReady(false)

    try {
      debugLog('[Batch Swap Approval] Starting approval process for amount:', approvalCheckAmount.toString())
      
      // Step 1: Token approval (token -> permit2) with receipt wait
      if (needsTokenApproval) {
        debugLog('[Batch Swap Approval] Step 1: Token approval needed')
        await setTokenAllowance(tokenInAddress as `0x${string}`, platform.permit2 as `0x${string}`, approvalCheckAmount)
        debugLog('[Batch Swap Approval] Token approval confirmed')
      } else {
        debugLog('[Batch Swap Approval] Step 1: Token approval not needed, skipping')
      }

      // Step 2: Permit2 approval (permit2 -> batch router) with receipt wait
      if (effectiveApprovalMode === 'explicit' && needsPermit2Approval) {
        debugLog('[Batch Swap Approval] Step 2: Permit2 approval needed')
        const threeDaysSecs = 3 * 24 * 60 * 60
        const expiration = Math.floor(Date.now() / 1000) + threeDaysSecs
        const hash = await writeContractAsync({
          address: platform.permit2 as `0x${string}`,
          abi: [
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
          ],
          functionName: 'approve',
          args: [tokenInAddress as `0x${string}`, batchRouterSpenderAddress as `0x${string}`, approvalCheckAmount, expiration]
          ,
          chain: activeChain,
          account: address,
        })
        debugLog('[Batch Swap Approval] Permit2 approval submitted, waiting for confirmation...', { hash })
        await publicClient.waitForTransactionReceipt({ hash })
        debugLog('[Batch Swap Approval] Permit2 approval confirmed')
      } else {
        debugLog('[Batch Swap Approval] Step 2: Permit2 approval not needed, skipping')
      }
      
      // Verify allowances strictly
      debugLog('[Batch Swap Approval] Verifying allowances on-chain...')
      const [a1, a2] = await Promise.all([refetchAllowance(), refetchPermit2Allowance()])
      const tokenOk = (a1?.data ?? tokenAllowance ?? BigInt(0)) >= approvalCheckAmount
      const permit2Expiration = Number(a2?.data?.[1] ?? permit2Allowance?.[1] ?? 0)
      const permit2NotExpired =
        effectiveApprovalMode === 'signed'
          ? true
          : Number.isFinite(permit2Expiration)
            && permit2Expiration > Math.floor(Date.now() / 1000)
      const p2Ok =
        effectiveApprovalMode === 'signed'
          ? true
          : (a2?.data?.[0] ?? permit2Allowance?.[0] ?? BigInt(0)) >= approvalCheckAmount && permit2NotExpired
      setAllowancesReady(tokenOk && p2Ok)
      debugLog('[Batch Swap Approval Verify Immediate]', { tokenOk, p2Ok, total: approvalCheckAmount.toString() })
      if (!tokenOk || !p2Ok) {
        throw new Error('Approvals not sufficient after confirmation; please try again')
      }

      setApprovalState('success')
      debugLog('[Batch Swap Approval] All approvals completed successfully')
      setTimeout(() => setApprovalState('idle'), 3000)
      
    } catch (error) {
      debugError('[Batch Swap Approval] Approval failed:', error)
      setApprovalState('error')
      setApprovalError(error instanceof Error ? error.message : 'Approval failed')
      setTimeout(() => {
        setApprovalState('idle')
        setApprovalError('')
      }, 5000)
    }
  }, [
    tokenInAddress,
    approvalCheckAmount,
    activeChain,
    address,
    publicClient,
    needsTokenApproval,
    needsPermit2Approval,
    writeContractAsync,
    refetchAllowance,
    refetchPermit2Allowance,
    tokenAllowance,
    permit2Allowance,
    effectiveApprovalMode,
    batchRouterSpenderAddress,
    platform.permit2,
    setTokenAllowance
  ])

  // Verify allowances once approvals succeed
  useEffect(() => {
    const verify = async () => {
      if (approvalState !== 'success' || !approvalCheckAmount) return
      
      await new Promise(r => setTimeout(r, 400))
      const [a1, a2] = await Promise.all([refetchAllowance(), refetchPermit2Allowance()])
      const tokenOk = (a1?.data ?? tokenAllowance ?? BigInt(0)) >= approvalCheckAmount
      const permit2Expiration = Number(a2?.data?.[1] ?? permit2Allowance?.[1] ?? 0)
      const permit2NotExpired =
        effectiveApprovalMode === 'signed'
          ? true
          : Number.isFinite(permit2Expiration)
            && permit2Expiration > Math.floor(Date.now() / 1000)
      const p2Ok =
        effectiveApprovalMode === 'signed'
          ? true
          : (a2?.data?.[0] ?? permit2Allowance?.[0] ?? BigInt(0)) >= approvalCheckAmount && permit2NotExpired
      setAllowancesReady(tokenOk && p2Ok)
      debugLog('[Batch Swap Approval Verify]', { 
        tokenOk, 
        p2Ok, 
        tokenAllowance: (a1?.data ?? tokenAllowance)?.toString?.(), 
        permit2: (a2?.data?.[0] ?? permit2Allowance?.[0])?.toString?.(), 
        permit2Expiration,
        total: approvalCheckAmount.toString() 
      })
    }
    verify()
  }, [approvalState, approvalCheckAmount, refetchAllowance, refetchPermit2Allowance, tokenAllowance, permit2Allowance, effectiveApprovalMode])

  const signBatchPermits = useCallback(async (
    builtPaths: SESwapPathExactIn[] | SESwapPathExactOut[],
    deadlineTimestamp: bigint,
    spenderAddress: `0x${string}`
  ): Promise<{ permits: PermitTransferFromInput[]; signatures: `0x${string}`[] }> => {
    if (!address) throw new Error('Wallet not connected')
    if (!publicClient) throw new Error('RPC client unavailable')
    if (effectiveApprovalMode !== 'signed') {
      return { permits: [], signatures: [] }
    }
    if (hasEthInput) {
      throw new Error('Signed mode is disabled when any path uses native ETH as token in')
    }

    let nonceBitmap = permit2NonceBitmap
    const refreshed = await refetchPermit2Nonce()
    if (refreshed.data !== undefined && refreshed.data !== null) {
      nonceBitmap = refreshed.data
    }
    if (nonceBitmap === undefined || nonceBitmap === null) {
      throw new Error('Failed to fetch Permit2 nonce bitmap')
    }

    const nonces = nextAvailableNonces(nonceBitmap, builtPaths.length)
    if (nonces.length < builtPaths.length) {
      throw new Error('Not enough available Permit2 nonces in bitmap word 0')
    }

    const permitChainId = await publicClient.getChainId()

    const signed = await Promise.all(
      builtPaths.map(async (path, idx) => {
        const amount = 'exactAmountIn' in path ? path.exactAmountIn : path.maxAmountIn
        const token = path.tokenIn
        const nonce = nonces[idx]

        const currentTokenAllowance = await publicClient.readContract({
          address: token,
          abi: erc20Abi,
          functionName: 'allowance',
          args: [address, platform.permit2 as `0x${string}`],
        }) as bigint

        if (currentTokenAllowance < amount) {
          throw new Error(
            `Insufficient token approval to Permit2 for ${token}: required ${amount.toString()}, approved ${currentTokenAllowance.toString()}. Issue Token → Permit2 approval first.`
          )
        }

        const typedData = {
          domain: {
            name: 'Permit2',
            chainId: permitChainId,
            verifyingContract: platform.permit2 as `0x${string}`,
          },
          types: {
            TokenPermissions: PERMIT2_TOKEN_PERMISSIONS_TYPE,
            PermitTransferFrom: PERMIT2_TRANSFER_FROM_TYPE,
          },
          primaryType: 'PermitTransferFrom' as const,
          message: {
            permitted: {
              token,
              amount,
            },
            spender: spenderAddress,
            nonce,
            deadline: deadlineTimestamp,
          },
        }

        const signature = await signTypedDataAsync({ ...typedData, account: address })

        return {
          permit: {
            permitted: {
              token,
              amount,
            },
            nonce,
            deadline: deadlineTimestamp,
          },
          signature,
        }
      })
    )

    return {
      permits: signed.map((x) => x.permit),
      signatures: signed.map((x) => x.signature as `0x${string}`),
    }
  }, [
    address,
    publicClient,
    effectiveApprovalMode,
    hasEthInput,
    permit2NonceBitmap,
    refetchPermit2Nonce,
    platform.permit2,
    signTypedDataAsync,
  ])

  const buildSignedPreviewPayload = useCallback(async (
    deadlineTimestamp: bigint,
    options?: { forceFresh?: boolean }
  ): Promise<StoredBatchPermitPayload> => {
    if (!address) throw new Error('Wallet not connected')
    if (!publicClient) throw new Error('RPC client unavailable')
    if (effectiveApprovalMode !== 'signed') throw new Error('Signed preview is only available in signed mode')
    if (hasEthInput) throw new Error('Signed preview is unavailable when any path uses native ETH as token in')
    if (!batchRouterSpenderAddress) throw new Error('Batch router address unavailable for this chain')

    const nowSec = BigInt(Math.floor(Date.now() / 1000))

    if (swapMode === 'exactIn') {
      const previewPaths = previewExactInBuild.paths ?? buildExactInPaths(true)
      const optimisticAmountsOut = previewExactInAmountsOut ?? await simulatePreviewExactIn(previewPaths)
      const exactInPaths = previewPaths.map((path, index) => ({
        ...path,
        minAmountOut: applySlippageFloor(optimisticAmountsOut[index] ?? BigInt(0), slippage),
      }))
      const intentKey = buildBatchPermitIntentKey({
        chainId: resolvedChainId,
        owner: address,
        spender: batchRouterSpenderAddress,
        swapMode: 'exactIn',
        wethIsEth,
        exactInPaths,
      })

      if (
        !options?.forceFresh &&
        storedBatchPermitPayload &&
        storedBatchPermitPayload.swapMode === 'exactIn' &&
        storedBatchPermitPayload.intentKey === intentKey &&
        storedBatchPermitPayload.deadline > nowSec
      ) {
        return storedBatchPermitPayload
      }

      const { permits, signatures } = await signBatchPermits(exactInPaths, deadlineTimestamp, batchRouterSpenderAddress)
      const nextPayload: StoredBatchPermitPayload = {
        permits,
        signatures,
        deadline: deadlineTimestamp,
        swapMode: 'exactIn',
        intentKey,
        signaturePath: 'typedData',
        exactInPaths,
        exactOutPaths: null,
      }
      setStoredBatchPermitPayload(nextPayload)
      return nextPayload
    }

    const previewPaths = previewExactOutBuild.paths ?? buildExactOutPaths(true)
    const optimisticAmountsIn = previewExactOutAmountsIn ?? await simulatePreviewExactOut(previewPaths)
    const exactOutPaths = previewPaths.map((path, index) => ({
      ...path,
      maxAmountIn: applySlippageCeil(optimisticAmountsIn[index] ?? BigInt(0), slippage),
    }))
    const intentKey = buildBatchPermitIntentKey({
      chainId: resolvedChainId,
      owner: address,
      spender: batchRouterSpenderAddress,
      swapMode: 'exactOut',
      wethIsEth,
      exactOutPaths,
    })

    if (
      !options?.forceFresh &&
      storedBatchPermitPayload &&
      storedBatchPermitPayload.swapMode === 'exactOut' &&
      storedBatchPermitPayload.intentKey === intentKey &&
      storedBatchPermitPayload.deadline > nowSec
    ) {
      return storedBatchPermitPayload
    }

    const { permits, signatures } = await signBatchPermits(exactOutPaths, deadlineTimestamp, batchRouterSpenderAddress)
    const nextPayload: StoredBatchPermitPayload = {
      permits,
      signatures,
      deadline: deadlineTimestamp,
      swapMode: 'exactOut',
      intentKey,
      signaturePath: 'typedData',
      exactInPaths: null,
      exactOutPaths,
    }
    setStoredBatchPermitPayload(nextPayload)
    return nextPayload
  }, [
    address,
    publicClient,
    effectiveApprovalMode,
    hasEthInput,
    batchRouterSpenderAddress,
    swapMode,
    previewExactInBuild.paths,
    previewExactOutBuild.paths,
    previewExactInAmountsOut,
    previewExactOutAmountsIn,
    simulatePreviewExactIn,
    simulatePreviewExactOut,
    slippage,
    resolvedChainId,
    wethIsEth,
    storedBatchPermitPayload,
    signBatchPermits,
    buildExactInPaths,
    buildExactOutPaths,
  ])

  const handleGetAccuratePreview = useCallback(async () => {
    if (effectiveApprovalMode !== 'signed' || hasEthInput) return
    if (!address || !publicClient) {
      setAccuratePreviewError('Wallet not connected')
      return
    }
    if (!isValid) {
      setAccuratePreviewError('Build a valid batch route first')
      return
    }
    if (needsTokenApproval) {
      setAccuratePreviewError('Issue Token → Permit2 approval first.')
      return
    }
    if (!batchRouterSpenderAddress) {
      setAccuratePreviewError('Batch router address unavailable for this chain')
      return
    }

    setAccuratePreviewLoading(true)
    setAccuratePreviewError('')
    setAccurateExactInAmountsOut(null)
    setAccurateExactOutAmountsIn(null)
    setAccuratePreviewSignaturePath(null)

    try {
      const deadlineTimestamp = BigInt(Math.floor(Date.now() / 1000) + deadline)

      if (swapMode === 'exactIn') {
        const previewPaths = buildExactInPaths(true)
        const { permits, signatures } = await signBatchPermits(previewPaths, deadlineTimestamp, batchRouterSpenderAddress)
        const { result } = await publicClient.simulateContract({
          address: batchRouterSpenderAddress as `0x${string}`,
          abi: balancerV3StandardExchangeBatchRouterExactInFacetAbi,
          functionName: 'swapExactInWithPermit',
          args: [previewPaths, deadlineTimestamp, wethIsEth, '0x', permits, signatures],
          account: address,
        } as const)
        const pathAmountsOut = result[0] as bigint[]
        const exactInPaths = previewPaths.map((path, index) => ({
          ...path,
          minAmountOut: applySlippageFloor(pathAmountsOut[index] ?? BigInt(0), slippage),
        }))
        const intentKey = buildBatchPermitIntentKey({
          chainId: resolvedChainId,
          owner: address,
          spender: batchRouterSpenderAddress,
          swapMode: 'exactIn',
          wethIsEth,
          exactInPaths,
        })
        setStoredBatchPermitPayload({
          permits,
          signatures,
          deadline: deadlineTimestamp,
          swapMode: 'exactIn',
          intentKey,
          signaturePath: 'typedData',
          exactInPaths,
          exactOutPaths: null,
        })
        setAccurateExactInAmountsOut(pathAmountsOut)
      } else {
        const exactOutPaths = buildExactOutPaths()
        const { permits, signatures } = await signBatchPermits(exactOutPaths, deadlineTimestamp, batchRouterSpenderAddress)
        const { result } = await publicClient.simulateContract({
          address: batchRouterSpenderAddress as `0x${string}`,
          abi: balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
          functionName: 'swapExactOutWithPermit',
          args: [exactOutPaths, deadlineTimestamp, wethIsEth, '0x', permits, signatures],
          account: address,
        } as const)
        const intentKey = buildBatchPermitIntentKey({
          chainId: resolvedChainId,
          owner: address,
          spender: batchRouterSpenderAddress,
          swapMode: 'exactOut',
          wethIsEth,
          exactOutPaths,
        })
        setStoredBatchPermitPayload({
          permits,
          signatures,
          deadline: deadlineTimestamp,
          swapMode: 'exactOut',
          intentKey,
          signaturePath: 'typedData',
          exactInPaths: null,
          exactOutPaths,
        })
        setAccurateExactOutAmountsIn(result[0] as bigint[])
      }

      setAccuratePreviewSignaturePath('typedData')
    } catch (error) {
      setAccuratePreviewError(normalizePreviewError(error))
    } finally {
      setAccuratePreviewLoading(false)
    }
  }, [
    effectiveApprovalMode,
    hasEthInput,
    address,
    publicClient,
    isValid,
    swapMode,
    needsTokenApproval,
    deadline,
    batchRouterSpenderAddress,
    buildExactInPaths,
    buildExactOutPaths,
    signBatchPermits,
    slippage,
    resolvedChainId,
    wethIsEth,
    normalizePreviewError,
  ])

  // Execute batch swap
  const executeBatchSwap = useCallback(async () => {
    if (!isValid || !address) return

    try {
      setExecutionError('')
      const builtPaths = swapMode === 'exactIn' ? buildExactInPaths() : buildExactOutPaths()

      // Calculate deadline timestamp
      const deadlineTimestamp = BigInt(Math.floor(Date.now() / 1000) + deadline)

      if (swapMode === 'exactIn') {
        if (effectiveApprovalMode === 'signed') {
          const payload = await buildSignedPreviewPayload(deadlineTimestamp, { forceFresh: true })

          await writeExactInWithPermit({
            args: [payload.exactInPaths ?? [], payload.deadline, wethIsEth, '0x', payload.permits, payload.signatures] as const,
          })
        } else {
          const txValue: bigint | undefined = hasEthInput
            ? nativeExactInValue(builtPaths as SESwapPathExactIn[])
            : undefined
          // Args: [paths, deadline, wethIsEth, userData]
          await writeExactIn({
            args: [builtPaths as SESwapPathExactIn[], deadlineTimestamp, wethIsEth, '0x'] as const,
            value: txValue,
          })
        }
      } else {
        if (effectiveApprovalMode === 'signed') {
          const payload = await buildSignedPreviewPayload(deadlineTimestamp, { forceFresh: true })

          await writeExactOutWithPermit({
            args: [payload.exactOutPaths ?? [], payload.deadline, wethIsEth, '0x', payload.permits, payload.signatures] as const,
          })
        } else {
          const txValue: bigint | undefined = hasEthInput
            ? nativeExactOutValue(builtPaths as SESwapPathExactOut[])
            : undefined
          await writeExactOut({
            args: [builtPaths as SESwapPathExactOut[], deadlineTimestamp, wethIsEth, '0x'] as const,
            value: txValue,
          })
        }
      }

    } catch (error) {
      setStoredBatchPermitPayload(null)
      debugError('Error executing batch swap:', error)
      setExecutionError(normalizePreviewError(error))
    }
  }, [
    isValid,
    address,
    buildExactInPaths,
    buildExactOutPaths,
    deadline,
    hasEthInput,
    swapMode,
    writeExactIn,
    writeExactInWithPermit,
    writeExactOut,
    writeExactOutWithPermit,
    effectiveApprovalMode,
    buildSignedPreviewPayload,
    wethIsEth,
    nativeExactInValue,
    nativeExactOutValue,
    normalizePreviewError,
  ])

  if (!isConnected) {
    return (
      <div className="container mx-auto px-4">
        <div className="text-center pt-10 pb-6">
          <h1 className="text-3xl font-bold text-white">Batch Swap</h1>
          <p className="text-gray-300 mt-2">Connect your wallet to start batch swapping</p>
        </div>
      </div>
    )
  }

  return (
    <div className="container mx-auto px-4 max-w-6xl relative">
      <h1 className="text-3xl font-bold text-white text-center py-8">Batch Swap</h1>
      
      {/* Swap Mode Selection */}
      <div className="mb-6">
        <label className="block text-sm font-medium text-gray-300 mb-2">Swap Mode</label>
        <div className="flex space-x-4">
          <button
            onClick={() => setSwapMode('exactIn')}
            className={`px-4 py-2 rounded-md border ${
              swapMode === 'exactIn' 
                ? 'bg-blue-600 border-blue-500 text-white' 
                : 'bg-slate-700 border-slate-600 text-gray-200 hover:bg-slate-600'
            }`}
          >
            Exact Input
          </button>
          <button
            onClick={() => setSwapMode('exactOut')}
            className={`px-4 py-2 rounded-md border ${
              swapMode === 'exactOut' 
                ? 'bg-blue-600 border-blue-500 text-white' 
                : 'bg-slate-700 border-slate-600 text-gray-200 hover:bg-slate-600'
            }`}
          >
            Exact Output
          </button>
        </div>
      </div>

      {/* Global Settings */}
      <div className="grid grid-cols-3 gap-4 mb-6">
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">Slippage Tolerance</label>
          <div className="flex items-center gap-2">
            {[0.1, 0.5, 1].map((v) => (
              <button
                key={v}
                type="button"
                onClick={() => setSlippage(v)}
                className={`px-3 py-1 rounded-md border ${slippage === v ? 'bg-blue-600 border-blue-500 text-white' : 'bg-slate-700 border-slate-600 text-gray-200 hover:bg-slate-600'}`}
              >
                {v}%
              </button>
            ))}
          </div>
        </div>
        
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">Deadline (minutes)</label>
          <input
            type="number"
            value={deadline / 60}
            onChange={(e) => setDeadline(parseInt(e.target.value) * 60)}
            className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-2"
            min="1"
            max="1440"
          />
        </div>

        <div className="rounded-md border border-slate-600 bg-slate-800/40 p-3 text-sm text-gray-300">
          Select `ETH` as a path `Token In` to wrap native ETH into WETH for settlement, or select `ETH` as the final step `Token Out` to unwrap WETH back to native ETH.
        </div>
      </div>

      {/* Approval Mode */}
      {approvalModeInitialized && (
        <div className="mb-6 rounded-lg border border-slate-600 bg-slate-800/40 p-4">
          <label className="block text-sm font-medium text-gray-300 mb-2">Approval Mode</label>
          <div className="flex space-x-3">
            <button
              onClick={() => handleApprovalModeChange('signed')}
              disabled={hasEthInput}
              className={`px-4 py-2 rounded-md border ${
                approvalMode === 'signed'
                  ? 'bg-blue-600 border-blue-500 text-white'
                  : 'bg-slate-700 border-slate-600 text-gray-200 hover:bg-slate-600'
              } disabled:opacity-50 disabled:cursor-not-allowed`}
            >
              Signed (Permit2)
            </button>
            <button
              onClick={() => handleApprovalModeChange('explicit')}
              className={`px-4 py-2 rounded-md border ${
                approvalMode === 'explicit'
                  ? 'bg-blue-600 border-blue-500 text-white'
                  : 'bg-slate-700 border-slate-600 text-gray-200 hover:bg-slate-600'
              }`}
            >
              Explicit Approvals
            </button>
          </div>
          <p className="text-xs text-gray-400 mt-2">
            {effectiveApprovalMode === 'signed'
              ? 'Signed mode uses Permit2 signatures for the first token in each path; only Token → Permit2 approvals are needed.'
              : 'Explicit mode uses on-chain approvals (Token → Permit2 and Permit2 → Router).'}
          </p>
          {hasEthInput && approvalMode === 'signed' && (
            <p className="text-xs text-yellow-300 mt-1">Signed mode is unavailable when any path uses native ETH as token in.</p>
          )}
        </div>
      )}

      {/* Paths */}
      <div className="space-y-6">
        <div className="flex justify-between items-center">
          <h2 className="text-xl font-semibold text-white">Swap Paths ({paths.length})</h2>
          <button
            onClick={addPath}
            className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700"
          >
            Add Path
          </button>
        </div>

        {paths.map((path, pathIndex) => (
          <div key={path.id} className="border border-slate-600 rounded-lg p-4 bg-slate-700/30">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-medium text-white">Path {pathIndex + 1}</h3>
              <button
                onClick={() => removePath(path.id)}
                className="px-3 py-1 bg-red-600 text-white rounded-md hover:bg-red-700 text-sm"
              >
                Remove
              </button>
            </div>

            {/* Path Configuration */}
            <div className="grid grid-cols-2 gap-4 mb-4">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">Token In</label>
                <select
                  value={path.tokenIn}
                  onChange={(e) => updatePath(path.id, { tokenIn: e.target.value })}
                  className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-2"
                >
                  <option value="">Select Token In</option>
                  {tokenOptions.map(option => (
                    <option key={option.value} value={option.value}>{option.label}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Token Out <span className="text-xs text-gray-400">(from last step)</span>
                </label>
                <div className="w-full rounded-md border border-slate-600 bg-slate-800 text-gray-300 p-2 flex items-center">
                  {getPathTokenOut(path) ? (
                    tokenOptions.find(t => t.value === getPathTokenOut(path))?.label || getPathTokenOut(path)
                  ) : (
                    <span className="text-gray-500 italic">Configure steps below</span>
                  )}
                </div>
              </div>
            </div>

            {/* Amount Input */}
            <div className="grid grid-cols-2 gap-4 mb-4">
              {swapMode === 'exactIn' ? (
                <>
                  <div>
                    <label className="block text-sm font-medium text-gray-300 mb-2">Exact Amount In</label>
                    <input
                      type="number"
                      value={path.exactAmountIn || ''}
                      onChange={(e) => updatePath(path.id, { exactAmountIn: e.target.value })}
                      className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-2"
                      placeholder="0.0"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-300 mb-2">Amount Out</label>
                    <input
                      type="text"
                      readOnly
                      value={(() => {
                        const amount = accurateExactInAmountsOut?.[pathIndex] ?? previewExactInAmountsOut?.[pathIndex]
                        if (amount === undefined) return ''
                        const tokenOutKey = getPathTokenOut(path)
                        const decimals = tokenOutKey ? getTokenDecimals(tokenOutKey) : 18
                        return formatUnits(amount, decimals)
                      })()}
                      className="w-full rounded-md border border-slate-600 bg-slate-800 text-white p-2"
                      placeholder="Quoted automatically"
                    />
                  </div>
                </>
              ) : (
                <>
                  <div>
                    <label className="block text-sm font-medium text-gray-300 mb-2">Exact Amount Out</label>
                    <input
                      type="number"
                      value={path.exactAmountOut || ''}
                      onChange={(e) => updatePath(path.id, { exactAmountOut: e.target.value })}
                      className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-2"
                      placeholder="0.0"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-300 mb-2">Amount In</label>
                    <input
                      type="text"
                      readOnly
                      value={(() => {
                        const amount = accurateExactOutAmountsIn?.[pathIndex] ?? previewExactOutAmountsIn?.[pathIndex]
                        if (amount === undefined) return ''
                        const tokenInKey = path.tokenIn
                        const decimals = tokenInKey ? getTokenDecimals(tokenInKey) : 18
                        return formatUnits(amount, decimals)
                      })()}
                      className="w-full rounded-md border border-slate-600 bg-slate-800 text-white p-2"
                      placeholder="Quoted automatically"
                    />
                  </div>
                </>
              )}
            </div>

            <div className="grid grid-cols-1 gap-4 mb-4">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  {swapMode === 'exactIn' ? 'Min Amount Out' : 'Max Amount In'}
                </label>
                <input
                  type="number"
                  value={swapMode === 'exactIn' ? (path.minAmountOut || '') : (path.maxAmountIn || '')}
                  onChange={(e) => updatePath(path.id, {
                    [swapMode === 'exactIn' ? 'minAmountOut' : 'maxAmountIn']: e.target.value
                  })}
                  className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-2"
                  placeholder="0.0"
                />
              </div>
            </div>

            <div className="mb-4 rounded-md border border-slate-600 bg-slate-800/50 px-3 py-2 text-sm">
              {swapMode === 'exactIn' && previewExactInAmountsOut?.[pathIndex] !== undefined && (() => {
                const tokenOutKey = getPathTokenOut(path)
                const decimals = tokenOutKey ? getTokenDecimals(tokenOutKey) : 18
                const formatted = formatUnits(previewExactInAmountsOut[pathIndex], decimals)
                const tokenLabel = filteredTokenOptions.find((option) => option.value === tokenOutKey)?.label ?? tokenOutKey ?? 'token'
                return (
                  <span className="text-emerald-300">
                    Query Quote Amount Out: {formatted} {tokenLabel}
                  </span>
                )
              })()}

              {swapMode === 'exactIn' && accurateExactInAmountsOut?.[pathIndex] !== undefined && (() => {
                const tokenOutKey = getPathTokenOut(path)
                const decimals = tokenOutKey ? getTokenDecimals(tokenOutKey) : 18
                const formatted = formatUnits(accurateExactInAmountsOut[pathIndex], decimals)
                const tokenLabel = filteredTokenOptions.find((option) => option.value === tokenOutKey)?.label ?? tokenOutKey ?? 'token'
                return (
                  <div className="text-fuchsia-300 mt-1">
                    Accurate Quote Amount Out: {formatted} {tokenLabel}
                  </div>
                )
              })()}

              {swapMode === 'exactOut' && previewExactOutAmountsIn?.[pathIndex] !== undefined && (() => {
                const tokenInKey = path.tokenIn
                const decimals = tokenInKey ? getTokenDecimals(tokenInKey) : 18
                const formatted = formatUnits(previewExactOutAmountsIn[pathIndex], decimals)
                const tokenLabel = filteredTokenOptions.find((option) => option.value === tokenInKey)?.label ?? tokenInKey ?? 'token'
                return (
                  <span className="text-emerald-300">
                    Query Quote Amount In: {formatted} {tokenLabel}
                  </span>
                )
              })()}

              {swapMode === 'exactOut' && accurateExactOutAmountsIn?.[pathIndex] !== undefined && (() => {
                const tokenInKey = path.tokenIn
                const decimals = tokenInKey ? getTokenDecimals(tokenInKey) : 18
                const formatted = formatUnits(accurateExactOutAmountsIn[pathIndex], decimals)
                const tokenLabel = filteredTokenOptions.find((option) => option.value === tokenInKey)?.label ?? tokenInKey ?? 'token'
                return (
                  <div className="text-fuchsia-300 mt-1">
                    Accurate Quote Amount In: {formatted} {tokenLabel}
                  </div>
                )
              })()}

              {previewPending && (
                <span className="text-sky-300">Previewing current route...</span>
              )}

              {accuratePreviewLoading && !previewPending && effectiveApprovalMode === 'signed' && !hasEthInput && (
                <div className="text-fuchsia-300 mt-1">Signing permit and simulating the permit swap path...</div>
              )}

              {!previewPending && !previewError && swapMode === 'exactIn' && previewExactInAmountsOut?.[pathIndex] === undefined && (
                <span className="text-slate-400">Enter a valid exact input path to preview the expected amount out.</span>
              )}

              {!previewPending && !previewError && swapMode === 'exactOut' && previewExactOutAmountsIn?.[pathIndex] === undefined && (
                <span className="text-slate-400">Enter a valid exact output path to preview the required amount in.</span>
              )}
            </div>

            {/* Steps */}
            <div className="space-y-3">
              <div className="flex justify-between items-center">
                <h4 className="text-md font-medium text-white">Steps ({path.steps.length})</h4>
                <button
                  onClick={() => addStep(path.id)}
                  className="px-3 py-1 bg-blue-600 text-white rounded-md hover:bg-blue-700 text-sm"
                >
                  Add Step
                </button>
              </div>

              {path.steps.map((step, stepIndex) => (
                <div key={step.id} className="border border-slate-500 rounded p-3 bg-slate-800/50">
                  <div className="flex justify-between items-center mb-2">
                    <span className="text-sm text-gray-300">Step {stepIndex + 1}</span>
                    <button
                      onClick={() => removeStep(path.id, step.id)}
                      className="px-2 py-1 bg-red-600 text-white rounded text-xs hover:bg-red-700"
                    >
                      Remove
                    </button>
                  </div>

                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-xs font-medium text-gray-300 mb-1">Pool</label>
                      <select
                        value={step.pool}
                        onChange={(e) => updateStep(path.id, step.id, { pool: e.target.value })}
                        className="w-full rounded border border-slate-600 bg-slate-700 text-white p-2 text-sm"
                      >
                        <option value="">Select Pool</option>
                        {filteredPoolOptions.map(option => (
                          <option key={option.value} value={option.value}>{option.label}</option>
                        ))}
                      </select>
                    </div>

                    <div>
                      <label className="block text-xs font-medium text-gray-300 mb-1">Token Out</label>
                      <select
                        value={step.tokenOut}
                        onChange={(e) => updateStep(path.id, step.id, { tokenOut: e.target.value })}
                        className="w-full rounded border border-slate-600 bg-slate-700 text-white p-2 text-sm"
                      >
                        <option value="">Select Token Out</option>
                        {filteredTokenOptions.map(option => (
                          <option key={option.value} value={option.value}>{option.label}</option>
                        ))}
                      </select>
                    </div>
                  </div>

                  <div className="flex gap-4 mt-2">
                    <label className="flex items-center gap-2 text-xs text-gray-300">
                      <input
                        type="checkbox"
                        checked={step.isBuffer}
                        onChange={(e) => updateStep(path.id, step.id, { 
                          isBuffer: e.target.checked,
                          isStrategyVault: e.target.checked ? false : step.isStrategyVault
                        })}
                      />
                      ERC4626 Buffer
                    </label>
                    <label className="flex items-center gap-2 text-xs text-gray-300">
                      <input
                        type="checkbox"
                        checked={step.isStrategyVault}
                        onChange={(e) => updateStep(path.id, step.id, { 
                          isStrategyVault: e.target.checked,
                          isBuffer: e.target.checked ? false : step.isBuffer
                        })}
                      />
                      Strategy Vault
                    </label>
                  </div>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>

      {/* Action Buttons */}
      <div className="mt-8 space-y-4">
        <div className="text-center space-y-3">
          {previewError && (
            <div className="text-sm text-red-400">Preview failed: {previewError}</div>
          )}

          {showSignedPreviewControls && (
            <div className="p-3 bg-slate-700/50 border border-slate-600 rounded-lg text-left">
              <div className="text-xs text-gray-400 mb-2">
                This will ask you to sign an approval so we can simulate the permit swap path and get an accurate quote.
              </div>
              {((swapMode === 'exactIn' && accurateExactInAmountsOut) || (swapMode === 'exactOut' && accurateExactOutAmountsIn)) && (
                <div className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-3 mb-2">
                  <div className="text-sm text-indigo-300 mb-1">
                    {swapMode === 'exactIn' ? 'Accurate Quote' : "You'll Pay"}
                  </div>
                  <div className="text-base">
                    {swapMode === 'exactIn'
                      ? accurateExactInAmountsOut?.map((amount, index) => {
                          const tokenOutKey = getPathTokenOut(paths[index]!)
                          const decimals = tokenOutKey ? getTokenDecimals(tokenOutKey) : 18
                          const tokenLabel = filteredTokenOptions.find((option) => option.value === tokenOutKey)?.label ?? tokenOutKey ?? 'token'
                          return `${formatUnits(amount, decimals)} ${tokenLabel}`
                        }).join(' | ')
                      : accurateExactOutAmountsIn?.map((amount, index) => {
                          const tokenInKey = paths[index]?.tokenIn ?? ''
                          const decimals = tokenInKey ? getTokenDecimals(tokenInKey) : 18
                          const tokenLabel = filteredTokenOptions.find((option) => option.value === tokenInKey)?.label ?? tokenInKey ?? 'token'
                          return `${formatUnits(amount, decimals)} ${tokenLabel}`
                        }).join(' | ')}
                  </div>
                </div>
              )}
              <button
                onClick={handleGetAccuratePreview}
                disabled={accuratePreviewLoading || !isValid}
                className="w-full py-2 px-4 bg-indigo-600 text-white rounded-md disabled:opacity-50 text-sm"
              >
                {accuratePreviewLoading ? 'Getting Accurate Quote...' : 'Get Accurate Quote (Sign Permit)'}
              </button>
              {accuratePreviewError && (
                <div className="text-xs text-red-400 mt-2">
                  {accuratePreviewError}
                </div>
              )}
              {((swapMode === 'exactIn' && accurateExactInAmountsOut) || (swapMode === 'exactOut' && accurateExactOutAmountsIn)) && (
                <div className="text-xs text-green-400 mt-2">
                  ✓ Permit signed and stored for batch swap
                </div>
              )}
            </div>
          )}

          {showTokenToPermit2Prompt && (
            <div className="p-3 bg-slate-700/50 border border-slate-600 rounded-lg text-left">
              <div className="text-xs text-gray-400 mb-2">
                Accurate quote requires Token → Permit2 approval before we can sign and simulate the permit swap path.
              </div>
              <button
                onClick={handleIssuePermit2Approval}
                disabled={approvalState === 'approving' || !isValid}
                className="w-full py-2 px-4 bg-purple-600 text-white rounded-md disabled:opacity-50 text-sm mb-2"
              >
                {approvalState === 'approving' ? 'Approving...' : 'Issue Approval: Token → Permit2'}
              </button>
              <div className="relative">
                <input
                  type="number"
                  placeholder="Token → Permit2 spending limit"
                  value={permit2SpendingLimit}
                  onChange={(e) => setPermit2SpendingLimit(e.target.value)}
                  className="w-full px-3 pr-16 py-2 bg-slate-600 border border-slate-500 rounded-lg text-white text-sm"
                />
                <button
                  onClick={() => handleSetPermit2SpendingLimit(MAX_UINT256)}
                  className="absolute right-1 top-1/2 -translate-y-1/2 px-2 py-1 bg-slate-500 text-white rounded text-xs hover:bg-slate-400"
                >
                  Max
                </button>
              </div>
              {tokenAllowance !== undefined && tokenInAddress && (
                <div className="text-xs text-gray-400 mt-2">
                  Current: {tokenAllowance.toString()} wei
                </div>
              )}
              {approvalError && <div className="text-xs text-red-400 mt-2">{approvalError}</div>}
            </div>
          )}

          {showPermit2RouterPrompt && !showTokenToPermit2Prompt && (
            <div className="p-3 bg-slate-700/50 border border-slate-600 rounded-lg text-left">
              <div className="text-xs text-gray-400 mb-2">
                Query preview currently needs Permit2 → Router approval because the batch router query path settles through Permit2 before returning a quote.
              </div>
              <button
                onClick={handleIssueRouterPermit2Approval}
                disabled={approvalState === 'approving' || !isValid}
                className="w-full py-2 px-4 bg-amber-600 text-white rounded-md disabled:opacity-50 text-sm mb-2"
              >
                {approvalState === 'approving' ? 'Approving...' : 'Issue Approval: Permit2 → Router'}
              </button>
              <div className="relative">
                <input
                  type="number"
                  placeholder="Permit2 → Router spending limit"
                  value={routerSpendingLimit}
                  onChange={(e) => setRouterSpendingLimit(e.target.value)}
                  className="w-full px-3 pr-16 py-2 bg-slate-600 border border-slate-500 rounded-lg text-white text-sm"
                />
                <button
                  onClick={() => handleSetRouterSpendingLimit(MAX_UINT256)}
                  className="absolute right-1 top-1/2 -translate-y-1/2 px-2 py-1 bg-slate-500 text-white rounded text-xs hover:bg-slate-400"
                >
                  Max
                </button>
              </div>
              {permit2Allowance && (
                <div className="text-xs text-gray-400 mt-2">
                  Current Permit2 allowance: {permit2Allowance[0].toString()} wei
                </div>
              )}
              {approvalError && <div className="text-xs text-red-400 mt-2">{approvalError}</div>}
            </div>
          )}

          {/* Approval Button */}
          {needsApproval && !showTokenToPermit2Prompt && !showPermit2RouterPrompt && (
            <button
              onClick={handleApproval}
              disabled={approvalState === 'approving' || !isValid}
              className="px-8 py-3 bg-yellow-600 text-white rounded-md disabled:opacity-50 disabled:cursor-not-allowed hover:bg-yellow-700"
            >
              {approvalState === 'approving' ? 'Approving...' : 'Approve Tokens'}
            </button>
          )}
          
          {/* Execute Button */}
          <button
            onClick={executeBatchSwap}
            disabled={!isValid || needsApproval}
            className="px-8 py-3 bg-blue-600 text-white rounded-md disabled:opacity-50 disabled:cursor-not-allowed hover:bg-blue-700"
          >
            {swapMode === 'exactIn' ? 'Execute Batch Exact Input' : 'Execute Batch Exact Output'}
          </button>
          {executionError && (
            <div className="text-sm text-red-400 max-w-3xl">
              Execute failed: {executionError}
            </div>
          )}
        </div>

        {/* Debug Info */}
        <DebugPanel title="Batch Swap Debug Information">
          <div>Valid: {isValid ? 'Yes' : 'No'}</div>
          <div>Paths: {paths.length}</div>
          <div>Mode: {swapMode}</div>
            <div>Approval Mode: {approvalMode} (effective: {effectiveApprovalMode})</div>
          <div>Slippage: {slippage}%</div>
          <div>Deadline: {deadline} seconds</div>
          <div>ETH Input Paths: {hasEthInput ? 'Yes' : 'No'}</div>
          <div>ETH Output Paths: {hasEthOutput ? 'Yes' : 'No'}</div>
          <div>wethIsEth: {wethIsEth ? 'Yes' : 'No'}</div>
          <div>Batch Router Address: {batchRouterAddress ?? 'N/A'}</div>
          <div>Batch Router Spender: {batchRouterSpenderAddress ?? 'N/A'}</div>
          <div>Preview Pending: {previewPending ? 'Yes' : 'No'}</div>
          <div>Preview Error: {previewError || 'None'}</div>
          <div>Preview Exact In Amounts Out: {previewExactInAmountsOut?.map((amount) => amount.toString()).join(', ') || 'N/A'}</div>
          <div>Preview Exact Out Amounts In: {previewExactOutAmountsIn?.map((amount) => amount.toString()).join(', ') || 'N/A'}</div>
          <div>Signed Preview Loading: {accuratePreviewLoading ? 'Yes' : 'No'}</div>
          <div>Signed Preview Error: {accuratePreviewError || 'None'}</div>
          <div>Execution Error: {executionError || 'None'}</div>
          <div>Signed Preview Signature Path: {accuratePreviewSignaturePath ?? 'N/A'}</div>
          <div>Signed Preview Exact In Amounts Out: {accurateExactInAmountsOut?.map((amount) => amount.toString()).join(', ') || 'N/A'}</div>
          <div>Signed Preview Exact Out Amounts In: {accurateExactOutAmountsIn?.map((amount) => amount.toString()).join(', ') || 'N/A'}</div>
          
          {/* Approval Debug Info */}
          <div className="mt-2 pt-2 border-t border-slate-600">
            <div className="text-xs text-blue-300 font-medium mb-1">Approval State:</div>
            <div>Needs Approval: {needsApproval ? '❌ Yes' : '✅ No'}</div>
            <div>Needs Token Approval: {needsTokenApproval ? '❌ Yes' : '✅ No'}</div>
            <div>Needs Permit2 Approval: {needsPermit2Approval ? '❌ Yes' : '✅ No'}</div>
            <div>Approval State: {approvalState}</div>
            <div>Allowances Ready: {allowancesReady ? '✅ Yes' : '❌ No'}</div>
            <div>Permit2 Nonce Bitmap (word0): {permit2NonceBitmap?.toString?.() ?? 'N/A'}</div>
            {approvalError && <div className="text-red-400">Error: {approvalError}</div>}
          </div>
          
          {/* Allowance Details */}
          {tokenInAddress && (
            <div className="mt-2 pt-2 border-t border-slate-600">
              <div className="text-xs text-blue-300 font-medium mb-1">Allowance Details:</div>
              <div>Token Address: {tokenInAddress}</div>
              <div>Total Input Amount: {totalInputAmount ? formatUnits(totalInputAmount, 18) : 'N/A'}</div>
              <div>Token → Permit2: {tokenAllowance ? formatUnits(tokenAllowance, 18) : 'Loading...'}</div>
              <div>Permit2 → Router: {permit2Allowance ? formatUnits(permit2Allowance[0], 18) : 'Loading...'}</div>
              <div>Router Address: {batchRouterSpenderAddress ?? 'N/A'}</div>
            </div>
          )}
          <div className="mt-2">
            <div>Path Validation Details:</div>
            {paths.map((path, index) => (
              <div key={path.id} className="ml-2">
                Path {index + 1}: 
                tokenIn: {path.tokenIn || 'MISSING'}, 
                tokenOut: {getPathTokenOut(path) || 'MISSING'} (computed from last step), 
                amount: {swapMode === 'exactIn' ? (path.exactAmountIn || 'MISSING') : (path.exactAmountOut || 'MISSING')}, 
                steps: {path.steps.length}
                {path.steps.map((step, stepIndex) => (
                  <div key={step.id} className="ml-2">
                    Step {stepIndex + 1}: pool: {step.pool || 'MISSING'}, tokenOut: {step.tokenOut || 'MISSING'}
                  </div>
                ))}
              </div>
            ))}
          </div>
        </DebugPanel>
      </div>
    </div>
  )
}
