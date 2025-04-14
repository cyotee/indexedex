'use client'

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useAccount, useChainId, useConnection, useConnectorClient, usePublicClient, useSignTypedData, useWalletClient } from 'wagmi'
import { useReadContract, useWriteContract } from 'wagmi'
import { foundry, localhost, sepolia } from 'wagmi/chains'
import { balancerV3StandardExchangeRouterExactInQueryFacetAbi } from '../generated'
import { balancerV3StandardExchangeRouterExactOutQueryFacetAbi } from '../generated'
import {
  balancerV3StandardExchangeRouterExactInSwapFacetAbi,
  balancerV3StandardExchangeRouterExactInSwapTargetAbi,
  balancerV3StandardExchangeRouterExactOutSwapFacetAbi,
  balancerV3StandardExchangeRouterExactOutSwapTargetAbi,
} from '../generated'
import { createPublicClient, erc20Abi, http } from 'viem'
import { decodeEventLog, encodeAbiParameters, formatUnits, hashTypedData, keccak256, parseUnits, recoverAddress } from 'viem'
import type { Log } from 'viem'
import DebugPanel from '../components/DebugPanel'
import { debugError, debugLog } from '../lib/debug'
import { usePreferredBrowserChainId } from '../lib/browserChain'

import { hasBytecode, isZeroAddress } from '../lib/onchain'

import { buildPermit2WitnessDigest, createWitnessFromSwapParams, getPermit2TypedData } from '../lib/permit2-signature'

import {
  CHAIN_ID_ANVIL,
  CHAIN_ID_BASE,
  CHAIN_ID_BASE_SEPOLIA,
  CHAIN_ID_LOCALHOST,
  getAddressArtifacts,
  isSupportedChainId,
  resolveArtifactsChainId,
} from '../lib/addressArtifacts'
import {
  buildPoolOptionsForChain,
  buildTokenOptionsForChain,
  resolveTokenAddressFromOptionForChain,
  getTokenDecimalsByAddressForChain,
  resolvePoolTypeForChain,
  getStrategyVaultTokensForChain,
  isStrategyVaultTokenForChain,
  type PoolOption,
  type TokenOption,
  type Address
} from '../lib/tokenlists'
import { CHAIN_ID_SEPOLIA } from '../addresses'

// Helper functions - moved outside component to prevent re-creation
const ZERO_ADDR = '0x0000000000000000000000000000000000000000' as `0x${string}`
const MAX_UINT160 = (BigInt(1) << BigInt(160)) - BigInt(1)
const SELECTOR_SWAP_EXACT_IN_WITH_PERMIT = '0x7585dc3d' as `0x${string}`
const SELECTOR_SWAP_EXACT_OUT_WITH_PERMIT = '0x5bc8b2f3' as `0x${string}`

function buildPermitIntentKey(params: {
  chainId: number
  owner: `0x${string}`
  spender: `0x${string}`
  pool: `0x${string}`
  tokenIn: `0x${string}`
  tokenInVault: `0x${string}`
  tokenOut: `0x${string}`
  tokenOutVault: `0x${string}`
  amountGiven: bigint
  limit: bigint
  wethIsEth: boolean
  userDataHash: `0x${string}`
  isExactIn: boolean
}): string {
  return [
    params.chainId.toString(),
    params.owner.toLowerCase(),
    params.spender.toLowerCase(),
    params.pool.toLowerCase(),
    params.tokenIn.toLowerCase(),
    params.tokenInVault.toLowerCase(),
    params.tokenOut.toLowerCase(),
    params.tokenOutVault.toLowerCase(),
    params.amountGiven.toString(),
    params.limit.toString(),
    params.wethIsEth ? '1' : '0',
    params.userDataHash.toLowerCase(),
    params.isExactIn ? 'in' : 'out',
  ].join('|')
}

// function prettyLabel(key: string): string {
//   let label = key
//     .replace(/ConstProdPool$/, ' Balancer Pool')
//     .replace(/StrategyVault/g, ' Strategy Vault')
//   if (/^aRated/i.test(label)) label = label.replace(/^aRated/i, 'A-Rated ')
//   if (/^bRated/i.test(label)) label = label.replace(/^bRated/i, 'B-Rated ')
//   if (/^cRated/i.test(label)) label = label.replace(/^cRated/i, 'C-Rated ')
//   if (/^wethRated/i.test(label)) label = label.replace(/^wethRated/i, 'WETH-Rated ')
//   // Insert spaces before capitals (lightweight token pair readability)
//   label = label.replace(/([a-z0-9])([A-Z])/g, '$1 $2')
//   return label.trim()
// }

type PoolType = 'balancer' | 'vault' | undefined

type BuildArgsInput = {
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

type BuildExactOutArgsInput = {
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

type BuildArgsOutput = {
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

function buildPreviewKey(args: BuildArgsOutput['args']): string | null {
  if (!args) return null
  const [pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, amount, sender] = args
  return [pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, amount.toString(), sender].join('|')
}

function toPreviewArgs(args: NonNullable<BuildArgsOutput['args']>): NonNullable<BuildArgsOutput['args']> {
  const [pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, amount, _sender, userData] = args
  return [pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, amount, ZERO_ADDR, userData] as const
}

function buildExactInArgs(input: BuildArgsInput): BuildArgsOutput {
  const missing: string[] = []
  const { poolType, poolAddress, tokenInAddress, tokenOutAddress, tokenInVaultAddress, tokenOutVaultAddress, exactAmountIn, sender, useTokenInVault, useTokenOutVault } = input

  let route: string | null = null
  let finalPool: `0x${string}` | null = null
  let tokenInVaultArg: `0x${string}` = ZERO_ADDR
  let tokenOutVaultArg: `0x${string}` = ZERO_ADDR

  const hasPool = !!poolAddress
  const hasTokenIn = !!tokenInAddress
  const hasTokenOut = !!tokenOutAddress

  if (hasPool && hasTokenIn && hasTokenOut && poolAddress && tokenInAddress && tokenOutAddress) {
    const tokenInLower = tokenInAddress.toLowerCase()
    const tokenOutLower = tokenOutAddress.toLowerCase()
    const poolLower = poolAddress.toLowerCase()
    if (tokenInLower === tokenOutLower && poolLower === tokenInLower) {
      route = 'WETH Wrap/Unwrap'
      finalPool = poolAddress as `0x${string}`
      tokenInVaultArg = ZERO_ADDR
      tokenOutVaultArg = ZERO_ADDR
    }
  }

  if (!route) {
    if (!useTokenInVault && !useTokenOutVault && poolType === 'balancer') {
      route = 'Direct Balancer V3 Swap'
      finalPool = (poolAddress || null) as `0x${string}` | null
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
      finalPool = (poolAddress || null) as `0x${string}` | null
      tokenInVaultArg = tokenInVaultAddress
      tokenOutVaultArg = ZERO_ADDR
    } else if (!useTokenInVault && useTokenOutVault && poolType === 'balancer' && tokenOutVaultAddress !== ZERO_ADDR) {
      route = 'Balancer Swap + Vault Withdrawal'
      finalPool = (poolAddress || null) as `0x${string}` | null
      tokenInVaultArg = ZERO_ADDR
      tokenOutVaultArg = tokenOutVaultAddress
    } else if (useTokenInVault && useTokenOutVault && poolType === 'balancer' && tokenInVaultAddress !== ZERO_ADDR && tokenOutVaultAddress !== ZERO_ADDR) {
      route = 'Vault Deposit → Balancer Swap → Vault Withdrawal'
      finalPool = (poolAddress || null) as `0x${string}` | null
      tokenInVaultArg = tokenInVaultAddress
      tokenOutVaultArg = tokenOutVaultAddress
    }
  }

  if (!route) {
    return { route: null, finalPool: null, args: null, valid: false, missing: ['route'] }
  }

  if (!hasPool) missing.push('pool')
  if (!hasTokenIn) missing.push('tokenIn')
  if (!hasTokenOut) missing.push('tokenOut')
  if (!exactAmountIn) missing.push('exactAmountIn')
  if (!sender) missing.push('sender')

  // Additional validation: for Deposit -> Balancer Swap, tokenOut must NOT be the deposit vault address
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

function buildExactOutArgs(input: BuildExactOutArgsInput): BuildArgsOutput {
  const missing: string[] = []
  const {
    poolType,
    poolAddress,
    tokenInAddress,
    tokenOutAddress,
    tokenInVaultAddress,
    tokenOutVaultAddress,
    exactAmountOut,
    sender,
    useTokenInVault,
    useTokenOutVault
  } = input

  let route: string | null = null
  let finalPool: `0x${string}` | null = null
  let tokenInVaultArg: `0x${string}` = ZERO_ADDR
  let tokenOutVaultArg: `0x${string}` = ZERO_ADDR

  const hasPool = !!poolAddress
  const hasTokenIn = !!tokenInAddress
  const hasTokenOut = !!tokenOutAddress

  if (hasPool && hasTokenIn && hasTokenOut && poolAddress && tokenInAddress && tokenOutAddress) {
    const tokenInLower = tokenInAddress.toLowerCase()
    const tokenOutLower = tokenOutAddress.toLowerCase()
    const poolLower = poolAddress.toLowerCase()
    if (tokenInLower === tokenOutLower && poolLower === tokenInLower) {
      route = 'WETH Wrap/Unwrap'
      finalPool = poolAddress as `0x${string}`
      tokenInVaultArg = ZERO_ADDR
      tokenOutVaultArg = ZERO_ADDR
    }
  }

  if (!route && !useTokenInVault && !useTokenOutVault && poolType === 'balancer') {
    route = 'Direct Balancer V3 Swap'
    finalPool = (poolAddress || null) as `0x${string}` | null
    tokenInVaultArg = ZERO_ADDR
    tokenOutVaultArg = ZERO_ADDR
  } else if (!route && useTokenInVault && useTokenOutVault && poolType === 'vault' && tokenInVaultAddress !== ZERO_ADDR && tokenInVaultAddress === tokenOutVaultAddress) {
    route = 'Strategy Vault Pass-Through'
    finalPool = tokenInVaultAddress
    tokenInVaultArg = tokenInVaultAddress
    tokenOutVaultArg = tokenOutVaultAddress
  } else if (!route && useTokenInVault && !useTokenOutVault && poolType === 'vault' && tokenInVaultAddress !== ZERO_ADDR && tokenOutAddress && tokenOutAddress === tokenInVaultAddress) {
    route = 'Strategy Vault Deposit'
    finalPool = tokenInVaultAddress
    tokenInVaultArg = tokenInVaultAddress
    tokenOutVaultArg = ZERO_ADDR
  } else if (!route && !useTokenInVault && useTokenOutVault && poolType === 'vault' && tokenOutVaultAddress !== ZERO_ADDR && tokenInAddress && tokenInAddress === tokenOutVaultAddress) {
    route = 'Strategy Vault Withdrawal'
    finalPool = tokenOutVaultAddress
    tokenInVaultArg = ZERO_ADDR
    tokenOutVaultArg = tokenOutVaultAddress
  } else if (!route && useTokenInVault && !useTokenOutVault && poolType === 'balancer' && tokenInVaultAddress !== ZERO_ADDR) {
    route = 'Vault Deposit + Balancer Swap'
    finalPool = (poolAddress || null) as `0x${string}` | null
    tokenInVaultArg = tokenInVaultAddress
    tokenOutVaultArg = ZERO_ADDR
  } else if (!route && !useTokenInVault && useTokenOutVault && poolType === 'balancer' && tokenOutVaultAddress !== ZERO_ADDR) {
    route = 'Balancer Swap + Vault Withdrawal'
    finalPool = (poolAddress || null) as `0x${string}` | null
    tokenInVaultArg = ZERO_ADDR
    tokenOutVaultArg = tokenOutVaultAddress
  } else if (!route && useTokenInVault && useTokenOutVault && poolType === 'balancer' && tokenInVaultAddress !== ZERO_ADDR && tokenOutVaultAddress !== ZERO_ADDR) {
    route = 'Vault Deposit → Balancer Swap → Vault Withdrawal'
    finalPool = (poolAddress || null) as `0x${string}` | null
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

  // Mirror ExactIn validation: for Deposit -> Balancer Swap, tokenOut must NOT be the deposit vault address
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
// Address/decimals now resolved via token list helpers

export default function SwapPage() {
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
  const resolvedChainId = resolveArtifactsChainId(walletChainId ?? CHAIN_ID_SEPOLIA) ?? walletChainId ?? CHAIN_ID_SEPOLIA
  const isUnsupportedChain = isConnected && walletChainId !== undefined && !isSupportedChainId(walletChainId)
  const wagmiPublicClient = usePublicClient({ chainId: resolvedChainId })

  const localhostPublicClient = useMemo(() => {
    return createPublicClient({ transport: http('http://127.0.0.1:8545') })
  }, [])

  const publicClient = useMemo(() => {
    if (isUnsupportedChain) return null
    if (wagmiPublicClient) return wagmiPublicClient
    if (resolvedChainId === foundry.id || resolvedChainId === localhost.id) return localhostPublicClient
    return null
  }, [isUnsupportedChain, wagmiPublicClient, resolvedChainId, localhostPublicClient])
  const { signTypedDataAsync } = useSignTypedData()

  const artifacts = useMemo(() => {
    if (isUnsupportedChain) return null
    return getAddressArtifacts(resolvedChainId)
  }, [isUnsupportedChain, resolvedChainId])
  const platform = artifacts?.platform

  function normalizeAddress(addr: unknown): `0x${string}` | null {
    if (typeof addr !== 'string') return null
    if (!addr.startsWith('0x')) return null
    if (addr.length !== 42) return null
    if (addr.toLowerCase() === ZERO_ADDR) return null
    return addr as `0x${string}`
  }

  const routerCandidates = useMemo(() => {
    const candidates: `0x${string}`[] = []
    const standard = normalizeAddress((platform as any)?.balancerV3StandardExchangeRouter)

    if (standard) candidates.push(standard)

    return candidates
  }, [platform])
  const permit2Address = useMemo(() => normalizeAddress((platform as any)?.permit2), [platform])

  const [routerAddress, setRouterAddress] = useState<`0x${string}` | null>(null)
  const [routerHasBytecode, setRouterHasBytecode] = useState<boolean | null>(null)
  const [routerBytecodeError, setRouterBytecodeError] = useState<string>('')

  const [rpcChainId, setRpcChainId] = useState<number | null>(null)
  const [rpcChainIdError, setRpcChainIdError] = useState<string>('')

  useEffect(() => {
    let cancelled = false
    setRpcChainIdError('')
    setRpcChainId(null)

    if (!publicClient) return () => { cancelled = true }

    ;(async () => {
      try {
        const id = await publicClient.getChainId()
        if (cancelled) return
        setRpcChainId(id)
      } catch (e) {
        if (cancelled) return
        setRpcChainIdError(e instanceof Error ? e.message : String(e))
      }
    })()

    return () => {
      cancelled = true
    }
  }, [publicClient, resolvedChainId])

  useEffect(() => {
    let cancelled = false
    setRouterBytecodeError('')
    setRouterHasBytecode(null)
    setRouterAddress(null)

    if (!publicClient) {
      setRouterHasBytecode(false)
      setRouterBytecodeError('RPC client unavailable')
      return () => { cancelled = true }
    }

    if (rpcChainId !== null && rpcChainId !== resolvedChainId) {
      setRouterHasBytecode(false)
      setRouterBytecodeError(`RPC network mismatch (wallet chainId=${resolvedChainId}, rpc chainId=${rpcChainId})`)
      return () => { cancelled = true }
    }

    if (routerCandidates.length === 0) {
      setRouterHasBytecode(false)
      setRouterBytecodeError('No router address found in artifacts for this chain')
      return () => { cancelled = true }
    }

    ;(async () => {
      try {
        for (const candidate of routerCandidates) {
          const ok = await hasBytecode(publicClient, candidate)
          if (cancelled) return
          if (ok) {
            setRouterAddress(candidate)
            setRouterHasBytecode(true)
            return
          }
        }
        if (cancelled) return
        setRouterAddress(null)
        setRouterHasBytecode(false)
        setRouterBytecodeError(`Router not deployed at any known candidate address: ${routerCandidates.join(', ')}`)
      } catch (e) {
        if (cancelled) return
        setRouterAddress(null)
        setRouterHasBytecode(false)
        setRouterBytecodeError(e instanceof Error ? e.message : String(e))
      }
    })()

    return () => {
      cancelled = true
    }
  }, [publicClient, rpcChainId, resolvedChainId, routerCandidates])

  const routerSpenderAddress = useMemo(() => {
    return (
      routerAddress ??
      normalizeAddress((platform as any)?.balancerV3StandardExchangeRouter)
    )
  }, [routerAddress, platform])

  const assertRouterDeployed = useCallback(() => {
    if (!routerAddress || routerHasBytecode !== true) throw new Error('Router not deployed')
    if (rpcChainId !== null && rpcChainId !== resolvedChainId) {
      throw new Error(`RPC network mismatch (wallet chainId=${resolvedChainId}, rpc chainId=${rpcChainId})`)
    }
    return routerAddress
  }, [routerAddress, routerHasBytecode, rpcChainId, resolvedChainId])

  const routerReady = useMemo(() => {
    if (!routerAddress) return false
    if (routerHasBytecode !== true) return false
    if (rpcChainId !== null && rpcChainId !== resolvedChainId) return false
    return true
  }, [routerAddress, routerHasBytecode, rpcChainId, resolvedChainId])

  const weth9Address = useMemo(() => {
    const addr = resolveTokenAddressFromOptionForChain(resolvedChainId, 'WETH9')
    if (!addr || addr === '0x0000000000000000000000000000000000000000') return null
    return addr
  }, [resolvedChainId])


  // Pool/token/vault options must be chain-aware and update on chain switch
  const poolOptions = useMemo(() => buildPoolOptionsForChain(resolvedChainId), [resolvedChainId])
  const tokenOptions: TokenOption[] = useMemo(
    () => buildTokenOptionsForChain(resolvedChainId, true, true),
    [resolvedChainId]
  )
  const filteredVaultOptions = useMemo(
    () => getStrategyVaultTokensForChain(resolvedChainId).map((t) => ({ value: t.address, label: t.name || t.symbol })),
    [resolvedChainId]
  )
  
  // Debug logging for imports
  debugLog('[Import Debug]', { chainId: resolvedChainId, platform: Object.keys(platform || {}) })

  // Sanity check: read Balancer V3 Vault address from diamond via BalancerV3VaultAwareFacet
  const { data: diamondVaultAddr, error: diamondVaultErr } = useReadContract({
    address: (routerAddress ?? routerSpenderAddress) as `0x${string}`,
    abi: [
      {
        inputs: [],
        name: 'balV3Vault',
        outputs: [{ name: '', type: 'address' }],
        stateMutability: 'view',
        type: 'function'
      }
    ],
    functionName: 'balV3Vault',
    args: [],
      query: { 
        enabled: isConnected && routerHasBytecode === true && !!(routerAddress ?? routerSpenderAddress),
        refetchInterval: false,
        refetchOnWindowFocus: false,
        refetchOnMount: false
      }
  })

  useEffect(() => {
    if (diamondVaultAddr) {
      debugLog('[Diamond Sanity] balV3Vault():', diamondVaultAddr)
    }
    if (diamondVaultErr) {
      debugLog('[Diamond Sanity] balV3Vault() read error:', diamondVaultErr)
    }
  }, [diamondVaultAddr, diamondVaultErr])

  // Core state
  const [selectedPool, setSelectedPool] = useState<'' | Address>('')
  const [tokenIn, setTokenIn] = useState('')
  const [tokenOut, setTokenOut] = useState('')
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

  // Approval mode: 'explicit' = ERC20 -> Permit2 -> Router (current), 'signed' = Permit2 signature (gasless)
  const [approvalMode, setApprovalMode] = useState<'explicit' | 'signed'>('signed')
  const [approvalModeInitialized, setApprovalModeInitialized] = useState(false)
  const [showApprovalSettings, setShowApprovalSettings] = useState(false)
  
  // Approval spending limit custom inputs
  const [permit2SpendingLimit, setPermit2SpendingLimit] = useState(MAX_UINT160.toString())
  const [routerSpendingLimit, setRouterSpendingLimit] = useState('')
  const [routerSpendingLimitDirty, setRouterSpendingLimitDirty] = useState(false)

  useEffect(() => {
    const validPoolValues = new Set(poolOptions.map((option) => option.value.toLowerCase()))
    const validTokenValues = new Set(tokenOptions.map((option) => String(option.value)))
    const validVaultValues = new Set(filteredVaultOptions.map((option) => String(option.value).toLowerCase()))

    if (selectedPool && !validPoolValues.has(selectedPool.toLowerCase())) {
      const preserveWethPoolSelection =
        !!weth9Address &&
        (tokenIn === 'ETH' || tokenIn === 'WETH9' || tokenOut === 'ETH' || tokenOut === 'WETH9' || useEthIn || useEthOut) &&
        validPoolValues.has(weth9Address.toLowerCase())

      setSelectedPool(preserveWethPoolSelection ? (weth9Address as Address) : '')
    }

    if (tokenIn && !validTokenValues.has(String(tokenIn))) {
      setTokenIn('')
      setUseEthIn(false)
    }

    if (tokenOut && !validTokenValues.has(String(tokenOut))) {
      setTokenOut('')
      setUseEthOut(false)
    }

    if (selectedVaultIn && !validVaultValues.has(selectedVaultIn.toLowerCase())) {
      setSelectedVaultIn('')
      setUseTokenInVault(false)
    }

    if (selectedVaultOut && !validVaultValues.has(selectedVaultOut.toLowerCase())) {
      setSelectedVaultOut('')
      setUseTokenOutVault(false)
    }
  }, [
    filteredVaultOptions,
    poolOptions,
    selectedPool,
    selectedVaultIn,
    selectedVaultOut,
    tokenIn,
    tokenOptions,
    tokenOut,
    useEthIn,
    useEthOut,
    weth9Address,
  ])

  // Load approval mode from localStorage on mount
  useEffect(() => {
    try {
      const saved = localStorage.getItem('swap-approval-mode')
      if (saved === 'explicit' || saved === 'signed') {
        setApprovalMode(saved)
      }
    } catch {}
    setApprovalModeInitialized(true)
  }, [])

  // Save approval mode to localStorage when changed
  const handleApprovalModeChange = (mode: 'explicit' | 'signed') => {
    setApprovalMode(mode)
    try {
      localStorage.setItem('swap-approval-mode', mode)
    } catch {}
  }

  // Derived state
  const senderArg = useMemo(() => (address ?? ZERO_ADDR) as `0x${string}`,
    [address]
  )

  const tokenInAddress = useMemo(() => {
    if (useEthIn || tokenIn === 'ETH') return weth9Address
    if (!tokenIn) return null
    return resolveTokenAddressFromOptionForChain(resolvedChainId, tokenIn as TokenOption['value'])
  }, [weth9Address, resolvedChainId, useEthIn, tokenIn])

  const tokenOutAddress = useMemo(() => {
    if (useEthOut || tokenOut === 'ETH') return weth9Address
    if (!tokenOut) return null
    return resolveTokenAddressFromOptionForChain(resolvedChainId, tokenOut as TokenOption['value'])
  }, [weth9Address, resolvedChainId, useEthOut, tokenOut])

  const rawPoolAddress = useMemo(() => {
    if (!selectedPool) return null
    return selectedPool as `0x${string}`
  }, [selectedPool])

  // ETH<->WETH wrap/unwrap is implemented in the router as a special-case that is ONLY
  // triggered when the caller selects the WETH sentinel pool (pool == WETH).
  // The UI should not auto-select that pool; users choose the pool explicitly.
  const isWethSentinelWrapUnwrapFlow = useMemo(() => {
    if (!weth9Address) return false
    if (!rawPoolAddress) return false
    if (!tokenInAddress || !tokenOutAddress) return false
    const bothWeth = tokenInAddress.toLowerCase() === weth9Address.toLowerCase() && tokenOutAddress.toLowerCase() === weth9Address.toLowerCase()
    const selectedWethPool = rawPoolAddress.toLowerCase() === weth9Address.toLowerCase()
    return selectedWethPool && bothWeth && (useEthIn || useEthOut)
  }, [weth9Address, rawPoolAddress, tokenInAddress, tokenOutAddress, useEthIn, useEthOut])

  const effectiveUseTokenInVault = useMemo(
    () => (isWethSentinelWrapUnwrapFlow ? false : useTokenInVault),
    [isWethSentinelWrapUnwrapFlow, useTokenInVault]
  )
  const effectiveUseTokenOutVault = useMemo(
    () => (isWethSentinelWrapUnwrapFlow ? false : useTokenOutVault),
    [isWethSentinelWrapUnwrapFlow, useTokenOutVault]
  )

  // IMPORTANT: Never override user-selected pool.
  const poolAddress = useMemo(() => {
    return rawPoolAddress
  }, [rawPoolAddress])

  useEffect(() => {
    if (!isWethSentinelWrapUnwrapFlow) return

    // Vault routes are not compatible with sentinel wrap/unwrap.
    if (useTokenInVault) setUseTokenInVault(false)
    if (useTokenOutVault) setUseTokenOutVault(false)
    if (selectedVaultIn) setSelectedVaultIn('')
    if (selectedVaultOut) setSelectedVaultOut('')
  }, [isWethSentinelWrapUnwrapFlow, useTokenInVault, useTokenOutVault, selectedVaultIn, selectedVaultOut])

  const tokenInVaultAddress = useMemo(() => {
    if (!effectiveUseTokenInVault || !selectedVaultIn) {
      return '0x0000000000000000000000000000000000000000' as `0x${string}`
    }
    return selectedVaultIn
  }, [effectiveUseTokenInVault, selectedVaultIn])

  const tokenOutVaultAddress = useMemo(() => {
    if (!effectiveUseTokenOutVault || !selectedVaultOut) return '0x0000000000000000000000000000000000000000' as `0x${string}`
    return selectedVaultOut
  }, [effectiveUseTokenOutVault, selectedVaultOut])

  const exactAmountInField = useMemo(() => {
    if (!amountIn || !tokenInAddress) return undefined
    try {
      const decimals = getTokenDecimalsByAddressForChain(resolvedChainId, tokenInAddress)
      const result = parseUnits(amountIn, decimals)

      debugLog('[Amount Conversion Debug]', {
        field: 'amountIn',
        amountIn,
        tokenIn,
        tokenInAddress,
        decimals,
        result: result.toString(),
        resultBigInt: result
      })

      return result
    } catch (error) {
      debugError('[Amount Conversion Error]', error)
      return undefined
    }
  }, [amountIn, resolvedChainId, tokenInAddress, tokenIn])

  const exactAmountOutField = useMemo(() => {
    if (!amountOut || !tokenOutAddress) return undefined
    try {
      const decimals = getTokenDecimalsByAddressForChain(resolvedChainId, tokenOutAddress)
      const result = parseUnits(amountOut, decimals)

      debugLog('[Amount Conversion Debug]', {
        field: 'amountOut',
        amountOut,
        tokenOut,
        tokenOutAddress,
        decimals,
        result: result.toString(),
        resultBigInt: result
      })

      return result
    } catch (error) {
      debugError('[Amount Conversion Error]', error)
      return undefined
    }
  }, [amountOut, resolvedChainId, tokenOutAddress, tokenOut])

  useEffect(() => {
    if (routerSpendingLimitDirty) return
    if (exactAmountInField === undefined) {
      setRouterSpendingLimit('')
      return
    }
    setRouterSpendingLimit(exactAmountInField.toString())
  }, [exactAmountInField, routerSpendingLimitDirty])

  const getDeadline = useCallback(() => {
    return BigInt(Math.floor(Date.now() / 1000) + 3600) // 1 hour from now
  }, [])

  // Derive pool type from selected option
  const poolType: PoolType = useMemo(() => {
    return resolvePoolTypeForChain(resolvedChainId, poolAddress)
  }, [resolvedChainId, poolAddress])

  // Build final args for preview/execute (single source of truth)
  const builtExactIn = useMemo(() => buildExactInArgs({
    poolType,
    poolAddress,
    tokenInAddress: tokenInAddress || null,
    tokenOutAddress: tokenOutAddress || null,
    tokenInVaultAddress: tokenInVaultAddress,
    tokenOutVaultAddress: tokenOutVaultAddress,
    exactAmountIn: exactAmountInField,
    sender: senderArg,
    useTokenInVault: effectiveUseTokenInVault,
    useTokenOutVault: effectiveUseTokenOutVault
  }), [poolType, poolAddress, tokenInAddress, tokenOutAddress, tokenInVaultAddress, tokenOutVaultAddress, exactAmountInField, senderArg, effectiveUseTokenInVault, effectiveUseTokenOutVault])

  const builtExactOut = useMemo(() => buildExactOutArgs({
    poolType,
    poolAddress,
    tokenInAddress: tokenInAddress || null,
    tokenOutAddress: tokenOutAddress || null,
    tokenInVaultAddress: tokenInVaultAddress,
    tokenOutVaultAddress: tokenOutVaultAddress,
    exactAmountOut: exactAmountOutField,
    sender: senderArg,
    useTokenInVault: effectiveUseTokenInVault,
    useTokenOutVault: effectiveUseTokenOutVault
  }), [poolType, poolAddress, tokenInAddress, tokenOutAddress, tokenInVaultAddress, tokenOutVaultAddress, exactAmountOutField, senderArg, effectiveUseTokenInVault, effectiveUseTokenOutVault])

  const ready = useMemo(() => {
    const commonConditions = {
      isConnected,
      selectedPool,
      tokenInAddress,
      tokenOutAddress,
      poolAddress
    }

    const commonReady = !!(
      commonConditions.isConnected &&
      commonConditions.selectedPool &&
      commonConditions.tokenInAddress &&
      commonConditions.tokenOutAddress &&
      commonConditions.poolAddress
    )

    const modeReady =
      lastEditedField === 'in'
        ? !!exactAmountInField && builtExactIn.valid
        : !!exactAmountOutField && builtExactOut.valid

    return commonReady && modeReady && routerReady
  }, [isConnected, selectedPool, tokenInAddress, tokenOutAddress, poolAddress, lastEditedField, exactAmountInField, exactAmountOutField, builtExactIn.valid, builtExactOut.valid, routerReady])

  const previewReady = useMemo(() => {
    const commonReady = !!(
      selectedPool &&
      tokenInAddress &&
      tokenOutAddress &&
      poolAddress
    )

    const modeReady =
      lastEditedField === 'in'
        ? !!exactAmountInField && builtExactIn.valid
        : !!exactAmountOutField && builtExactOut.valid

    return commonReady && modeReady
  }, [selectedPool, tokenInAddress, tokenOutAddress, poolAddress, lastEditedField, exactAmountInField, exactAmountOutField, builtExactIn.valid, builtExactOut.valid])

  const previewExactInHookEnabled =
    previewReady && routerHasBytecode === true && lastEditedField === 'in' && builtExactIn.valid
  const previewExactOutHookEnabled =
    previewReady && routerHasBytecode === true && lastEditedField === 'out' && builtExactOut.valid

  debugLog('[Preview Hook Enabled Debug]', {
    ready,
    lastEditedField,
    builtExactInValid: builtExactIn.valid,
    previewExactInHookEnabled,
    exactAmountInField: exactAmountInField?.toString(),
    tokenInAddress,
    tokenOutAddress,
    poolAddress,
    isConnected,
    routerAddress,
    routerHasBytecode,
    routerBytecodeError,
  })

  debugLog('[Final Args Builder ExactIn]', builtExactIn)
  debugLog('[Final Args Builder ExactOut]', builtExactOut)

  const simulatePreviewExactIn = useCallback(
    async (args: NonNullable<BuildArgsOutput['args']>) => {
      if (!publicClient) throw new Error('RPC client unavailable')
      if (!routerAddress || routerHasBytecode !== true) {
        throw new Error('Swap preview unavailable: router is not deployed on this network')
      }

      const previewArgs = toPreviewArgs(args)
      const { result } = await publicClient.simulateContract({
        address: routerAddress,
        abi: balancerV3StandardExchangeRouterExactInQueryFacetAbi,
        functionName: 'querySwapSingleTokenExactIn',
        args: previewArgs,
        account: ZERO_ADDR,
      } as const)

      return result as bigint
    },
    [publicClient, routerAddress, routerHasBytecode]
  )

  const simulatePreviewExactOut = useCallback(
    async (args: NonNullable<BuildArgsOutput['args']>) => {
      if (!publicClient) throw new Error('RPC client unavailable')
      if (!routerAddress || routerHasBytecode !== true) {
        throw new Error('Swap preview unavailable: router is not deployed on this network')
      }

      const previewArgs = toPreviewArgs(args)
      const { result } = await publicClient.simulateContract({
        address: routerAddress,
        abi: balancerV3StandardExchangeRouterExactOutQueryFacetAbi,
        functionName: 'querySwapSingleTokenExactOut',
        args: previewArgs,
        account: ZERO_ADDR,
      } as const)

      return result as bigint
    },
    [publicClient, routerAddress, routerHasBytecode]
  )

  const [previewExactIn, setPreviewExactIn] = useState<bigint | null>(null)
  const [previewExactOut, setPreviewExactOut] = useState<bigint | null>(null)
  const [previewExactInPending, setPreviewExactInPending] = useState(false)
  const [previewExactOutPending, setPreviewExactOutPending] = useState(false)
  const [previewExactInError, setPreviewExactInError] = useState<Error | null>(null)
  const [previewExactOutError, setPreviewExactOutError] = useState<Error | null>(null)

  useEffect(() => {
    if (!previewReady) return
    if (routerHasBytecode !== false) return
    if (!routerSpenderAddress) return

    const suffix = ` Router candidates: ${routerCandidates.join(', ')}`
    const base = 'Swap preview unavailable: router is not deployed on this network.'
    const chainSuffix = rpcChainId !== null ? ` (rpc chainId=${rpcChainId}, wallet chainId=${resolvedChainId})` : ''
    const message = routerBytecodeError
      ? `${base}${chainSuffix} ${routerBytecodeError}. ${suffix}`
      : `${base}${chainSuffix}. ${suffix}`
    const err = new Error(message)
    setPreviewExactInError(err)
    setPreviewExactOutError(err)
  }, [previewReady, routerHasBytecode, routerSpenderAddress, routerBytecodeError, routerCandidates, rpcChainId, resolvedChainId])

  debugLog('[Preview Results]', {
    previewExactIn: previewExactIn?.toString(),
    previewExactOut: previewExactOut?.toString(),
    previewExactInPending,
    previewExactOutPending,
    previewExactInError: previewExactInError?.message,
    previewExactOutError: previewExactOutError?.message
  })

  const tokenInDecimals = useMemo(() => {
    if (!tokenInAddress) return 18
    return getTokenDecimalsByAddressForChain(resolvedChainId, tokenInAddress)
  }, [resolvedChainId, tokenInAddress])

  const tokenOutDecimals = useMemo(() => {
    if (!tokenOutAddress) return 18
    return getTokenDecimalsByAddressForChain(resolvedChainId, tokenOutAddress)
  }, [resolvedChainId, tokenOutAddress])

  const previewExactInKey = useMemo(() => (builtExactIn.args ? buildPreviewKey(toPreviewArgs(builtExactIn.args)) : null), [builtExactIn.args])
  const previewExactOutKey = useMemo(() => (builtExactOut.args ? buildPreviewKey(toPreviewArgs(builtExactOut.args)) : null), [builtExactOut.args])

  const previewDebounceTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const lastCompletedPreviewKeyRef = useRef<string | null>(null)
  const latestDesiredPreviewKeyRef = useRef<string | null>(null)
  const previewRequestSeqRef = useRef(0)

  useEffect(() => {
    if (!previewReady) return

    const isExactIn = lastEditedField === 'in'
    const desiredKeyBase = isExactIn ? previewExactInKey : previewExactOutKey
    const desiredKey = desiredKeyBase ? `${lastEditedField}:${desiredKeyBase}` : null
    latestDesiredPreviewKeyRef.current = desiredKey

    if (isExactIn && !exactAmountInField) return
    if (!isExactIn && !exactAmountOutField) return

    const activeBuilt = isExactIn ? builtExactIn : builtExactOut
    if (!activeBuilt.valid || !desiredKey) return

    if (lastCompletedPreviewKeyRef.current === desiredKey) return

    if (previewDebounceTimerRef.current) {
      clearTimeout(previewDebounceTimerRef.current)
      previewDebounceTimerRef.current = null
    }

    const DEBOUNCE_MS = 450
    previewDebounceTimerRef.current = setTimeout(() => {
      const requestId = ++previewRequestSeqRef.current
      void (async () => {
        try {
          if (isExactIn) {
            setPreviewExactInPending(true)
            setPreviewExactInError(null)

            if (!builtExactIn.args) throw new Error('Missing exact-in args')
            const result = await simulatePreviewExactIn(builtExactIn.args)
            if (latestDesiredPreviewKeyRef.current !== desiredKey || previewRequestSeqRef.current !== requestId) return
            setPreviewExactIn(result)
          } else {
            setPreviewExactOutPending(true)
            setPreviewExactOutError(null)

            if (!builtExactOut.args) throw new Error('Missing exact-out args')
            const result = await simulatePreviewExactOut(builtExactOut.args)
            if (latestDesiredPreviewKeyRef.current !== desiredKey || previewRequestSeqRef.current !== requestId) return
            setPreviewExactOut(result)
          }

          if (latestDesiredPreviewKeyRef.current === desiredKey) {
            lastCompletedPreviewKeyRef.current = desiredKey
          }
        } catch (e) {
          debugError('[Preview Debounce] Refetch failed', e)

          const err = e instanceof Error ? e : new Error('Preview refetch failed')
          if (isExactIn) {
            if (latestDesiredPreviewKeyRef.current !== desiredKey || previewRequestSeqRef.current !== requestId) return
            setPreviewExactInError(err)
            setPreviewExactIn(null)
          } else {
            if (latestDesiredPreviewKeyRef.current !== desiredKey || previewRequestSeqRef.current !== requestId) return
            setPreviewExactOutError(err)
            setPreviewExactOut(null)
          }
        } finally {
          if (isExactIn) {
            if (latestDesiredPreviewKeyRef.current !== desiredKey || previewRequestSeqRef.current !== requestId) return
            setPreviewExactInPending(false)
          } else {
            if (latestDesiredPreviewKeyRef.current !== desiredKey || previewRequestSeqRef.current !== requestId) return
            setPreviewExactOutPending(false)
          }
        }
      })()
    }, DEBOUNCE_MS)

    return () => {
      if (previewDebounceTimerRef.current) {
        clearTimeout(previewDebounceTimerRef.current)
        previewDebounceTimerRef.current = null
      }
    }
  }, [
    previewReady,
    lastEditedField,
    exactAmountInField,
    exactAmountOutField,
    builtExactIn,
    builtExactOut,
    previewExactInKey,
    previewExactOutKey,
    simulatePreviewExactIn,
    simulatePreviewExactOut
  ])

  useEffect(() => {
    if (lastEditedField === 'in' && previewExactIn !== null && exactAmountInField) {
      const formatted = formatUnits(previewExactIn, tokenOutDecimals)
      if (formatted !== amountOut) {
        setAmountOut(formatted)
      }
    }
  }, [lastEditedField, previewExactIn, exactAmountInField, tokenOutDecimals, amountOut])

  useEffect(() => {
    if (lastEditedField === 'out' && previewExactOut !== null && exactAmountOutField) {
      const formatted = formatUnits(previewExactOut, tokenInDecimals)
      if (formatted !== amountIn) {
        setAmountIn(formatted)
      }
    }
  }, [lastEditedField, previewExactOut, exactAmountOutField, tokenInDecimals, amountIn])

  const amountInDisplay = useMemo(() => {
    if (lastEditedField !== 'out') return amountIn
    if (!exactAmountOutField) return amountIn
    if (previewExactOut === null) return amountIn
    return formatUnits(previewExactOut, tokenInDecimals)
  }, [lastEditedField, amountIn, exactAmountOutField, previewExactOut, tokenInDecimals])

  const amountOutDisplay = useMemo(() => {
    if (lastEditedField !== 'in') return amountOut
    if (!exactAmountInField) return amountOut
    if (previewExactIn === null) return amountOut
    return formatUnits(previewExactIn, tokenOutDecimals)
  }, [lastEditedField, amountOut, exactAmountInField, previewExactIn, tokenOutDecimals])

  const previewPending = lastEditedField === 'in' ? previewExactInPending : previewExactOutPending
  const previewError = lastEditedField === 'in' ? previewExactInError : previewExactOutError

  // Enhanced debug logging for preview hook
  useEffect(() => {
    debugLog('[Preview Hook Debug]', {
      lastEditedField,
      builtExactIn,
      builtExactOut,
      previewExactIn: (previewExactIn as unknown as bigint | undefined)?.toString(),
      previewExactOut: (previewExactOut as unknown as bigint | undefined)?.toString(),
      previewExactInPending,
      previewExactOutPending,
      previewExactInError,
      previewExactOutError,
      hookEnabled: { previewExactInHookEnabled, previewExactOutHookEnabled },
      routerAddress
    })

    if (builtExactIn.valid && builtExactIn.args) {
      const [pool, tokenInArg, tokenInVault, tokenOutArg, tokenOutVault, amountInArg, sender, userData] = builtExactIn.args
      debugLog('[Router Query Arguments ExactIn]', {
        pool,
        tokenIn: tokenInArg,
        tokenInVault,
        tokenOut: tokenOutArg,
        tokenOutVault,
        exactAmountIn: amountInArg.toString(),
        sender,
        userData
      })
    }

    if (builtExactOut.valid && builtExactOut.args) {
      const [pool, tokenInArg, tokenInVault, tokenOutArg, tokenOutVault, amountOutArg, sender, userData] = builtExactOut.args
      debugLog('[Router Query Arguments ExactOut]', {
        pool,
        tokenIn: tokenInArg,
        tokenInVault,
        tokenOut: tokenOutArg,
        tokenOutVault,
        exactAmountOut: amountOutArg.toString(),
        sender,
        userData
      })
    }
  }, [
    lastEditedField,
    builtExactIn,
    builtExactOut,
    previewExactIn,
    previewExactOut,
    previewExactInPending,
    previewExactOutPending,
    previewExactInError,
    previewExactOutError,
    previewExactInHookEnabled,
    previewExactOutHookEnabled,
    routerAddress
  ])

  const minOut = useMemo(() => {
    if (lastEditedField !== 'in' || previewExactIn === null) return undefined
    const slippageMultiplier = BigInt(1000 - slippage * 10) // Convert percentage to basis points
    return (previewExactIn * slippageMultiplier) / BigInt(1000)
  }, [lastEditedField, previewExactIn, slippage])

  const maxIn = useMemo(() => {
    if (lastEditedField !== 'out' || previewExactOut === null) return undefined
    const slippageMultiplier = BigInt(1000 + slippage * 10) // Convert percentage to basis points
    return (previewExactOut * slippageMultiplier) / BigInt(1000)
  }, [lastEditedField, previewExactOut, slippage])

  const requiredAmountIn = useMemo(() => {
    if (useEthIn) return undefined
    return lastEditedField === 'in' ? exactAmountInField : maxIn
  }, [useEthIn, lastEditedField, exactAmountInField, maxIn])

  // Route pattern detection - Based on PROJECT_PLAN.md route table
  const routePattern = useMemo(() => {
    if (!selectedPool || !tokenInAddress || !tokenOutAddress) return null

    // Make wrap/unwrap explicit in the UI when using the WETH sentinel pool.
    if (isWethSentinelWrapUnwrapFlow && weth9Address && poolAddress && poolAddress.toLowerCase() === weth9Address.toLowerCase()) {
      return 'WETH Wrap/Unwrap'
    }

    const pt = resolvePoolTypeForChain(resolvedChainId, poolAddress)
    const isVaultPassThrough = effectiveUseTokenInVault && effectiveUseTokenOutVault && pt === 'vault'
    const isVaultDeposit = effectiveUseTokenInVault && !effectiveUseTokenOutVault && pt === 'vault' && isStrategyVaultTokenForChain(resolvedChainId, tokenOutAddress)
    const isVaultWithdrawal = !effectiveUseTokenInVault && effectiveUseTokenOutVault && pt === 'vault' && isStrategyVaultTokenForChain(resolvedChainId, tokenInAddress)
    const isVaultDepositWithExternalSwap = effectiveUseTokenInVault && !effectiveUseTokenOutVault && pt === 'balancer'
    const isExternalSwapWithVaultWithdrawal = !effectiveUseTokenInVault && effectiveUseTokenOutVault && pt === 'balancer'
    const isVaultToVault =
      effectiveUseTokenInVault &&
      effectiveUseTokenOutVault &&
      pt === 'vault' &&
      isStrategyVaultTokenForChain(resolvedChainId, tokenInAddress) &&
      isStrategyVaultTokenForChain(resolvedChainId, tokenOutAddress)
    switch(pt) {
      case 'balancer':
        if (isVaultDepositWithExternalSwap) return 'Vault Deposit + Balancer Swap'
        if (isExternalSwapWithVaultWithdrawal) return 'Balancer Swap + Vault Withdrawal'
        return 'Direct Balancer V3 Swap'
      case 'vault':
        if (useEthIn || useEthOut) return 'Strategy Vault with ETH'
        if (isVaultPassThrough) return 'Strategy Vault Pass-Through'
        if (isVaultDeposit) return 'Strategy Vault Deposit'
        if (isVaultWithdrawal) return 'Strategy Vault Withdrawal'
        if (isVaultToVault) return 'Vault-to-Vault Cycle'
        return 'Strategy Vault Operation'
      default:
        return null
    }
  }, [selectedPool, tokenInAddress, tokenOutAddress, useEthIn, useEthOut, effectiveUseTokenInVault, effectiveUseTokenOutVault, poolAddress, resolvedChainId, isWethSentinelWrapUnwrapFlow, weth9Address])

  // Approval state management (moved above allowance hooks for scope keys)
  const [approvalState, setApprovalState] = useState<'idle' | 'approving' | 'success' | 'error'>('idle')
  const [approvalError, setApprovalError] = useState<string>('')
  const [allowancesReady, setAllowancesReady] = useState<boolean>(false)
  const [lastSwapTxHash, setLastSwapTxHash] = useState<`0x${string}` | null>(null)
  const [lastSwapEthDeltaWei, setLastSwapEthDeltaWei] = useState<bigint | null>(null)
  const [lastSwapEthNetReceivedWei, setLastSwapEthNetReceivedWei] = useState<bigint | null>(null)
  const [lastSwapReceiptStatus, setLastSwapReceiptStatus] = useState<'success' | 'reverted' | 'pending' | null>(null)
  const [lastSwapHookDebug, setLastSwapHookDebug] = useState<any | null>(null)
  const [lastSwapSentinelDebug, setLastSwapSentinelDebug] = useState<any | null>(null)

  // Accurate quote state for signed approval mode
  const [accurateQuote, setAccurateQuote] = useState<bigint | null>(null)
  const [accurateQuoteLoading, setAccurateQuoteLoading] = useState(false)
  const [accurateQuoteError, setAccurateQuoteError] = useState<string>('')
  const [accurateQuoteSignaturePath, setAccurateQuoteSignaturePath] = useState<'typedData' | null>(null)
  // Store the signed permit for reuse in swap execution
  const [storedPermitSignature, setStoredPermitSignature] = useState<{
    signature: `0x${string}`
    deadline: bigint
    nonce: bigint
    isExactIn: boolean
    intentKey: string
  } | null>(null)

  // Reset allowancesReady when inputs that affect approval requirements change
  useEffect(() => {
    setAllowancesReady(false)
  }, [address, tokenInAddress, requiredAmountIn, poolAddress, approvalMode])

  const activePermitIntentKey = useMemo(() => {
    if (approvalMode !== 'signed' || useEthIn) return null
    if (!address) return null

    const wethIsEth = useEthIn || useEthOut

    if (lastEditedField === 'in') {
      if (!builtExactIn.valid || !builtExactIn.args || !exactAmountInField) return null
      const args = builtExactIn.args
      const pool = args[0]
      const tokenInArg = args[1]
      const tokenInVault = args[2]
      const tokenOutArg = args[3]
      const tokenOutVault = args[4]
      const amountGiven = args[5]
      const limit = minOut ?? BigInt(0)
      const userDataBytes = args[7]
      const userDataHash = keccak256(userDataBytes)

      return buildPermitIntentKey({
        chainId: resolvedChainId,
        owner: address,
        spender: routerSpenderAddress as `0x${string}`,
        pool,
        tokenIn: tokenInArg,
        tokenInVault,
        tokenOut: tokenOutArg,
        tokenOutVault,
        amountGiven,
        limit,
        wethIsEth,
        userDataHash,
        isExactIn: true,
      })
    }

    if (lastEditedField === 'out') {
      if (!builtExactOut.valid || !builtExactOut.args || !exactAmountOutField) return null
      const args = builtExactOut.args
      const pool = args[0]
      const tokenInArg = args[1]
      const tokenInVault = args[2]
      const tokenOutArg = args[3]
      const tokenOutVault = args[4]
      const amountGiven = args[5]
      const limit = maxIn ?? BigInt(0)
      const userDataBytes = args[7]
      const userDataHash = keccak256(userDataBytes)

      return buildPermitIntentKey({
        chainId: resolvedChainId,
        owner: address,
        spender: routerSpenderAddress as `0x${string}`,
        pool,
        tokenIn: tokenInArg,
        tokenInVault,
        tokenOut: tokenOutArg,
        tokenOutVault,
        amountGiven,
        limit,
        wethIsEth,
        userDataHash,
        isExactIn: false,
      })
    }

    return null
  }, [
    approvalMode,
    routePattern,
    useEthIn,
    useEthOut,
    address,
    lastEditedField,
    builtExactIn,
    builtExactOut,
    exactAmountInField,
    exactAmountOutField,
    minOut,
    maxIn,
    resolvedChainId,
    routerSpenderAddress,
  ])

  useEffect(() => {
    if (!storedPermitSignature) return
    if (!activePermitIntentKey || storedPermitSignature.intentKey !== activePermitIntentKey) {
      setStoredPermitSignature(null)
      setAccurateQuote(null)
      setAccurateQuoteError('')
    }
  }, [storedPermitSignature, activePermitIntentKey])

  // Generic ERC20 hooks for all token operations - NO TOKEN-SPECIFIC HOOKS
  const { data: tokenBalance, refetch: refetchBalance } = useReadContract({
    address: tokenInAddress as `0x${string}`,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [address as `0x${string}`],
    query: { 
      enabled: !!tokenInAddress && !!address && !(useEthIn || tokenIn === 'ETH'),
      refetchInterval: false,
      refetchOnWindowFocus: false,
      refetchOnMount: false
    }
  })

  const [nativeBalance, setNativeBalance] = useState<bigint | null>(null)
  const [nativeBalanceError, setNativeBalanceError] = useState('')
  const isNativeTokenIn = useMemo(() => useEthIn || tokenIn === 'ETH', [useEthIn, tokenIn])

  const refetchNativeBalance = useCallback(async () => {
    if (!publicClient) return
    if (!address) return

    try {
      setNativeBalanceError('')
      const bal = await publicClient.getBalance({ address: address as `0x${string}` })
      setNativeBalance(bal)
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Failed to fetch native balance'
      setNativeBalanceError(msg)
      setNativeBalance(null)
    }
  }, [publicClient, address])

  useEffect(() => {
    if (!isNativeTokenIn) return
    void refetchNativeBalance()
  }, [isNativeTokenIn, refetchNativeBalance])

  const { data: tokenAllowance, refetch: refetchAllowance } = useReadContract({
    address: tokenInAddress as `0x${string}`,
    abi: erc20Abi,
    functionName: 'allowance',
    args: [address as `0x${string}`, (permit2Address ?? ZERO_ADDR) as `0x${string}`],
    scopeKey: `tokenAllowance:${tokenInAddress}:${address}:${approvalState}`,
    query: { 
      enabled: !!tokenInAddress && !!address && !!permit2Address, 
      staleTime: 0, 
      gcTime: 0, 
      refetchInterval: false,
      refetchOnWindowFocus: false,
      refetchOnMount: false,
      refetchOnReconnect: false
    }
  })

  // Debug logging for allowance data
  useEffect(() => {
    if (tokenAllowance !== undefined) {
      debugLog('[Token Allowance Hook]', {
        tokenAllowance: tokenAllowance.toString(),
        tokenAllowanceType: typeof tokenAllowance,
        tokenInAddress,
        address
      })
    }
  }, [tokenAllowance, tokenInAddress, address])

  const { data: permit2Allowance, refetch: refetchPermit2Allowance } = useReadContract({
    address: (permit2Address ?? ZERO_ADDR) as `0x${string}`,
    abi: [
      {
        inputs: [
          { name: 'owner', type: 'address' },
          { name: 'token', type: 'address' },
          { name: 'spender', type: 'address' }
        ],
        name: 'allowance',
        outputs: [
          { name: 'amount', type: 'uint160' },
          { name: 'expiration', type: 'uint48' },
          { name: 'nonce', type: 'uint48' }
        ],
        stateMutability: 'view',
        type: 'function'
      }
    ],
    functionName: 'allowance',
    args: [address as `0x${string}`, tokenInAddress as `0x${string}`, routerSpenderAddress as `0x${string}`],
    scopeKey: `permit2Allowance:${tokenInAddress}:${address}:${approvalState}`,
    query: { 
      enabled: !!permit2Address && !!tokenInAddress && !!address && !!routerSpenderAddress, 
      staleTime: 0, 
      gcTime: 0, 
      refetchInterval: false,
      refetchOnWindowFocus: false,
      refetchOnMount: false,
      refetchOnReconnect: false
    }
  })

  // Permit2 nonce hook for EIP-712 signature
  const { data: permit2NonceBitmap, refetch: refetchPermit2Nonce } = useReadContract({
    address: (permit2Address ?? ZERO_ADDR) as `0x${string}`,
    abi: [
      {
        inputs: [
          { name: 'owner', type: 'address' },
          { name: 'wordIndex', type: 'uint256' }
        ],
        name: 'nonceBitmap',
        outputs: [{ name: 'bitmap', type: 'uint256' }],
        stateMutability: 'view',
        type: 'function'
      }
    ],
    functionName: 'nonceBitmap',
    args: [address as `0x${string}`, BigInt(0)], // Start with word index 0
    scopeKey: `permit2Nonce:${address}`,
    query: {
      enabled: !!permit2Address && !!address,
      staleTime: 0,
      gcTime: 0,
      refetchInterval: false,
      refetchOnWindowFocus: false,
      refetchOnMount: false,
      refetchOnReconnect: false
    }
  })

  // Debug logging for permit2 allowance data
  useEffect(() => {
    if (permit2Allowance !== undefined) {
      debugLog('[Permit2 Allowance Hook]', {
        permit2Allowance: permit2Allowance[0]?.toString(),
        permit2AllowanceType: typeof permit2Allowance[0],
        permit2AllowanceFull: permit2Allowance,
        tokenInAddress,
        address,
        routerAddress: routerSpenderAddress
      })
    }
  }, [permit2Allowance, tokenInAddress, address, routerSpenderAddress])

  // Generic swap execution hook - NO TOKEN-SPECIFIC HOOKS
  const { writeContract: writeSwap, writeContractAsync: writeSwapAsync, isPending: swapPending } = useWriteContract()
  const ensureSpendingLimits = useCallback(
    async (amountNeeded: bigint) => {
      if (useEthIn) return
      if (!tokenInAddress || !address) throw new Error('Wallet/token not ready')
      if (!publicClient) throw new Error('RPC client unavailable')
      if (!permit2Address) throw new Error('Permit2 not deployed')
      if (!routerAddress || routerHasBytecode !== true) throw new Error('Router not deployed')
      if (rpcChainId !== null && rpcChainId !== resolvedChainId) throw new Error(`RPC network mismatch (wallet chainId=${resolvedChainId}, rpc chainId=${rpcChainId})`)
      if (amountNeeded <= BigInt(0)) return

      // Always read latest allowances from chain (avoid stale/cached UI state)
      const tokenAllowanceNow = (await publicClient.readContract({
        address: tokenInAddress as `0x${string}`,
        abi: erc20Abi,
        functionName: 'allowance',
        args: [address as `0x${string}`, permit2Address]
      })) as bigint

      const permit2AllowanceNow = (await publicClient.readContract({
        address: permit2Address,
        abi: [
          {
            inputs: [
              { name: 'owner', type: 'address' },
              { name: 'token', type: 'address' },
              { name: 'spender', type: 'address' }
            ],
            name: 'allowance',
            outputs: [
              { name: 'amount', type: 'uint160' },
              { name: 'expiration', type: 'uint48' },
              { name: 'nonce', type: 'uint48' }
            ],
            stateMutability: 'view',
            type: 'function'
          }
        ],
        functionName: 'allowance',
        args: [
          address as `0x${string}`,
          tokenInAddress as `0x${string}`,
          routerAddress
        ]
      })) as readonly [bigint, number, number]

      debugLog('[Spending Limits] Snapshot', {
        tokenAllowanceToPermit2: tokenAllowanceNow.toString(),
        permit2AllowanceToRouter: permit2AllowanceNow[0].toString(),
        amountNeeded: amountNeeded.toString()
      })

      // Step 1: Ensure ERC20 allowance (token -> Permit2)
      if (tokenAllowanceNow < amountNeeded) {
        debugLog('[Spending Limits] Increasing ERC20 allowance to Permit2', {
          tokenAllowanceNow: tokenAllowanceNow.toString(),
          amountNeeded: amountNeeded.toString()
        })

        // Some tokens require resetting allowance to 0 before increasing.
        // Try direct approve first, fall back to 0->amount if it fails.
        try {
          const hash = await writeSwapAsync({
            address: tokenInAddress as `0x${string}`,
            abi: erc20Abi,
            functionName: 'approve',
            args: [permit2Address, amountNeeded]
          })
          await publicClient.waitForTransactionReceipt({ hash })
        } catch (e) {
          debugError('[Spending Limits] ERC20 approve failed; trying reset-to-zero flow', e)
          const hash0 = await writeSwapAsync({
            address: tokenInAddress as `0x${string}`,
            abi: erc20Abi,
            functionName: 'approve',
            args: [permit2Address, BigInt(0)]
          })
          await publicClient.waitForTransactionReceipt({ hash: hash0 })
          const hash1 = await writeSwapAsync({
            address: tokenInAddress as `0x${string}`,
            abi: erc20Abi,
            functionName: 'approve',
            args: [permit2Address, amountNeeded]
          })
          await publicClient.waitForTransactionReceipt({ hash: hash1 })
        }
      }

      // Step 2: Ensure Permit2 allowance (Permit2 -> Router)
      if (permit2AllowanceNow[0] < amountNeeded) {
        debugLog('[Spending Limits] Increasing Permit2 allowance to Router', {
          permit2AllowanceNow: permit2AllowanceNow[0].toString(),
          amountNeeded: amountNeeded.toString()
        })

        const threeDaysSecs = 3 * 24 * 60 * 60
        const expiration = Math.floor(Date.now() / 1000) + threeDaysSecs
        const hash = await writeSwapAsync({
          address: permit2Address,
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
          args: [
            tokenInAddress as `0x${string}`,
            routerAddress,
            amountNeeded,
            expiration
          ]
        })
        await publicClient.waitForTransactionReceipt({ hash })
      }

      // Refresh UI hooks best-effort (don’t block swapping on cache)
      try {
        await Promise.all([refetchAllowance(), refetchPermit2Allowance()])
      } catch {
        // ignore
      }
    },
    [
      useEthIn,
      tokenInAddress,
      address,
      publicClient,
      routerAddress,
      routerHasBytecode,
      rpcChainId,
      resolvedChainId,
      permit2Address,
      writeSwapAsync,
      refetchAllowance,
      refetchPermit2Allowance
    ]
  )

  // Calculate the effective amount in - the maximum of entered amount or previewed amount
  // This ensures we check approval against the worst-case scenario
  const effectiveAmountIn = useMemo(() => {
    if (useEthIn) return undefined
    const entered = exactAmountInField ?? BigInt(0)
    const previewed = maxIn ?? BigInt(0)
    return entered > previewed ? entered : previewed
  }, [useEthIn, exactAmountInField, maxIn])

  // Separate approval checks for each step
  const needsTokenApproval = useMemo(() => {
    if (useEthIn) return false
    if (!effectiveAmountIn || effectiveAmountIn <= BigInt(0)) return false
    if (tokenAllowance === undefined || tokenAllowance === null) return false
    
    // No buffer needed - exact amount is sufficient
    const sufficient = tokenAllowance >= effectiveAmountIn
    
    debugLog('[Token Approval Check]', {
      effectiveAmountIn: effectiveAmountIn.toString(),
      tokenAllowance: tokenAllowance.toString(),
      sufficient,
      needsApproval: !sufficient
    })
    
    return !sufficient
  }, [useEthIn, effectiveAmountIn, tokenAllowance])

  const needsPermit2Approval = useMemo(() => {
    if (useEthIn) return false
    if (!effectiveAmountIn || effectiveAmountIn <= BigInt(0)) return false
    if (permit2Allowance === undefined || permit2Allowance === null) return false
    
    // No buffer needed - exact amount is sufficient
    const sufficient = permit2Allowance[0] >= effectiveAmountIn
    
    debugLog('[Permit2 Approval Check]', {
      effectiveAmountIn: effectiveAmountIn.toString(),
      permit2Allowance: permit2Allowance[0].toString(),
      sufficient,
      needsApproval: !sufficient
    })
    
    return !sufficient
  }, [useEthIn, effectiveAmountIn, permit2Allowance])

  const effectiveApprovalMode = useMemo<'explicit' | 'signed'>(() => {
    return approvalMode
  }, [approvalMode])

  // Overall approval needed - mode dependent
  // Signed mode: only need Token→Permit2 (we use EIP-712 signatures for the swap)
  // Explicit mode: need both Token→Permit2 AND Permit2→Router
  const needsApproval = useMemo(() => {
    const needsAny = effectiveApprovalMode === 'signed'
      ? needsTokenApproval  // Signed mode: only check token approval
      : needsTokenApproval || needsPermit2Approval  // Explicit mode: check both
    
    debugLog('[Overall Approval Check]', {
      approvalMode,
      effectiveApprovalMode,
      needsTokenApproval,
      needsPermit2Approval,
      needsAny,
      routePattern
    })
    
    return needsAny
  }, [approvalMode, effectiveApprovalMode, needsTokenApproval, needsPermit2Approval, routePattern])

  const showTokenToPermit2Controls = useMemo(() => {
    if (useEthIn) return false
    if (!requiredAmountIn || requiredAmountIn <= BigInt(0)) return false
    if (tokenAllowance === undefined || tokenAllowance === null) return false
    return tokenAllowance < requiredAmountIn
  }, [useEthIn, requiredAmountIn, tokenAllowance])

  // Handlers
  const handlePreview = useCallback(() => {
    debugLog('[Handle Preview] Manual preview refresh triggered')
    const isExactIn = lastEditedField === 'in'
    const desiredKeyBase = isExactIn ? previewExactInKey : previewExactOutKey
    const desiredKey = desiredKeyBase ? `${lastEditedField}:${desiredKeyBase}` : null
    latestDesiredPreviewKeyRef.current = desiredKey

    const requestId = ++previewRequestSeqRef.current

    void (async () => {
      try {
        if (isExactIn) {
          debugLog('[Handle Preview] Built args (ExactIn):', builtExactIn)
          if (!builtExactIn.valid || !builtExactIn.args || !desiredKey) {
            debugLog('[Handle Preview] Cannot fetch preview (ExactIn) - missing required values', builtExactIn.missing)
            return
          }

          setPreviewExactInPending(true)
          setPreviewExactInError(null)
          const result = await simulatePreviewExactIn(builtExactIn.args)
          if (latestDesiredPreviewKeyRef.current !== desiredKey || previewRequestSeqRef.current !== requestId) return
          setPreviewExactIn(result)
          lastCompletedPreviewKeyRef.current = desiredKey
          return
        }

        debugLog('[Handle Preview] Built args (ExactOut):', builtExactOut)
        if (!builtExactOut.valid || !builtExactOut.args || !desiredKey) {
          debugLog('[Handle Preview] Cannot fetch preview (ExactOut) - missing required values', builtExactOut.missing)
          return
        }

        setPreviewExactOutPending(true)
        setPreviewExactOutError(null)
        const result = await simulatePreviewExactOut(builtExactOut.args)
        if (latestDesiredPreviewKeyRef.current !== desiredKey || previewRequestSeqRef.current !== requestId) return
        setPreviewExactOut(result)
        lastCompletedPreviewKeyRef.current = desiredKey
      } catch (e) {
        debugError('[Handle Preview] Preview failed', e)
        const err = e instanceof Error ? e : new Error('Preview failed')
        if (isExactIn) {
          if (latestDesiredPreviewKeyRef.current !== desiredKey || previewRequestSeqRef.current !== requestId) return
          setPreviewExactInError(err)
          setPreviewExactIn(null)
        } else {
          if (latestDesiredPreviewKeyRef.current !== desiredKey || previewRequestSeqRef.current !== requestId) return
          setPreviewExactOutError(err)
          setPreviewExactOut(null)
        }
      } finally {
        if (isExactIn) {
          if (latestDesiredPreviewKeyRef.current !== desiredKey || previewRequestSeqRef.current !== requestId) return
          setPreviewExactInPending(false)
        } else {
          if (latestDesiredPreviewKeyRef.current !== desiredKey || previewRequestSeqRef.current !== requestId) return
          setPreviewExactOutPending(false)
        }
      }
    })()
  }, [lastEditedField, builtExactIn, builtExactOut, previewExactInKey, previewExactOutKey, simulatePreviewExactIn, simulatePreviewExactOut])

  // Helper to set allowance with reset-to-zero pattern (needed for some tokens)
  const setTokenAllowance = useCallback(
    async (token: `0x${string}`, spender: `0x${string}`, amount: bigint) => {
      const client = publicClient
      if (!client) throw new Error('RPC client unavailable')
      if (!permit2Address) throw new Error('Permit2 not deployed')

      // Try direct approve first
      try {
        const hash = await writeSwapAsync({
          address: token,
          abi: erc20Abi,
          functionName: 'approve',
          args: [spender, amount]
        })
        await client.waitForTransactionReceipt({ hash })
        return
      } catch (e) {
        debugError('[Token Approval] Direct approve failed, trying reset-to-zero flow', e)
      }
      
      // Reset to 0 first
      const hash0 = await writeSwapAsync({
        address: token,
        abi: erc20Abi,
        functionName: 'approve',
        args: [spender, BigInt(0)]
      })
      await client.waitForTransactionReceipt({ hash: hash0 })
      
      // Then set to desired amount
      const hash1 = await writeSwapAsync({
        address: token,
        abi: erc20Abi,
        functionName: 'approve',
        args: [spender, amount]
      })
      await client.waitForTransactionReceipt({ hash: hash1 })
    },
    [publicClient, writeSwapAsync]
  )

  // Helper to set Permit2 allowance with reset-to-zero pattern
  const setPermit2Allowance = useCallback(
    async (token: `0x${string}`, spender: `0x${string}`, amount: bigint) => {
      const client = publicClient
      if (!client) throw new Error('RPC client unavailable')
      if (!permit2Address) throw new Error('Permit2 not deployed')

      const permit2: `0x${string}` = permit2Address

      const threeDaysSecs = 3 * 24 * 60 * 60
      const expiration = Math.floor(Date.now() / 1000) + threeDaysSecs
      
      const permit2Abi = [
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

      // Try direct approve first
      try {
        const hash = await writeSwapAsync({
          address: permit2,
          abi: permit2Abi,
          functionName: 'approve',
          args: [token, spender, amount, expiration]
        })
        await client.waitForTransactionReceipt({ hash })
        return
      } catch (e) {
        debugError('[Permit2 Approval] Direct approve failed, trying reset-to-zero flow', e)
      }
      
      // Reset to 0 first
      const hash0 = await writeSwapAsync({
        address: permit2,
        abi: permit2Abi,
        functionName: 'approve',
        args: [token, spender, BigInt(0), expiration]
      })
      await client.waitForTransactionReceipt({ hash: hash0 })
      
      // Then set to desired amount
      const hash1 = await writeSwapAsync({
        address: permit2,
        abi: permit2Abi,
        functionName: 'approve',
        args: [token, spender, amount, expiration]
      })
      await client.waitForTransactionReceipt({ hash: hash1 })
    },
    [permit2Address, publicClient, writeSwapAsync]
  )

  const handleApproval = useCallback(async () => {
    if (useEthIn) return
    if (!tokenInAddress || !effectiveAmountIn || !address) return
    if (!publicClient) {
      setApprovalState('error')
      setApprovalError('RPC client unavailable')
      return
    }

    if (!permit2Address) {
      setApprovalState('error')
      setApprovalError('Permit2 not deployed')
      return
    }

    if (!routerAddress || routerHasBytecode !== true) {
      setApprovalState('error')
      setApprovalError('Router not deployed')
      return
    }

    if (rpcChainId !== null && rpcChainId !== resolvedChainId) {
      setApprovalState('error')
      setApprovalError(`RPC network mismatch (wallet chainId=${resolvedChainId}, rpc chainId=${rpcChainId})`)
      return
    }
    
    setApprovalState('approving')
    setApprovalError('')
    setAllowancesReady(false)
    
    try {
      debugLog('[Approval] Starting approval process')
      debugLog('[Approval] Mode:', { selected: approvalMode, effective: effectiveApprovalMode, routePattern })
      debugLog('[Approval] effectiveAmountIn:', effectiveAmountIn.toString())
      
      // Signed mode: Only need Token->Permit2 with MAX_UINT160
      if (effectiveApprovalMode === 'signed') {
        if (needsTokenApproval) {
          debugLog('[Approval] Signed mode: Setting Token->Permit2 to MAX_UINT160')
          await setTokenAllowance(tokenInAddress, permit2Address, MAX_UINT160)
          debugLog('[Approval] Token->Permit2 approval confirmed')
        }
      } else {
        // Explicit mode: Need both Token->Permit2 (MAX_UINT160) and Permit2->Router (max calculation)
        
        // Step 1: Token -> Permit2 with MAX_UINT160
        if (needsTokenApproval) {
          debugLog('[Approval] Explicit mode: Setting Token->Permit2 to MAX_UINT160')
          await setTokenAllowance(tokenInAddress, permit2Address, MAX_UINT160)
          debugLog('[Approval] Token->Permit2 approval confirmed')
        }
        
        // Step 2: Permit2 -> Router with max(effectiveAmountIn, currentAllowance)
        if (needsPermit2Approval) {
          const currentPermit2Allowance = permit2Allowance?.[0] ?? BigInt(0)
          const permit2Amount = effectiveAmountIn > currentPermit2Allowance ? effectiveAmountIn : currentPermit2Allowance
          debugLog('[Approval] Explicit mode: Setting Permit2->Router to max(amount, current)', {
            effectiveAmountIn: effectiveAmountIn.toString(),
            currentAllowance: currentPermit2Allowance.toString(),
            newAmount: permit2Amount.toString()
          })
          await setPermit2Allowance(tokenInAddress, routerAddress, permit2Amount)
          debugLog('[Approval] Permit2->Router approval confirmed')
        }
      }
      
      // Refresh and verify allowances - retry a few times to handle RPC caching
      debugLog('[Approval] Verifying allowances on-chain...')
      let tokenOk = false
      let p2Ok = false

      for (let attempt = 0; attempt < 3; attempt++) {
        if (attempt > 0) {
          await new Promise(r => setTimeout(r, 1000)) // Wait 1s between retries
        }
        const [a1, a2] = await Promise.all([refetchAllowance(), refetchPermit2Allowance()])
        tokenOk = (a1?.data ?? tokenAllowance ?? BigInt(0)) >= effectiveAmountIn
        p2Ok = (a2?.data?.[0] ?? permit2Allowance?.[0] ?? BigInt(0)) >= effectiveAmountIn
        debugLog(`[Approval Verify Attempt ${attempt + 1}]`, { tokenOk, p2Ok, effectiveAmountIn: effectiveAmountIn.toString() })

        const ok = approvalMode === 'signed' ? tokenOk : tokenOk && p2Ok
        if (ok) break
      }

      const ok = approvalMode === 'signed' ? tokenOk : tokenOk && p2Ok
      setAllowancesReady(ok)

      // Don't throw error - trust the transaction receipts. The UI will update via hooks.
      // If verification still fails after retries, just log it but still show success
      // since the transactions were confirmed on-chain.
      if (!ok) {
        debugLog('[Approval] Warning: Verification showed insufficient allowance after confirmed txs. This may be RPC caching - allowances should update shortly.')
      }

      setApprovalState('success')
      debugLog('[Approval] Approval process completed successfully')
      
      // Reset success state after a delay
      setTimeout(() => setApprovalState('idle'), 3000)
      
    } catch (error) {
      debugError('[Approval] Approval failed:', error)
      setApprovalState('error')
      setApprovalError(error instanceof Error ? error.message : 'Approval failed')
      
      // Keep allowancesReady = false and do not enable swap
      setTimeout(() => {
        setApprovalState('idle')
        setApprovalError('')
      }, 5000)
    }
  }, [
    useEthIn,
    tokenInAddress,
    effectiveAmountIn,
    address,
    publicClient,
    refetchAllowance,
    refetchPermit2Allowance,
    needsTokenApproval,
    needsPermit2Approval,
    tokenAllowance,
    permit2Allowance,
    routerAddress,
    routerHasBytecode,
    rpcChainId,
    resolvedChainId,
    permit2Address,
    approvalMode,
    setTokenAllowance,
    setPermit2Allowance,
    MAX_UINT160
  ])

  // Handler for setting permit2 spending limit
  const handleSetPermit2SpendingLimit = useCallback((amount: bigint) => {
    setPermit2SpendingLimit(amount.toString())
  }, [])

  // Handler for setting router spending limit  
  const handleSetRouterSpendingLimit = useCallback((amount: bigint) => {
    setRouterSpendingLimitDirty(true)
    setRouterSpendingLimit(amount.toString())
  }, [])

  // Handler for issuing permit2 approval with custom limit
  const handleIssuePermit2Approval = useCallback(async () => {
    if (useEthIn) return
    if (!tokenInAddress || !address) return
    if (!publicClient) {
      setApprovalError('RPC client unavailable')
      return
    }

    if (!permit2Address) {
      setApprovalError('Permit2 not deployed')
      return
    }

    const amount = permit2SpendingLimit 
      ? BigInt(permit2SpendingLimit)
      : MAX_UINT160

    setApprovalState('approving')
    setApprovalError('')

    try {
      await setTokenAllowance(tokenInAddress, permit2Address, amount)
      await refetchAllowance()
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
  }, [useEthIn, tokenInAddress, address, publicClient, permit2Address, permit2SpendingLimit, setTokenAllowance, refetchAllowance, MAX_UINT160])

  // Handler for issuing router approval with custom limit
  const handleIssueRouterApproval = useCallback(async () => {
    if (useEthIn) return
    if (!tokenInAddress || !address) return
    if (!publicClient) {
      setApprovalError('RPC client unavailable')
      return
    }

    if (!routerAddress || routerHasBytecode !== true) {
      setApprovalError('Router not deployed')
      return
    }

    if (rpcChainId !== null && rpcChainId !== resolvedChainId) {
      setApprovalError(`RPC network mismatch (wallet chainId=${resolvedChainId}, rpc chainId=${rpcChainId})`)
      return
    }

    const amount = routerSpendingLimit
      ? BigInt(routerSpendingLimit)
      : (exactAmountInField ?? MAX_UINT160)

    setApprovalState('approving')
    setApprovalError('')

    try {
      await setPermit2Allowance(tokenInAddress, routerAddress, amount)
      await refetchPermit2Allowance()
      setApprovalState('success')
      setTimeout(() => setApprovalState('idle'), 3000)
    } catch (error) {
      setApprovalState('error')
      setApprovalError(error instanceof Error ? error.message : 'Router approval failed')
      setTimeout(() => {
        setApprovalState('idle')
        setApprovalError('')
      }, 5000)
    }
  }, [useEthIn, tokenInAddress, address, publicClient, routerSpendingLimit, exactAmountInField, routerAddress, routerHasBytecode, rpcChainId, resolvedChainId, setPermit2Allowance, refetchPermit2Allowance, MAX_UINT160])

  // Handler for getting accurate quote with signed permit (supports both Exact In and Exact Out)
  const handleGetAccurateQuote = useCallback(async () => {
    // Only works in signed mode with Exact In or Exact Out
    if (approvalMode !== 'signed' || useEthIn) {
      return
    }
    
    const isExactIn = lastEditedField === 'in'
    const isExactOut = lastEditedField === 'out'
    
    if (!isExactIn && !isExactOut) {
      return
    }

    // Validate required parameters
    if (isExactIn && (!builtExactIn.valid || !builtExactIn.args || !exactAmountInField)) {
      setAccurateQuoteError('Missing required parameters for Exact In')
      return
    }
    if (isExactOut && (!builtExactOut.valid || !builtExactOut.args || !exactAmountOutField)) {
      setAccurateQuoteError('Missing required parameters for Exact Out')
      return
    }
    
    if (!address || !publicClient) {
      setAccurateQuoteError('Wallet not connected')
      return
    }
    let nonceBitmap = permit2NonceBitmap
    {
      const refreshed = await refetchPermit2Nonce()
      if (refreshed.data !== undefined && refreshed.data !== null) {
        nonceBitmap = refreshed.data
      }
    }
    if (nonceBitmap === undefined || nonceBitmap === null) {
      setAccurateQuoteError('Failed to fetch Permit2 nonce')
      return
    }
    setAccurateQuoteLoading(true)
    setAccurateQuoteError('')
    setAccurateQuote(null)
    setAccurateQuoteSignaturePath(null)
    try {
      const isPermitSelectorSupported = async (selector: `0x${string}`): Promise<boolean> => {
        if (!publicClient || !routerAddress) return false
        try {
          const facetAddr = await publicClient.readContract({
            address: routerAddress,
            abi: [
              {
                inputs: [{ name: '_functionSelector', type: 'bytes4' }],
                name: 'facetAddress',
                outputs: [{ name: 'facetAddress_', type: 'address' }],
                stateMutability: 'view',
                type: 'function',
              },
            ],
            functionName: 'facetAddress',
            args: [selector],
          }) as `0x${string}`

          return !!facetAddr && !isZeroAddress(facetAddr)
        } catch {
          return false
        }
      }

      // Find the first unused nonce
      const inverted = ~nonceBitmap & ((BigInt(1) << BigInt(256)) - BigInt(1))
      let nonce = BigInt(0)
      for (let i = 0; i < 256; i++) {
        if ((((inverted >> BigInt(i)) & BigInt(1)) === BigInt(1))) {
          nonce = BigInt(i)
          break
        }
      }

      const permitDeadline = getDeadline()

      let pool: `0x${string}`
      let tokenInArg: `0x${string}`
      let tokenInVault: `0x${string}`
      let tokenOutArg: `0x${string}`
      let tokenOutVault: `0x${string}`
      let amountGiven: bigint
      let limit: bigint
      let swapKind: number
      let functionName: 'swapSingleTokenExactInWithPermit' | 'swapSingleTokenExactOutWithPermit'
      let userDataBytes: `0x${string}`
      
      if (isExactIn) {
        // Exact In case
        const args = builtExactIn.args!
        pool = args[0]
        tokenInArg = args[1]
        tokenInVault = args[2]
        tokenOutArg = args[3]
        tokenOutVault = args[4]
        amountGiven = args[5] // exactAmountIn
        limit = minOut ?? BigInt(0) // minOut as limit
        swapKind = 0 // SwapKind.ExactIn
        functionName = 'swapSingleTokenExactInWithPermit'
        userDataBytes = args[7]

        const supported = await isPermitSelectorSupported(SELECTOR_SWAP_EXACT_IN_WITH_PERMIT)
        if (!supported) {
          throw new Error(
            `Signed quote unavailable: router ${routerAddress} does not expose swapSingleTokenExactInWithPermit. Redeploy with permit swap facets.`
          )
        }
      } else {
        // Exact Out case
        const args = builtExactOut.args!
        pool = args[0]
        tokenInArg = args[1]
        tokenInVault = args[2]
        tokenOutArg = args[3]
        tokenOutVault = args[4]
        amountGiven = args[5] // exactAmountOut
        limit = maxIn ?? BigInt(0) // maxIn as limit
        swapKind = 1 // SwapKind.ExactOut
        functionName = 'swapSingleTokenExactOutWithPermit'
        userDataBytes = args[7]

        const supported = await isPermitSelectorSupported(SELECTOR_SWAP_EXACT_OUT_WITH_PERMIT)
        if (!supported) {
          throw new Error(
            `Signed quote unavailable: router ${routerAddress} does not expose swapSingleTokenExactOutWithPermit. Redeploy with permit swap facets.`
          )
        }
      }

      const wethIsEth = useEthIn || useEthOut
      const userDataHash = keccak256(userDataBytes)

      const permittedAmount = isExactIn ? amountGiven : limit

      if (!useEthIn && permittedAmount > BigInt(0)) {
        const [tokenBalanceNow, tokenAllowanceNow] = await Promise.all([
          publicClient.readContract({
            address: tokenInArg,
            abi: erc20Abi,
            functionName: 'balanceOf',
            args: [address],
          }) as Promise<bigint>,
          publicClient.readContract({
            address: tokenInArg,
            abi: erc20Abi,
            functionName: 'allowance',
            args: [address, (permit2Address ?? ZERO_ADDR) as `0x${string}`],
          }) as Promise<bigint>,
        ])

        if (tokenBalanceNow < permittedAmount) {
          throw new Error(
            `Insufficient token balance for signed quote: need ${formatUnits(permittedAmount, tokenInDecimals)} ${tokenIn}, have ${formatUnits(tokenBalanceNow, tokenInDecimals)} ${tokenIn}. For WETH→ETH unwrap, you must hold WETH (not only ETH).`
          )
        }

        if (tokenAllowanceNow < permittedAmount) {
          throw new Error(
            `Insufficient token approval to Permit2 for signed quote: need ${formatUnits(permittedAmount, tokenInDecimals)} ${tokenIn}, approved ${formatUnits(tokenAllowanceNow, tokenInDecimals)} ${tokenIn}. Issue Token → Permit2 approval first.`
          )
        }
      }

      // Build witness data for the permit
      const witness = createWitnessFromSwapParams(
        address,
        pool,
        tokenInArg,
        tokenInVault,
        tokenOutArg,
        tokenOutVault,
        amountGiven,
        limit,
        permitDeadline,
        wethIsEth,
        userDataHash
      )

      // Sign the permit (permit is always for tokenIn)
      if (!routerAddress || routerHasBytecode !== true) {
        throw new Error('Router not deployed')
      }

      if (rpcChainId !== null && rpcChainId !== resolvedChainId) {
        throw new Error(`RPC network mismatch (wallet chainId=${resolvedChainId}, rpc chainId=${rpcChainId})`)
      }

      if (!permit2Address) {
        throw new Error('Permit2 not deployed')
      }

      const permitChainId = rpcChainId ?? (await publicClient.getChainId())

      const typedData = getPermit2TypedData(
        permitChainId,
        permit2Address as `0x${string}`,
        {
          token: tokenInArg,
          amount: permittedAmount,
          nonce,
          deadline: permitDeadline,
          owner: address,
          spender: routerAddress,
          witness,
        }
      )

      const typedDigest = hashTypedData(typedData)
      const permitDigest = buildPermit2WitnessDigest({
        chainId: permitChainId,
        permit2Address: permit2Address as `0x${string}`,
        token: tokenInArg,
        amount: permittedAmount,
        nonce,
        deadline: permitDeadline,
        spender: routerAddress,
        witness,
      })

      let signature = await signTypedDataAsync({ ...typedData, account: address })
      let signaturePath: 'typedData' = 'typedData'
      let recoveredTypedSigner = await recoverAddress({ hash: typedDigest, signature })
      let recoveredPermitSigner = await recoverAddress({ hash: permitDigest, signature })

      if (recoveredTypedSigner.toLowerCase() !== address.toLowerCase()) {
        throw new Error(
          `Permit signature signer mismatch (typed): expected ${address}, recovered ${recoveredTypedSigner}. Ensure your wallet signs with the connected account.`
        )
      }

      // Build the StandardExchangeSwapSingleTokenHookParams
      const swapParams = {
        sender: address,
        kind: swapKind,
        pool,
        tokenIn: tokenInArg,
        tokenInVault,
        tokenOut: tokenOutArg,
        tokenOutVault,
        amountGiven,
        limit,
        deadline: permitDeadline,
        wethIsEth,
        userData: userDataBytes
      } as const
      const permit = {
        permitted: {
          token: tokenInArg,
          amount: permittedAmount
        },
        nonce: nonce,
        deadline: permitDeadline
      } as const
      const accurateQuoteAbi = isExactIn
        ? balancerV3StandardExchangeRouterExactInSwapFacetAbi
        : balancerV3StandardExchangeRouterExactOutSwapFacetAbi
      const simulationValue = useEthIn ? permittedAmount : undefined

      const simulateAccurateQuoteWithSignature = async (signatureArg: `0x${string}`) => {
        return await publicClient.simulateContract({
          address: routerAddress,
          abi: accurateQuoteAbi,
          functionName,
          args: [swapParams, permit, signatureArg],
          account: address,
          value: simulationValue,
        })
      }

      let accurateResult: bigint
      try {
        const simulation = await simulateAccurateQuoteWithSignature(signature)
        accurateResult = simulation.result
      } catch (simulationError) {
        const simulationMessage = simulationError instanceof Error ? simulationError.message : String(simulationError)
        const invalidSigner = simulationMessage.includes('0x815e1d64') || simulationMessage.includes('InvalidSigner')
        const invalidNonce = simulationMessage.includes('0x756688fe') || simulationMessage.includes('InvalidNonce')

        if (invalidNonce) {
          throw new Error(
            'Permit2 nonce is no longer valid (already used). Click Get Accurate Quote again to sign with a fresh nonce.'
          )
        }

        if (!invalidSigner) {
          throw simulationError
        }

        throw new Error(
          `Permit2 signature rejected with InvalidSigner for typed-data signature. personal_sign/signMessage is not a valid fallback here because it applies EIP-191 prefixing. Check typed-data parity (chainId, permit2 address, spender/router, witness fields, nonce, deadline) with on-chain Permit2 verification.`
        )
      }

      setAccurateQuoteSignaturePath(signaturePath)

      debugLog('[Accurate Quote] Permit signature validation', {
        signaturePath,
        typedDigest,
        permitDigest,
        recoveredTypedSigner,
        recoveredPermitSigner,
      })
      // Store the permit signature for use in swap execution
      // Store which direction so we know which function to use
      setStoredPermitSignature({
        signature,
        deadline: permitDeadline,
        nonce,
        isExactIn,
        intentKey: buildPermitIntentKey({
          chainId: resolvedChainId,
          owner: address,
          spender: routerAddress,
          pool,
          tokenIn: tokenInArg,
          tokenInVault,
          tokenOut: tokenOutArg,
          tokenOutVault,
          amountGiven,
          limit,
          wethIsEth,
          userDataHash,
          isExactIn,
        }),
      })
      // For Exact In, result is amountOut
      // For Exact Out, result is amountIn (what you'll pay)
      setAccurateQuote(accurateResult)
      debugLog('[Accurate Quote] Got accurate quote:', accurateResult.toString(), isExactIn ? '(Exact In amountOut)' : '(Exact Out amountIn)')
    } catch (error) {
      debugError('[Accurate Quote] Failed:', error)
      const message = error instanceof Error ? error.message : 'Failed to get accurate quote'
      if (message.includes('0x815e1d64')) {
        setAccurateQuoteError(
          'Permit signature validation failed (InvalidSigner). For ETH→WETH signed quotes, ensure the simulation includes ETH value and the signature was produced for the connected account and current router address.'
        )
      } else {
        setAccurateQuoteError(message)
      }
    } finally {
      setAccurateQuoteLoading(false)
    }
  }, [
    approvalMode,
    useEthIn,
    useEthOut,
    lastEditedField,
    builtExactIn,
    builtExactOut,
    exactAmountInField,
    exactAmountOutField,
    minOut,
    maxIn,
    address,
    publicClient,
    routerAddress,
    routerHasBytecode,
    rpcChainId,
    permit2NonceBitmap,
    refetchPermit2Nonce,
    getDeadline,
    resolvedChainId,
    platform,
    signTypedDataAsync
  ])

  const handleSwap = useCallback(async () => {
    if (!ready) return
    if (!publicClient) return

    if (!routerAddress || routerHasBytecode !== true) {
      debugError('Swap blocked: router not deployed', { routerAddress, routerHasBytecode })
      return
    }

    if (rpcChainId !== null && rpcChainId !== resolvedChainId) {
      debugError('Swap blocked: RPC network mismatch', { resolvedChainId, rpcChainId })
      return
    }
    
    try {
      setLastSwapReceiptStatus('pending')
      setLastSwapTxHash(null)
      setLastSwapEthDeltaWei(null)
      setLastSwapEthNetReceivedWei(null)
      setLastSwapHookDebug(null)
      setLastSwapSentinelDebug(null)

      const preBalance = address ? await publicClient.getBalance({ address }) : null

      if (!useEthIn && requiredAmountIn && effectiveApprovalMode === 'explicit') {
        setApprovalState('approving')
        setApprovalError('')
        try {
          await ensureSpendingLimits(requiredAmountIn)
          setApprovalState('success')
          setTimeout(() => setApprovalState('idle'), 1500)
        } catch (e) {
          setApprovalState('error')
          setApprovalError(e instanceof Error ? e.message : 'Approval failed')
          setTimeout(() => {
            setApprovalState('idle')
            setApprovalError('')
          }, 5000)
          return
        }
      }

      const deadline = getDeadline()

      const buildOrGetPermitSignature = async ({
        isExactIn,
        sender,
        pool,
        tokenInArg,
        tokenInVault,
        tokenOutArg,
        tokenOutVault,
        amountGiven,
        limit,
        wethIsEth,
        userData,
        permittedAmount,
        selector,
      }: {
        isExactIn: boolean
        sender: `0x${string}`
        pool: `0x${string}`
        tokenInArg: `0x${string}`
        tokenInVault: `0x${string}`
        tokenOutArg: `0x${string}`
        tokenOutVault: `0x${string}`
        amountGiven: bigint
        limit: bigint
        wethIsEth: boolean
        userData: `0x${string}`
        permittedAmount: bigint
        selector: `0x${string}`
      }) => {
        if (effectiveApprovalMode !== 'signed' || useEthIn) {
          return null
        }

        const userDataHash = keccak256(userData)
        const intentKey = buildPermitIntentKey({
          chainId: resolvedChainId,
          owner: sender,
          spender: routerAddress,
          pool,
          tokenIn: tokenInArg,
          tokenInVault,
          tokenOut: tokenOutArg,
          tokenOutVault,
          amountGiven,
          limit,
          wethIsEth,
          userDataHash,
          isExactIn,
        })

        let nonceBitmap = permit2NonceBitmap
        {
          const refreshed = await refetchPermit2Nonce()
          if (refreshed.data !== undefined && refreshed.data !== null) {
            nonceBitmap = refreshed.data
          }
        }
        if (nonceBitmap === undefined || nonceBitmap === null) {
          throw new Error('Failed to fetch Permit2 nonce')
        }

        const nowSec = BigInt(Math.floor(Date.now() / 1000))
        if (
          storedPermitSignature &&
          storedPermitSignature.isExactIn === isExactIn &&
          storedPermitSignature.intentKey === intentKey &&
          storedPermitSignature.deadline > nowSec
        ) {
          const storedNonce = storedPermitSignature.nonce
          const nonceUsedInWord0 =
            storedNonce < BigInt(256) &&
            (((nonceBitmap >> storedNonce) & BigInt(1)) === BigInt(1))

          if (!nonceUsedInWord0) {
            return storedPermitSignature
          }

          setStoredPermitSignature(null)
        }

        const facetAddr = await publicClient.readContract({
          address: routerAddress,
          abi: [
            {
              inputs: [{ name: '_functionSelector', type: 'bytes4' }],
              name: 'facetAddress',
              outputs: [{ name: 'facetAddress_', type: 'address' }],
              stateMutability: 'view',
              type: 'function',
            },
          ],
          functionName: 'facetAddress',
          args: [selector],
        }) as `0x${string}`

        if (isZeroAddress(facetAddr)) {
          throw new Error(
            `Signed swap unavailable: router ${routerAddress} does not expose ${
              isExactIn ? 'swapSingleTokenExactInWithPermit' : 'swapSingleTokenExactOutWithPermit'
            }.`
          )
        }

        const inverted = ~nonceBitmap & ((BigInt(1) << BigInt(256)) - BigInt(1))
        let nonce = BigInt(0)
        for (let i = 0; i < 256; i++) {
          if ((((inverted >> BigInt(i)) & BigInt(1)) === BigInt(1))) {
            nonce = BigInt(i)
            break
          }
        }

        if (!useEthIn && permittedAmount > BigInt(0)) {
          const [tokenBalanceNow, tokenAllowanceNow] = await Promise.all([
            publicClient.readContract({
              address: tokenInArg,
              abi: erc20Abi,
              functionName: 'balanceOf',
              args: [sender],
            }) as Promise<bigint>,
            publicClient.readContract({
              address: tokenInArg,
              abi: erc20Abi,
              functionName: 'allowance',
              args: [sender, (permit2Address ?? ZERO_ADDR) as `0x${string}`],
            }) as Promise<bigint>,
          ])

          if (tokenBalanceNow < permittedAmount) {
            throw new Error(
              `Insufficient token balance for signed swap: need ${formatUnits(permittedAmount, tokenInDecimals)} ${tokenIn}, have ${formatUnits(tokenBalanceNow, tokenInDecimals)} ${tokenIn}.`
            )
          }

          if (tokenAllowanceNow < permittedAmount) {
            throw new Error(
              `Insufficient token approval to Permit2 for signed swap: need ${formatUnits(permittedAmount, tokenInDecimals)} ${tokenIn}, approved ${formatUnits(tokenAllowanceNow, tokenInDecimals)} ${tokenIn}. Issue Token → Permit2 approval first.`
            )
          }
        }

        const witness = createWitnessFromSwapParams(
          sender,
          pool,
          tokenInArg,
          tokenInVault,
          tokenOutArg,
          tokenOutVault,
          amountGiven,
          limit,
          deadline,
          wethIsEth,
          userDataHash
        )

        if (!permit2Address) {
          throw new Error('Permit2 not deployed')
        }

        const permitChainId = rpcChainId ?? (await publicClient.getChainId())
        const typedData = getPermit2TypedData(
          permitChainId,
          permit2Address as `0x${string}`,
          {
            token: tokenInArg,
            amount: permittedAmount,
            nonce,
            deadline,
            owner: sender,
            spender: routerAddress,
            witness,
          }
        )

        const signature = await signTypedDataAsync({ ...typedData, account: sender })
        const recoveredTypedSigner = await recoverAddress({ hash: hashTypedData(typedData), signature })
        if (recoveredTypedSigner.toLowerCase() !== sender.toLowerCase()) {
          throw new Error(
            `Permit signature signer mismatch (typed): expected ${sender}, recovered ${recoveredTypedSigner}.`
          )
        }

        const nextPermitSignature = {
          signature,
          deadline,
          nonce,
          isExactIn,
          intentKey,
        }
        setStoredPermitSignature(nextPermitSignature)
        return nextPermitSignature
      }

      if (lastEditedField === 'in') {
        if (previewExactIn === null || !builtExactIn.valid || !builtExactIn.args || !exactAmountInField) return

        const [pool, tokenInArg, tokenInVault, tokenOutArg, tokenOutVault, amountInArg, sender, userData] = builtExactIn.args
        const minOutForSwap = minOut ?? (builtExactIn.route === 'WETH Wrap/Unwrap' ? amountInArg : undefined)
        if (minOutForSwap === undefined) return
        const swapArgs: readonly [`0x${string}`, `0x${string}`, `0x${string}`, `0x${string}`, `0x${string}`, bigint, bigint, bigint, boolean, `0x${string}`] = [
          pool,
          tokenInArg,
          tokenInVault,
          tokenOutArg,
          tokenOutVault,
          amountInArg,
          minOutForSwap,
          deadline,
          useEthIn || useEthOut, // wethIsEth
          userData
        ]

        debugLog('[Swap ExactIn] Executing with args:', {
          args: swapArgs,
          value: useEthIn ? exactAmountInField : undefined,
          route: builtExactIn.route,
          ethHandling: { useEthIn, useEthOut, wethIsEth: useEthIn || useEthOut },
          vaultHandling: { useTokenInVault: effectiveUseTokenInVault, useTokenOutVault: effectiveUseTokenOutVault, tokenInVaultAddress, tokenOutVaultAddress }
        })

        const shouldUsePermitPath = effectiveApprovalMode === 'signed' && !useEthIn
        const signedPermit = shouldUsePermitPath
          ? await buildOrGetPermitSignature({
              isExactIn: true,
              sender,
              pool,
              tokenInArg,
              tokenInVault,
              tokenOutArg,
              tokenOutVault,
              amountGiven: amountInArg,
              limit: minOutForSwap,
              wethIsEth: useEthIn || useEthOut,
              userData,
              permittedAmount: amountInArg,
              selector: SELECTOR_SWAP_EXACT_IN_WITH_PERMIT,
            })
          : null

        if (shouldUsePermitPath) {
          if (!signedPermit) {
            throw new Error('Failed to prepare signed permit for Exact In swap')
          }

          debugLog('[Swap ExactIn] Using signed permit for swap')
          const swapParamsPermit = {
            sender,
            kind: 0,
            pool,
            tokenIn: tokenInArg,
            tokenInVault,
            tokenOut: tokenOutArg,
            tokenOutVault,
            amountGiven: amountInArg,
            limit: minOutForSwap,
            deadline: signedPermit.deadline,
            wethIsEth: useEthIn || useEthOut,
            userData,
          } as const

          // Build the permit structure
          const permit = {
            permitted: {
              token: tokenInArg,
              amount: amountInArg
            },
            nonce: signedPermit.nonce,
            deadline: signedPermit.deadline
          } as const

          const hash = (await writeSwapAsync({
            address: routerAddress,
            abi: [
              {
                type: 'function',
                name: 'swapSingleTokenExactInWithPermit',
                inputs: [
                  {
                    name: 'swapParams',
                    type: 'tuple',
                    components: [
                      { name: 'sender', type: 'address' },
                      { name: 'kind', type: 'uint8' },
                      { name: 'pool', type: 'address' },
                      { name: 'tokenIn', type: 'address' },
                      { name: 'tokenInVault', type: 'address' },
                      { name: 'tokenOut', type: 'address' },
                      { name: 'tokenOutVault', type: 'address' },
                      { name: 'amountGiven', type: 'uint256' },
                      { name: 'limit', type: 'uint256' },
                      { name: 'deadline', type: 'uint256' },
                      { name: 'wethIsEth', type: 'bool' },
                      { name: 'userData', type: 'bytes' }
                    ]
                  },
                  {
                    name: 'permit',
                    type: 'tuple',
                    components: [
                      { name: 'permitted', type: 'tuple', components: [
                        { name: 'token', type: 'address' },
                        { name: 'amount', type: 'uint256' }
                      ]},
                      { name: 'nonce', type: 'uint256' },
                      { name: 'deadline', type: 'uint256' }
                    ]
                  },
                  { name: 'signature', type: 'bytes' }
                ],
                outputs: [{ name: '', type: 'uint256' }],
                stateMutability: 'payable'
              }
            ],
            functionName: 'swapSingleTokenExactInWithPermit',
            args: [swapParamsPermit, permit, signedPermit.signature],
            value: useEthIn ? exactAmountInField : undefined
          })) as `0x${string}`

          // Handle receipt
          if (publicClient && address) {
            setLastSwapTxHash(hash)
            const receipt = await publicClient.waitForTransactionReceipt({ hash })
            setLastSwapReceiptStatus(receipt.status)
            const postBalance = await publicClient.getBalance({ address })
            const gasSpent = receipt.effectiveGasPrice * receipt.gasUsed
            const delta = postBalance - (preBalance ?? BigInt(0))
            const netReceived = delta + gasSpent
            setLastSwapEthDeltaWei(delta)
            setLastSwapEthNetReceivedWei(netReceived)

            const routerDebugAbi = [
              {
                type: 'event',
                name: 'SwapHookParamsDebug',
                inputs: [
                  { indexed: true, name: 'sender', type: 'address' },
                  { indexed: false, name: 'kind', type: 'uint8' },
                  { indexed: true, name: 'pool', type: 'address' },
                  { indexed: false, name: 'tokenIn', type: 'address' },
                  { indexed: false, name: 'tokenOut', type: 'address' },
                  { indexed: false, name: 'tokenInVault', type: 'address' },
                  { indexed: false, name: 'tokenOutVault', type: 'address' },
                  { indexed: false, name: 'amountGiven', type: 'uint256' },
                  { indexed: false, name: 'limit', type: 'uint256' },
                  { indexed: false, name: 'wethIsEth', type: 'bool' },
                ],
              },
              {
                type: 'event',
                name: 'WethSentinelDebug',
                inputs: [
                  { indexed: true, name: 'sender', type: 'address' },
                  { indexed: false, name: 'kind', type: 'uint8' },
                  { indexed: false, name: 'amountGiven', type: 'uint256' },
                  { indexed: false, name: 'limit', type: 'uint256' },
                  { indexed: false, name: 'wrap', type: 'bool' },
                  { indexed: false, name: 'unwrap', type: 'bool' },
                ],
              },
            ] as const

            const routerAddr = routerAddress.toLowerCase()
            for (const log of receipt.logs) {
              if (log.address.toLowerCase() !== routerAddr) continue
              try {
                const decoded = decodeEventLog({ abi: routerDebugAbi, data: log.data, topics: log.topics })
                if (decoded.eventName === 'SwapHookParamsDebug') {
                  setLastSwapHookDebug(decoded.args)
                }
                if (decoded.eventName === 'WethSentinelDebug') {
                  setLastSwapSentinelDebug(decoded.args)
                }
              } catch {
                // ignore non-matching logs
              }
            }
          }

          return
        }


        // Original swap execution for explicit mode or when no permit stored

        const hash = (await writeSwapAsync({
          address: routerAddress,
          abi: [
            {
              inputs: [
                { name: 'pool', type: 'address' },
                { name: 'tokenIn', type: 'address' },
                { name: 'tokenInVault', type: 'address' },
                { name: 'tokenOut', type: 'address' },
                { name: 'tokenOutVault', type: 'address' },
                { name: 'exactAmountIn', type: 'uint256' },
                { name: 'minAmountOut', type: 'uint256' },
                { name: 'deadline', type: 'uint256' },
                { name: 'wethIsEth', type: 'bool' },
                { name: 'userData', type: 'bytes' }
              ],
              name: 'swapSingleTokenExactIn',
              outputs: [{ name: '', type: 'uint256' }],
              stateMutability: 'payable',
              type: 'function'
            }
          ],
          functionName: 'swapSingleTokenExactIn',
          args: swapArgs,
          value: useEthIn ? exactAmountInField : undefined
        })) as `0x${string}`

        if (publicClient && address) {
          setLastSwapTxHash(hash)
          const receipt = await publicClient.waitForTransactionReceipt({ hash })
          setLastSwapReceiptStatus(receipt.status)
          const postBalance = await publicClient.getBalance({ address })
          const gasSpent = receipt.effectiveGasPrice * receipt.gasUsed
          const delta = postBalance - (preBalance ?? BigInt(0))
          const netReceived = delta + gasSpent
          setLastSwapEthDeltaWei(delta)
          setLastSwapEthNetReceivedWei(netReceived)

          const routerDebugAbi = [
            {
              type: 'event',
              name: 'SwapHookParamsDebug',
              inputs: [
                { indexed: true, name: 'sender', type: 'address' },
                { indexed: false, name: 'kind', type: 'uint8' },
                { indexed: true, name: 'pool', type: 'address' },
                { indexed: false, name: 'tokenIn', type: 'address' },
                { indexed: false, name: 'tokenOut', type: 'address' },
                { indexed: false, name: 'tokenInVault', type: 'address' },
                { indexed: false, name: 'tokenOutVault', type: 'address' },
                { indexed: false, name: 'amountGiven', type: 'uint256' },
                { indexed: false, name: 'limit', type: 'uint256' },
                { indexed: false, name: 'wethIsEth', type: 'bool' },
              ],
            },
            {
              type: 'event',
              name: 'WethSentinelDebug',
              inputs: [
                { indexed: true, name: 'sender', type: 'address' },
                { indexed: false, name: 'kind', type: 'uint8' },
                { indexed: false, name: 'amountGiven', type: 'uint256' },
                { indexed: false, name: 'limit', type: 'uint256' },
                { indexed: false, name: 'wrap', type: 'bool' },
                { indexed: false, name: 'unwrap', type: 'bool' },
              ],
            },
          ] as const

          const routerAddr = routerAddress.toLowerCase()
          for (const log of receipt.logs) {
            if (log.address.toLowerCase() !== routerAddr) continue
            try {
              const decoded = decodeEventLog({ abi: routerDebugAbi, data: log.data, topics: log.topics })
              if (decoded.eventName === 'SwapHookParamsDebug') {
                setLastSwapHookDebug(decoded.args)
              }
              if (decoded.eventName === 'WethSentinelDebug') {
                setLastSwapSentinelDebug(decoded.args)
              }
            } catch {
              // ignore non-matching logs
            }
          }
        }

        return
      }

      if (previewExactOut === null || !builtExactOut.valid || !builtExactOut.args || !exactAmountOutField) return

      const [pool, tokenInArg, tokenInVault, tokenOutArg, tokenOutVault, amountOutArg, sender, userData] = builtExactOut.args
      const maxInForSwap = maxIn ?? (builtExactOut.route === 'WETH Wrap/Unwrap' ? amountOutArg : undefined)
      if (maxInForSwap === undefined) return
      const swapArgs: readonly [`0x${string}`, `0x${string}`, `0x${string}`, `0x${string}`, `0x${string}`, bigint, bigint, bigint, boolean, `0x${string}`] = [
        pool,
        tokenInArg,
        tokenInVault,
        tokenOutArg,
        tokenOutVault,
        amountOutArg,
        maxInForSwap,
        deadline,
        useEthIn || useEthOut, // wethIsEth
        userData
      ]

      const shouldUsePermitPath = effectiveApprovalMode === 'signed' && !useEthIn
      const signedPermit = shouldUsePermitPath
        ? await buildOrGetPermitSignature({
            isExactIn: false,
            sender,
            pool,
            tokenInArg,
            tokenInVault,
            tokenOutArg,
            tokenOutVault,
            amountGiven: amountOutArg,
            limit: maxInForSwap,
            wethIsEth: useEthIn || useEthOut,
            userData,
            permittedAmount: maxInForSwap,
            selector: SELECTOR_SWAP_EXACT_OUT_WITH_PERMIT,
          })
        : null

      if (shouldUsePermitPath) {
        if (!signedPermit) {
          throw new Error('Failed to prepare signed permit for Exact Out swap')
        }

        debugLog('[Swap ExactOut] Using signed permit for swap')

        const swapParamsPermit = {
          sender,
          kind: 1,
          pool,
          tokenIn: tokenInArg,
          tokenInVault,
          tokenOut: tokenOutArg,
          tokenOutVault,
          amountGiven: amountOutArg,
            limit: maxInForSwap,
          deadline: signedPermit.deadline,
          wethIsEth: useEthIn || useEthOut,
          userData,
          } as const

        const permit = {
          permitted: {
            token: tokenInArg,
              amount: maxInForSwap,
          },
          nonce: signedPermit.nonce,
          deadline: signedPermit.deadline,
        } as const

        const hash = (await writeSwapAsync({
          address: routerAddress,
          abi: [
            {
              type: 'function',
              name: 'swapSingleTokenExactOutWithPermit',
              inputs: [
                {
                  name: 'swapParams',
                  type: 'tuple',
                  components: [
                    { name: 'sender', type: 'address' },
                    { name: 'kind', type: 'uint8' },
                    { name: 'pool', type: 'address' },
                    { name: 'tokenIn', type: 'address' },
                    { name: 'tokenInVault', type: 'address' },
                    { name: 'tokenOut', type: 'address' },
                    { name: 'tokenOutVault', type: 'address' },
                    { name: 'amountGiven', type: 'uint256' },
                    { name: 'limit', type: 'uint256' },
                    { name: 'deadline', type: 'uint256' },
                    { name: 'wethIsEth', type: 'bool' },
                    { name: 'userData', type: 'bytes' },
                  ],
                },
                {
                  name: 'permit',
                  type: 'tuple',
                  components: [
                    {
                      name: 'permitted',
                      type: 'tuple',
                      components: [
                        { name: 'token', type: 'address' },
                        { name: 'amount', type: 'uint256' },
                      ],
                    },
                    { name: 'nonce', type: 'uint256' },
                    { name: 'deadline', type: 'uint256' },
                  ],
                },
                { name: 'signature', type: 'bytes' },
              ],
              outputs: [{ name: '', type: 'uint256' }],
              stateMutability: 'payable',
            },
          ] as const,
          functionName: 'swapSingleTokenExactOutWithPermit',
          args: [swapParamsPermit, permit, signedPermit.signature],
          value: useEthIn ? maxInForSwap : undefined,
        })) as `0x${string}`

        if (publicClient && address) {
          setLastSwapTxHash(hash)
          const receipt = await publicClient.waitForTransactionReceipt({ hash })
          setLastSwapReceiptStatus(receipt.status)
          const postBalance = await publicClient.getBalance({ address })
          const gasSpent = receipt.effectiveGasPrice * receipt.gasUsed
          const delta = postBalance - (preBalance ?? BigInt(0))
          const netReceived = delta + gasSpent
          setLastSwapEthDeltaWei(delta)
          setLastSwapEthNetReceivedWei(netReceived)
        }

        return
      }

      debugLog('[Swap ExactOut] Executing with args:', {
        args: swapArgs,
        value: useEthIn ? maxInForSwap : undefined,
        route: builtExactOut.route,
        ethHandling: { useEthIn, useEthOut, wethIsEth: useEthIn || useEthOut },
        vaultHandling: { useTokenInVault: effectiveUseTokenInVault, useTokenOutVault: effectiveUseTokenOutVault, tokenInVaultAddress, tokenOutVaultAddress }
      })

      const hash = (await writeSwapAsync({
        address: routerAddress,
        abi: [
          {
            inputs: [
              { name: 'pool', type: 'address' },
              { name: 'tokenIn', type: 'address' },
              { name: 'tokenInVault', type: 'address' },
              { name: 'tokenOut', type: 'address' },
              { name: 'tokenOutVault', type: 'address' },
              { name: 'exactAmountOut', type: 'uint256' },
              { name: 'maxAmountIn', type: 'uint256' },
              { name: 'deadline', type: 'uint256' },
              { name: 'wethIsEth', type: 'bool' },
              { name: 'userData', type: 'bytes' }
            ],
            name: 'swapSingleTokenExactOut',
            outputs: [{ name: 'amountIn', type: 'uint256' }],
            stateMutability: 'payable',
            type: 'function'
          }
        ],
        functionName: 'swapSingleTokenExactOut',
        args: swapArgs,
        value: useEthIn ? maxInForSwap : undefined
      })) as `0x${string}`

      if (publicClient && address) {
        setLastSwapTxHash(hash)
        const receipt = await publicClient.waitForTransactionReceipt({ hash })
        setLastSwapReceiptStatus(receipt.status)
        const postBalance = await publicClient.getBalance({ address })
        const gasSpent = receipt.effectiveGasPrice * receipt.gasUsed
        const delta = postBalance - (preBalance ?? BigInt(0))
        const netReceived = delta + gasSpent
        setLastSwapEthDeltaWei(delta)
        setLastSwapEthNetReceivedWei(netReceived)

        const routerDebugAbi = [
          {
            type: 'event',
            name: 'SwapHookParamsDebug',
            inputs: [
              { indexed: true, name: 'sender', type: 'address' },
              { indexed: false, name: 'kind', type: 'uint8' },
              { indexed: true, name: 'pool', type: 'address' },
              { indexed: false, name: 'tokenIn', type: 'address' },
              { indexed: false, name: 'tokenOut', type: 'address' },
              { indexed: false, name: 'tokenInVault', type: 'address' },
              { indexed: false, name: 'tokenOutVault', type: 'address' },
              { indexed: false, name: 'amountGiven', type: 'uint256' },
              { indexed: false, name: 'limit', type: 'uint256' },
              { indexed: false, name: 'wethIsEth', type: 'bool' },
            ],
          },
          {
            type: 'event',
            name: 'WethSentinelDebug',
            inputs: [
              { indexed: true, name: 'sender', type: 'address' },
              { indexed: false, name: 'kind', type: 'uint8' },
              { indexed: false, name: 'amountGiven', type: 'uint256' },
              { indexed: false, name: 'limit', type: 'uint256' },
              { indexed: false, name: 'wrap', type: 'bool' },
              { indexed: false, name: 'unwrap', type: 'bool' },
            ],
          },
        ] as const

        const routerAddr = routerAddress.toLowerCase()
        for (const log of receipt.logs) {
          if (log.address.toLowerCase() !== routerAddr) continue
          try {
            const decoded = decodeEventLog({ abi: routerDebugAbi, data: log.data, topics: log.topics })
            if (decoded.eventName === 'SwapHookParamsDebug') {
              setLastSwapHookDebug(decoded.args)
            }
            if (decoded.eventName === 'WethSentinelDebug') {
              setLastSwapSentinelDebug(decoded.args)
            }
          } catch {
            // ignore non-matching logs
          }
        }
      }
      
    } catch (error) {
      debugError('Swap failed:', error)
      setLastSwapReceiptStatus('reverted')
    }
  }, [
    ready,
    lastEditedField,
    previewExactIn,
    previewExactOut,
    minOut,
    maxIn,
    builtExactIn,
    builtExactOut,
    requiredAmountIn,
    ensureSpendingLimits,
    exactAmountInField,
    exactAmountOutField,
    getDeadline,
    resolvedChainId,
    useEthIn,
    useEthOut,
    writeSwapAsync,
    address,
    publicClient,
    routerAddress,
    routerHasBytecode,
    rpcChainId,
    permit2NonceBitmap,
    refetchPermit2Nonce,
    signTypedDataAsync,
    platform,
    tokenIn,
    tokenInDecimals,
    tokenInVaultAddress,
    tokenOutVaultAddress,
    effectiveUseTokenInVault,
    effectiveUseTokenOutVault,
    approvalMode,
    effectiveApprovalMode,
    routePattern,
    storedPermitSignature
  ])

  function getRouteDescription(): string {
    if (!routePattern) return ''
    
    switch(routePattern) {
      case 'WETH Wrap/Unwrap':
        return 'Wrap or unwrap between ETH and WETH (no pool swap)'
      case 'Direct Balancer V3 Swap':
        return 'Direct swap through Balancer V3 constant product pool'
      case 'Vault Deposit + Balancer Swap':
        return 'Deposit token into vault, then swap through external Balancer V3 pool'
      case 'Balancer Swap + Vault Withdrawal':
        return 'Swap through external Balancer V3 pool, then withdraw from vault'
      case 'Strategy Vault with ETH':
        return 'Strategy vault operation with ETH wrapping/unwrapping'
      case 'Strategy Vault Deposit':
        return 'Direct deposit to strategy vault (LP tokens → Vault shares)'
      case 'Strategy Vault Withdrawal':
        return 'Direct withdrawal from strategy vault (Vault shares → LP tokens)'
      case 'Strategy Vault Pass-Through':
        return 'Swap through strategy vault (deposit/withdraw)'
      case 'Vault-to-Vault Cycle':
        return 'Complex routing through multiple vaults'
      case 'Strategy Vault Operation':
        return 'Strategy vault operation'
      default:
        return ''
    }
  }

  // Refresh data when dependencies change
  useEffect(() => {
    if (tokenInAddress && address) {
      if (!isNativeTokenIn) {
        refetchBalance()
      } else {
        void refetchNativeBalance()
      }
      refetchAllowance()
      refetchPermit2Allowance()
    }
  }, [tokenInAddress, address, isNativeTokenIn, refetchBalance, refetchNativeBalance, refetchAllowance, refetchPermit2Allowance])

  // Verify allowances once approvals succeed
  useEffect(() => {
    const verify = async () => {
      if (approvalState !== 'success' || !requiredAmountIn) return
      // Refresh twice with small delays to avoid RPC cache
      await Promise.all([refetchAllowance(), refetchPermit2Allowance()])
      await new Promise(r => setTimeout(r, 400))
      const [a1, a2] = await Promise.all([refetchAllowance(), refetchPermit2Allowance()])
      const tokenOk = (a1?.data ?? tokenAllowance ?? BigInt(0)) >= requiredAmountIn
      const p2Ok = (a2?.data?.[0] ?? permit2Allowance?.[0] ?? BigInt(0)) >= requiredAmountIn
      const ok = approvalMode === 'signed' ? tokenOk : tokenOk && p2Ok
      setAllowancesReady(ok)
      debugLog('[Approval Verify]', { tokenOk, p2Ok, tokenAllowance: (a1?.data ?? tokenAllowance)?.toString?.(), permit2: (a2?.data?.[0] ?? permit2Allowance?.[0])?.toString?.(), exact: requiredAmountIn.toString() })
    }
    verify()
  }, [approvalState, requiredAmountIn, refetchAllowance, refetchPermit2Allowance, tokenAllowance, permit2Allowance, approvalMode])

  return (
    <div className="container mx-auto px-4 max-w-2xl">
      <h1 className="text-3xl font-bold text-white text-center py-4">Swap Tokens</h1>

      {!isConnected && (
        <div className="mb-4 p-3 bg-amber-600/20 border border-amber-500/50 rounded-lg">
          <div className="text-sm text-amber-200 font-medium">Wallet not connected</div>
          <div className="text-xs text-amber-300 mt-1">
            You can still preview quotes, but you&apos;ll need to connect a wallet to issue approvals or submit a swap.
          </div>
        </div>
      )}

      {isUnsupportedChain && (
        <div className="mb-4 p-3 bg-rose-600/20 border border-rose-500/50 rounded-lg">
          <div className="text-sm text-rose-200 font-medium">Unsupported network</div>
          <div className="text-xs text-rose-300 mt-1">
            Connected wallet chainId {walletChainId}. Switch to Sepolia ({CHAIN_ID_SEPOLIA}) or the local Anvil fork ({CHAIN_ID_ANVIL}).
          </div>
        </div>
      )}
       
      {/* Approval Mode Settings */}
      <div className="mb-4">
        <button
          onClick={() => setShowApprovalSettings(!showApprovalSettings)}
          className="flex items-center justify-between w-full px-4 py-2 bg-slate-700/50 rounded-lg border border-slate-600 hover:bg-slate-700 transition-colors"
        >
          <div className="flex items-center gap-2">
            <svg className="w-5 h-5 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
            <span className="text-sm font-medium text-gray-200">Approval Settings</span>
          </div>
          <svg 
            className={`w-4 h-4 text-gray-400 transition-transform ${showApprovalSettings ? 'rotate-180' : ''}`} 
            fill="none" 
            stroke="currentColor" 
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
        </button>
        
        {showApprovalSettings && (
          <div className="mt-2 p-4 bg-slate-700/30 rounded-lg border border-slate-600">
            <div className="text-xs text-gray-400 mb-3">Choose how you authorize token transfers:</div>
            
            {/* Explicit Approval Option */}
            <label
              className={`flex items-start gap-3 p-3 rounded-lg border cursor-pointer transition-all ${
                approvalMode === 'explicit' 
                  ? 'bg-blue-600/20 border-blue-500' 
                  : 'bg-slate-700/30 border-slate-600 hover:border-slate-500'
              }`}
            >
              <input
                type="radio"
                name="approvalMode"
                value="explicit"
                checked={approvalMode === 'explicit'}
                onChange={() => handleApprovalModeChange('explicit')}
                className="mt-1"
              />
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <span className={`text-sm font-medium ${approvalMode === 'explicit' ? 'text-blue-300' : 'text-gray-200'}`}>
                    Explicit Approvals
                  </span>
                  <span className="text-xs px-2 py-0.5 bg-slate-600 text-gray-300 rounded">Default</span>
                </div>
                <div className="text-xs text-gray-400 mt-1">
                  Two-step: Approve token → Approve Permit2. Requires 2 transactions on first swap.
                </div>
              </div>
            </label>
            
            {/* Signed Approval Option */}
            <label
              className={`flex items-start gap-3 p-3 rounded-lg border cursor-pointer transition-all mt-2 ${
                approvalMode === 'signed' 
                  ? 'bg-purple-600/20 border-purple-500' 
                  : 'bg-slate-700/30 border-slate-600 hover:border-slate-500'
              }`}
            >
              <input
                type="radio"
                name="approvalMode"
                value="signed"
                checked={approvalMode === 'signed'}
                onChange={() => handleApprovalModeChange('signed')}
                className="mt-1"
              />
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <span className={`text-sm font-medium ${approvalMode === 'signed' ? 'text-purple-300' : 'text-gray-200'}`}>
                    Signed Approvals
                  </span>
                  <span className="text-xs px-2 py-0.5 bg-purple-600/30 text-purple-300 rounded">Gasless</span>
                </div>
                <div className="text-xs text-gray-400 mt-1">
                  EIP-712 signature. One signature required per swap. No pre-approval needed.
                </div>
              </div>
            </label>
            
            {approvalModeInitialized && (
              <div className="mt-3 text-xs text-gray-500">
                ✓ Setting saved. Will persist across sessions.
              </div>
            )}
          </div>
        )}
      </div>
      
      {/* Pool Selection */}
      <div className="mb-6">
        <label className="block text-sm font-medium text-gray-300 mb-2">
          Select Pool ({poolOptions.length} pools available)
        </label>
          <select
          value={selectedPool} 
          onChange={(e) => setSelectedPool((e.target.value || '') as '' | Address)}
          className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-3"
        >
          <option value="">Select a Pool</option>
          {poolOptions.map(option => (
            <option key={option.value} value={option.value}>{option.label}</option>
            ))}
          </select>
        </div>

      {/* Token Selection */}
      <div className="grid grid-cols-2 gap-4 mb-6">
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">Token In</label>
            <select
              value={tokenIn}
              onChange={(e) => {
                const next = e.target.value
                setTokenIn(next)

                // ETH handling UX:
                // - Selecting ETH should always enable "Use ETH".
                // - Selecting WETH9 should preserve the user's "Use ETH" choice.
                // - Selecting any other token must disable "Use ETH".
                if (next === 'ETH') {
                  setUseEthIn(true)
                } else if (next === 'WETH9') {
                  // preserve existing toggle
                } else {
                  setUseEthIn(false)
                }
              }}
            className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-3"
            >
              <option value="">Select Token In</option>
            {tokenOptions.map(option => (
              <option key={String(option.value)} value={String(option.value)}>{option.label}</option>
              ))}
            </select>
          <label className="flex items-center gap-2 text-sm text-gray-300 mt-2">
            <input
              type="checkbox"
              checked={useEthIn}
              onChange={(e) => {
                const checked = e.target.checked
                if (checked) {
                  setUseEthIn(true)

                  // "Use ETH" means we treat WETH9 as the onchain token but pay in native ETH.
                  // Ensure the selected token is compatible with this behavior.
                  if (tokenIn !== 'ETH' && tokenIn !== 'WETH9') {
                    setTokenIn(weth9Address ? 'WETH9' : '')
                  }
                  return
                }

                // If the user unchecks while ETH is selected, fall back to WETH9 if available.
                setUseEthIn(false)
                if (tokenIn === 'ETH') {
                  setTokenIn(weth9Address ? 'WETH9' : '')
                }
              }}
            />
            Use ETH (wrap to WETH)
          </label>
          </div>

        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">Token Out</label>
              <select
            value={tokenOut}
            onChange={(e) => {
              const next = e.target.value
              setTokenOut(next)

              // ETH handling UX:
              // - Selecting ETH should always enable "Use ETH".
              // - Selecting WETH9 should preserve the user's "Use ETH" choice (so WETH9 can be unwrapped to ETH).
              // - Selecting any other token must disable "Use ETH".
              if (next === 'ETH') {
                setUseEthOut(true)
              } else if (next === 'WETH9') {
                // preserve existing toggle
              } else {
                setUseEthOut(false)
              }
            }}
            className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-3"
          >
            <option value="">Select Token Out</option>
            {tokenOptions.map(option => (
              <option key={String(option.value)} value={String(option.value)}>{option.label}</option>
                ))}
              </select>
          <label className="flex items-center gap-2 text-sm text-gray-300 mt-2">
              <input
                type="checkbox"
              checked={useEthOut}
              onChange={(e) => {
                const checked = e.target.checked
                if (checked) {
                  setUseEthOut(true)

                  // "Use ETH" on output means we unwrap WETH9 to native ETH.
                  // Ensure tokenOut is compatible (WETH9 or ETH).
                  if (tokenOut !== 'ETH' && tokenOut !== 'WETH9') {
                    setTokenOut(weth9Address ? 'WETH9' : '')
                  }
                  return
                }

                setUseEthOut(false)
                if (tokenOut === 'ETH') {
                  setTokenOut(weth9Address ? 'WETH9' : '')
                }
              }}
            />
            Use ETH (unwrap from WETH)
            </label>
          </div>
        </div>

      {/* Vault Selection */}
      <div className="grid grid-cols-2 gap-4 mb-6">
        <div>
          <label className="flex items-center gap-2 text-sm text-gray-300 mb-2">
            <input
              type="checkbox"
              checked={useTokenInVault}
              onChange={(e) => setUseTokenInVault(e.target.checked)}
            />
            Use Token In Vault
          </label>
          {useTokenInVault && (
            <select
              value={selectedVaultIn}
              onChange={(e) => {
                const selectedValue = e.target.value
                if (selectedValue) {
                  setSelectedVaultIn(selectedValue as `0x${string}`)
                } else {
                  setSelectedVaultIn('')
                }
              }}
              className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-3"
            >
              <option value="">Select Vault In</option>
              {filteredVaultOptions.map(option => (
                <option key={option.value} value={option.value as string}>
                  {option.label}
                </option>
              ))}
            </select>
          )}
          </div>

        <div>
          <label className="flex items-center gap-2 text-sm text-gray-300 mb-2">
            <input
              type="checkbox"
              checked={useTokenOutVault}
              onChange={(e) => setUseTokenOutVault(e.target.checked)}
            />
            Use Token Out Vault
            </label>
          {useTokenOutVault && (
              <select
                value={selectedVaultOut}
              onChange={(e) => setSelectedVaultOut(e.target.value as `0x${string}`)}
              className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-3"
            >
              <option value="">Select Vault Out</option>
              {filteredVaultOptions.map(option => (
                <option key={option.value} value={option.value as string}>
                  {option.label}
                </option>
                ))}
              </select>
            )}
        </div>
      </div>

      {/* Amount Input */}
      <div className="mb-6">
        <label className="block text-sm font-medium text-gray-300 mb-2">Amount In</label>
              <input
          type="number"
          value={amountInDisplay}
          onChange={(e) => {
            const next = e.target.value
            setLastEditedField('in')
            setAmountIn(next)
            if (!next) setAmountOut('')
          }}
          className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-3"
          placeholder="0.0"
        />
        {isNativeTokenIn ? (
          nativeBalance !== null ? (
            <div className="text-xs text-gray-400 mt-1">
              Balance: {formatUnits(nativeBalance, 18)} ETH
            </div>
          ) : nativeBalanceError ? (
            <div className="text-xs text-amber-300 mt-1">Balance: {nativeBalanceError}</div>
          ) : null
        ) : tokenBalance !== undefined ? (
          <div className="text-xs text-gray-400 mt-1">
            Balance: {formatUnits(tokenBalance, tokenInAddress ? getTokenDecimalsByAddressForChain(resolvedChainId, tokenInAddress) : 18)} {tokenIn}
          </div>
        ) : null}

        {lastEditedField === 'in' && previewExactInError && (
          <div className="text-xs text-amber-300 mt-2">Quote error: {previewExactInError.message}</div>
        )}
        </div>

        {/* Slippage */}
      <div className="mb-6">
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

      {/* Vault warning for Amount Out (explicit mode only) */}
      {approvalMode === 'explicit' && (useTokenInVault || useTokenOutVault) && (
        <div className="mb-4 p-3 bg-amber-600/20 border border-amber-500/50 rounded-lg">
          <div className="text-xs text-amber-300">
            Some Standard Exchange Vaults interact with underlying pools. This amount out may not include this interaction in the results of this swap. Use signed approvals or issue the explicit approval to ensure you get an accurate quote.
          </div>
        </div>
      )}

      {/* Amount Out Input (below slippage) */}
      <div className="mb-6">
        <label className="block text-sm font-medium text-gray-300 mb-2">Amount Out</label>
        <input
          type="number"
          value={amountOutDisplay}
          onChange={(e) => {
            const next = e.target.value
            setLastEditedField('out')
            setAmountOut(next)
            if (!next) setAmountIn('')
          }}
          className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-3"
          placeholder="0.0"
        />
        {lastEditedField === 'out' && previewExactOutError && (
          <div className="text-xs text-amber-300 mt-2">Quote error: {previewExactOutError.message}</div>
        )}
      </div>

      {/* Route Info */}
      {routePattern && (
        <div className="mb-6 p-4 bg-slate-700/50 rounded-lg">
          <div className="text-sm text-blue-300 font-medium">Route: {routePattern}</div>
          <div className="text-xs text-gray-400 mt-1">
            {getRouteDescription()}
          </div>
        </div>
      )}
      
      {/* Preview */}
      {lastEditedField === 'in' && previewExactIn && (
        <div className="mb-6 p-4 bg-slate-700/50 rounded-lg">
          <div className="text-sm text-green-300 font-medium">Preview (Exact In)</div>
          <div className="text-xs text-gray-400 mt-1">
            Expected Output: {formatUnits(previewExactIn, tokenOutAddress ? getTokenDecimalsByAddressForChain(resolvedChainId, tokenOutAddress) : 18)} {tokenOut}
          </div>
          {minOut && (
            <div className="text-xs text-gray-400">
              Minimum Output: {formatUnits(minOut, tokenOutAddress ? getTokenDecimalsByAddressForChain(resolvedChainId, tokenOutAddress) : 18)} {tokenOut}
            </div>
          )}
        </div>
      )}

      {lastEditedField === 'out' && previewExactOut && (
        <div className="mb-6 p-4 bg-slate-700/50 rounded-lg">
          <div className="text-sm text-green-300 font-medium">Preview (Exact Out)</div>
          <div className="text-xs text-gray-400 mt-1">
            Expected Input: {formatUnits(previewExactOut, tokenInAddress ? getTokenDecimalsByAddressForChain(resolvedChainId, tokenInAddress) : 18)} {tokenIn}
          </div>
          <div className="text-xs text-gray-400 mt-1">
            Preview is conservative for exact-out: actual input used may be lower.
          </div>
          {maxIn && (
            <div className="text-xs text-gray-400">
              Maximum Input: {formatUnits(maxIn, tokenInAddress ? getTokenDecimalsByAddressForChain(resolvedChainId, tokenInAddress) : 18)} {tokenIn}
            </div>
          )}
        </div>
      )}
      
      {/* Action Buttons */}
      <div className="space-y-3">
        {/* Signed Approval Mode - Show info and optional max approval */}
        {approvalMode === 'signed' && !useEthIn && (
          <div className="space-y-3">
            <div className="p-4 bg-purple-600/20 border border-purple-500 rounded-lg">
              <div className="flex items-center gap-2 mb-2">
                <svg className="w-5 h-5 text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                </svg>
                <span className="text-sm font-medium text-purple-300">Signed Approval Mode</span>
              </div>
              <div className="text-xs text-gray-400">
                You&apos;ll sign a permit with your wallet to authorize this swap. No pre-approval transactions needed for the swap itself.
              </div>
            </div>

            {/* Get Accurate Quote button - for Exact In or Exact Out */}
            {((lastEditedField === 'in' && builtExactIn.valid) || (lastEditedField === 'out' && builtExactOut.valid)) && (
              <div className="p-3 bg-slate-700/50 border border-slate-600 rounded-lg">
                <div className="text-xs text-gray-400 mb-2">
                  This will ask you to sign an approval so we can simulate the transaction to get you an accurate quote.
                </div>
                {accurateQuote && (
                  <div className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-3 mb-2">
                    <div className="text-sm text-indigo-300 mb-1">
                      {lastEditedField === 'in' ? 'Accurate Quote' : "You'll Pay"}
                    </div>
                    <div className="text-base">
                      {lastEditedField === 'in'
                        ? `${formatUnits(accurateQuote, tokenOutDecimals)} ${/^0x[a-fA-F0-9]{40}$/.test(tokenOut) ? 'Token Out' : tokenOut}`
                        : `${formatUnits(accurateQuote, tokenInDecimals)} ${/^0x[a-fA-F0-9]{40}$/.test(tokenIn) ? 'Token In' : tokenIn}`}
                    </div>
                  </div>
                )}
                <button
                  onClick={handleGetAccurateQuote}
                  disabled={accurateQuoteLoading || (!exactAmountInField && lastEditedField === 'in') || (!exactAmountOutField && lastEditedField === 'out')}
                  className="w-full py-2 px-4 bg-indigo-600 text-white rounded-md disabled:opacity-50 text-sm"
                >
                  {accurateQuoteLoading ? 'Getting Accurate Quote...' : 'Get Accurate Quote (Sign Permit)'}
                </button>
                {accurateQuoteError && (
                  <div className="text-xs text-red-400 mt-2">
                    {accurateQuoteError}
                  </div>
                )}
                {accurateQuote && (
                  <div className="text-xs text-green-400 mt-2">
                    ✓ Permit signed and stored for swap
                  </div>
                )}
              </div>
            )}
            
            {showTokenToPermit2Controls && (
              <div className="p-3 bg-slate-700/50 border border-slate-600 rounded-lg">
                <button
                  onClick={handleIssuePermit2Approval}
                  disabled={approvalState === 'approving'}
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
                    onClick={() => handleSetPermit2SpendingLimit(MAX_UINT160)}
                    className="absolute right-1 top-1/2 -translate-y-1/2 px-2 py-1 bg-slate-500 text-white rounded text-xs hover:bg-slate-400"
                  >
                    Max
                  </button>
                </div>
                {tokenAllowance !== undefined && (
                  <div className="text-xs text-gray-400 mt-1">
                    Current: {tokenAllowance.toString()} wei
                  </div>
                )}
              </div>
            )}
          </div>
        )}

        {/* Explicit Approval Mode - Show approval button */}
        {approvalMode === 'explicit' && (
          <div className="space-y-3">
            {showTokenToPermit2Controls && (
              <div className="p-3 bg-slate-700/50 border border-slate-600 rounded-lg">
                <button
                  onClick={handleIssuePermit2Approval}
                  disabled={approvalState === 'approving'}
                  className="w-full py-2 px-4 bg-blue-600 text-white rounded-md disabled:opacity-50 text-sm mb-2"
                >
                  Issue Approval: Permit2
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
                    onClick={() => handleSetPermit2SpendingLimit(MAX_UINT160)}
                    className="absolute right-1 top-1/2 -translate-y-1/2 px-2 py-1 bg-slate-500 text-white rounded text-xs hover:bg-slate-400"
                  >
                    Max
                  </button>
                </div>
                {tokenAllowance !== undefined && (
                  <div className="text-xs text-gray-400 mt-1">
                    Current: {tokenAllowance.toString()} wei
                  </div>
                )}
              </div>
            )}

            {needsPermit2Approval && (
              <div className="p-3 bg-slate-700/50 border border-slate-600 rounded-lg">
                <button
                  onClick={handleIssueRouterApproval}
                  disabled={approvalState === 'approving'}
                  className="w-full py-2 px-4 bg-blue-600 text-white rounded-md disabled:opacity-50 text-sm mb-2"
                >
                  Issue Approval: Router
                </button>
                <div className="relative">
                  <input
                    type="number"
                    placeholder="Spending limit"
                    value={routerSpendingLimit}
                    onChange={(e) => {
                      const next = e.target.value
                      setRouterSpendingLimit(next)
                      setRouterSpendingLimitDirty(next !== '')
                    }}
                    className="w-full px-3 pr-16 py-2 bg-slate-600 border border-slate-500 rounded-lg text-white text-sm"
                  />
                  <button
                    onClick={() => handleSetRouterSpendingLimit(MAX_UINT160)}
                    className="absolute right-1 top-1/2 -translate-y-1/2 px-2 py-1 bg-slate-500 text-white rounded text-xs hover:bg-slate-400"
                  >
                    Max
                  </button>
                </div>
                {permit2Allowance?.[0] !== undefined && (
                  <div className="text-xs text-gray-400 mt-1">
                    Current: {permit2Allowance[0].toString()} wei
                  </div>
                )}
              </div>
            )}

            {/* Permit2 -> Router Approval - ALREADY DEFINED ABOVE */}
            {/* DUPLICATE REMOVED */}
          </div>
        )}
        
        {approvalState === 'success' && (
          <div className="w-full py-3 px-4 bg-green-600 text-white rounded-md text-center">
            ✅ Approval Successful! You can now swap.
          </div>
        )}
        
        {approvalState === 'error' && (
          <div className="w-full py-3 px-4 bg-red-600 text-white rounded-md text-center">
            ❌ Approval Failed: {approvalError}
          </div>
        )}

        {/* Swap Button State Debug */}
        <DebugPanel title="🔍 Swap Button State" className="mt-4">
          <div>Mode: {lastEditedField === 'in' ? 'Exact In' : 'Exact Out'}</div>
          <div>
            Ready: {ready ? '✅' : '❌'} | Preview: {(lastEditedField === 'in' ? !!previewExactIn : !!previewExactOut) ? '✅' : '❌'} | NeedsApproval: {needsApproval ? '❌' : '✅'}
          </div>
          <div>
            Button Disabled: {(!ready || !(lastEditedField === 'in' ? !!previewExactIn : !!previewExactOut) || needsApproval) ? 'YES' : 'NO'}
          </div>
          <div>Allowances Ready (post-approval): {allowancesReady ? '✅ Yes' : '❌ No'}</div>
          <div>Preview Error: {previewError ? '❌ ' + previewError.message : '✅ None'}</div>
          <div className="mt-2 text-xs text-gray-400">
            <div>HookEnabled: {previewExactInHookEnabled ? '✅' : '❌'}</div>
            <div>ExactAmountIn: {exactAmountInField?.toString() || 'undefined'}</div>
            <div>BuiltExactIn Valid: {builtExactIn.valid ? '✅' : '❌'}</div>
            <div>Missing: {builtExactIn.missing?.join(', ') || 'none'}</div>
            <div>TokenIn: {tokenInAddress || 'none'}</div>
            <div>TokenOut: {tokenOutAddress || 'none'}</div>
            <div>Pool: {poolAddress || 'none'}</div>
          </div>
          <div className="mt-2">
            <button 
              onClick={() => {
                debugLog('[Debug] Manual preview refresh triggered')
                handlePreview()
              }}
              className="px-2 py-1 text-xs bg-blue-600 text-white rounded hover:bg-blue-700"
            >
              🔄 Refresh Preview
            </button>
          </div>
        </DebugPanel>
        
        <button
          onClick={handleSwap}
          disabled={!ready || !(lastEditedField === 'in' ? !!previewExactIn : !!previewExactOut)}
          className="w-full py-3 px-4 bg-blue-600 text-black rounded-md disabled:opacity-50"
        >
          {swapPending ? 'Swapping...' : lastEditedField === 'in' ? 'Swap (Exact In)' : 'Swap (Exact Out)'}
        </button>
      </div>
      
      {/* Debug Info */}
      {
        (
        <DebugPanel title="Swap Debug Information">
          <div>Pool: {poolAddress}</div>
          <div>TokenIn: {tokenInAddress}</div>
          <div>TokenOut: {tokenOutAddress}</div>
          <div>TokenInVault: {useTokenInVault ? tokenInVaultAddress : 'None'}</div>
          <div>TokenOutVault: {useTokenOutVault ? tokenOutVaultAddress : 'None'}</div>
          <div>Mode: {lastEditedField === 'in' ? 'Exact In' : 'Exact Out'}</div>
          <div>Exact Amount In (field): {exactAmountInField?.toString() || 'undefined'} wei</div>
          <div>Exact Amount Out (field): {exactAmountOutField?.toString() || 'undefined'} wei</div>
          <div>Preview Exact In (amountOut): {previewExactIn?.toString() || 'undefined'} wei</div>
          <div>Preview Exact Out (amountIn): {previewExactOut?.toString() || 'undefined'} wei</div>
          <div>MinOut (exact in): {minOut?.toString() || 'undefined'} wei</div>
          <div>MaxIn (exact out): {maxIn?.toString() || 'undefined'} wei</div>
          <div>WethIsEth: {(useEthIn || useEthOut) ? 'true' : 'false'}</div>
          <div>Accurate Quote Signature Path: {accurateQuoteSignaturePath ?? 'N/A'}</div>
          <div>Ready: {ready ? 'Yes' : 'No'}</div>
          <div>Needs Token Approval: {needsTokenApproval ? 'Yes' : 'No'}</div>
          <div>Needs Permit2 Approval: {needsPermit2Approval ? 'Yes' : 'No'}</div>

          <div>Needs Any Approval: {needsApproval ? 'Yes' : 'No'}</div>
          <div>Approval State: {approvalState}</div>
          {approvalError && <div>Approval Error: {approvalError}</div>}


          
          {/* Route Debug Info */}
          <div className="mt-2 pt-2 border-t border-slate-500">
            <div className="text-xs text-purple-300 font-medium mb-1">Route Info:</div>
            <div>Route Pattern: {routePattern || 'None'}</div>
            <div>Pool Type: {poolOptions.find(p => p.value === selectedPool)?.type || 'None'}</div>
            <div>Selected Pool: {selectedPool || 'None'}</div>
          </div>
          
          {/* Chain State Debug Info */}
          <div className="mt-2 pt-2 border-t border-slate-600">
            <div className="text-xs text-blue-300 font-medium mb-1">Chain State:</div>
            <div>Token → Permit2 Allowance: {tokenAllowance ? formatUnits(tokenAllowance, tokenInAddress ? getTokenDecimalsByAddressForChain(resolvedChainId, tokenInAddress) : 18) : 'Loading...'} {tokenIn}</div>
            <div>Permit2 → Router Allowance: {permit2Allowance ? formatUnits(permit2Allowance[0], tokenInAddress ? getTokenDecimalsByAddressForChain(resolvedChainId, tokenInAddress) : 18) : 'Loading...'} {tokenIn}</div>
            <div>Required Amount In: {requiredAmountIn ? formatUnits(requiredAmountIn, tokenInAddress ? getTokenDecimalsByAddressForChain(resolvedChainId, tokenInAddress) : 18) : 'N/A'} {tokenIn}</div>
            <div>Token Address: {tokenInAddress || 'None'}</div>
            <div>Router Address: {platform?.balancerV3StandardExchangeRouter ?? 'n/a'}</div>
            
            {/* Raw Values for Debugging */}
            <div className="mt-2 pt-2 border-t border-slate-500">
              <div className="text-xs text-yellow-300 font-medium mb-1">Raw Values:</div>
              <div>Token Allowance (wei): {tokenAllowance?.toString() || 'undefined'}</div>
              <div>Permit2 Allowance (wei): {permit2Allowance ? permit2Allowance[0]?.toString() : 'undefined'}</div>
              <div>Required Amount In (wei): {requiredAmountIn?.toString() || 'undefined'}</div>
              <div>Hook Status: Token={tokenAllowance !== undefined ? 'Loaded' : 'Loading'}, Permit2={permit2Allowance !== undefined ? 'Loaded' : 'Loading'}</div>
              <div className="mt-2">
                <button 
                  onClick={() => {
                    debugLog('[Debug] Manual refresh triggered')
                    refetchAllowance()
                    refetchPermit2Allowance()
                  }}
                  className="px-2 py-1 text-xs bg-blue-600 text-white rounded hover:bg-blue-700"
                >
                  🔄 Refresh Allowances
                </button>
              </div>
            </div>
          </div>
        </DebugPanel>
        )
      }
    </div>
  )
}
