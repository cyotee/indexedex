'use client'

import { Suspense, useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useSearchParams } from 'next/navigation'
import {
  useAccount,
  useChainId,
  useConnect,
  useConnection,
  useConnectorClient,
  usePublicClient,
  useSignTypedData,
  useSwitchChain,
  useWalletClient,
} from 'wagmi'
import { useReadContract, useReadContracts, useWriteContract } from 'wagmi'
import { sepolia } from 'wagmi/chains'
import { balancerV3StandardExchangeRouterExactInQueryFacetAbi } from '../generated'
import { balancerV3StandardExchangeRouterExactOutQueryFacetAbi } from '../generated'
import {
  balancerV3StandardExchangeRouterExactInSwapFacetAbi,
  balancerV3StandardExchangeRouterExactInSwapTargetAbi,
  balancerV3StandardExchangeRouterExactOutSwapFacetAbi,
  balancerV3StandardExchangeRouterExactOutSwapTargetAbi,
} from '../generated'
import { erc20Abi } from 'viem'
import { createPublicClient, http } from 'viem'
import { decodeEventLog, encodeAbiParameters, formatUnits, hashTypedData, keccak256, parseUnits, recoverAddress } from 'viem'
import type { Log } from 'viem'
import DebugPanel from '../components/DebugPanel'
import { ActionCta } from '../components/ui/ActionCta'
import { Card } from '../components/ui/Card'
import { debugError, debugLog } from '../lib/debug'
import { usePreferredBrowserChainId } from '@indexedex/protocol/browserChain'
import {
  resolveWalletGate,
  type PendingLeg,
} from '../lib/tx/actionState'
import { parseContractError } from '../lib/tx/parseContractError'

import { hasBytecode, isZeroAddress } from '@indexedex/protocol/onchain'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'
import { parseLaunchQuery } from '../lib/earn/launchQuery'

import { buildPermit2WitnessDigest, buildPermitIntentKey, createWitnessFromSwapParams, getPermit2TypedData } from '@indexedex/protocol/permit2-signature'

import {
  CHAIN_ID_ANVIL,
  CHAIN_ID_BASE,
  CHAIN_ID_BASE_SEPOLIA,
  CHAIN_ID_LOCALHOST,
  getAddressArtifacts,
  isSupportedChainId,
  resolveArtifactsChainId,
} from '@indexedex/protocol/addressArtifacts'
import {
  buildPoolOptionsForChain,
  buildTokenOptionsForChain,
  getWeth9AddressForChain,
  resolveTokenAddressFromOptionForChain,
  getTokenDecimalsByAddressForChain,
  resolvePoolTypeForChain,
  getStrategyVaultTokensForChain,
  isStrategyVaultTokenForChain,
  selectFromMenu,
  type PoolOption,
  type TokenOption,
  type Address
} from '@indexedex/protocol/tokenlists'
import { CHAIN_ID_SEPOLIA } from '@indexedex/protocol/addresses'
import {
  resolveRoute,
  type BalancerRouteName,
  type RouteResolution,
  type VaultRouteName,
} from './lib/routeMatcher'

// Helper functions - moved outside component to prevent re-creation
const ZERO_ADDR = '0x0000000000000000000000000000000000000000' as `0x${string}`
const MAX_UINT160 = (BigInt(1) << BigInt(160)) - BigInt(1)
const SELECTOR_SWAP_EXACT_IN_WITH_PERMIT = '0x7585dc3d' as `0x${string}`
const SELECTOR_SWAP_EXACT_OUT_WITH_PERMIT = '0x5bc8b2f3' as `0x${string}`
// Permit2 AllowanceTransfer.InsufficientAllowance(uint256) — emitted when the
// router tries `permit2.transferFrom(user, router, ...)` and the user hasn't
// issued the Permit2 -> Router approval (Explicit-mode step 2).
const PERMIT2_INSUFFICIENT_ALLOWANCE_SELECTOR = '0xf96fb071'

function translatePermit2AllowanceError(err: unknown): Error {
  const message = err instanceof Error ? err.message : String(err)
  if (message.includes(PERMIT2_INSUFFICIENT_ALLOWANCE_SELECTOR) || message.includes('InsufficientAllowance')) {
    return new Error(
      'Permit2 → Router approval missing or insufficient. In Explicit mode you must issue both Token → Permit2 and Permit2 → Router approvals before the quote can simulate the full swap. Click "Issue Approval" to proceed.'
    )
  }
  return err instanceof Error ? err : new Error(message)
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

type SwapRouteAuto =
  | null
  | RouteResolution<VaultRouteName>
  | RouteResolution<BalancerRouteName>

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

function SwapPageInner() {
  const { address, isConnected } = useAccount()
  const configChainId = useChainId()
  const { selectedChainId } = useSelectedNetwork()
  const { connect, connectors, isPending: isConnectPending } = useConnect()
  const { switchChainAsync, isPending: isSwitchPending } = useSwitchChain()
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
  const resolvedChainId = resolveArtifactsChainId(walletChainId ?? selectedChainId, undefined, selectedChainId) ?? selectedChainId ?? CHAIN_ID_SEPOLIA
  const isUnsupportedChain = isConnected && walletChainId !== undefined && !isSupportedChainId(walletChainId)
  const wagmiPublicClient = usePublicClient({ chainId: resolvedChainId })

  const publicClient = useMemo(() => {
    if (isUnsupportedChain) return null
    if (wagmiPublicClient) return wagmiPublicClient
    return null
  }, [isUnsupportedChain, wagmiPublicClient])
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
    const addr = getWeth9AddressForChain(resolvedChainId)
    if (!addr || addr === '0x0000000000000000000000000000000000000000') return null
    return addr
  }, [resolvedChainId])

  // Compare a dropdown token value against the resolved WETH9 hex address.
  // The dropdown now emits WETH9 as its hex address (sourced from the Token
  // List), so wrap/unwrap detection is a case-insensitive address match.
  const isWethValue = useCallback(
    (value: string): boolean => {
      if (!weth9Address) return false
      return value.toLowerCase() === weth9Address.toLowerCase()
    },
    [weth9Address],
  )


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
  const searchParams = useSearchParams()
  const launchApplied = useRef(false)
  useEffect(() => {
    if (launchApplied.current) return
    const launch = parseLaunchQuery({
      launch: searchParams.get('launch'),
      tokenOut: searchParams.get('tokenOut'),
      tokenIn: searchParams.get('tokenIn'),
    })
    if (launch.tokenOut) {
      setTokenOut(launch.tokenOut)
      launchApplied.current = true
    }
    if (launch.tokenIn) {
      setTokenIn(launch.tokenIn)
      launchApplied.current = true
    }
  }, [searchParams])
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
  // Sticky guard for the Standard Exchange Vault auto-flag effect below. Set
  // true the moment the user manually toggles either Use Token In/Out Vault
  // checkbox so we don't keep clobbering their choice. Reset when the user
  // switches to a different pool.
  const vaultFlagsManuallyToggled = useRef(false)

  // Approval mode: 'explicit' = ERC20 -> Permit2 -> Router (current), 'signed' = Permit2 signature (gasless)
  const [approvalMode, setApprovalMode] = useState<'explicit' | 'signed'>('signed')
  const [approvalModeInitialized, setApprovalModeInitialized] = useState(false)
  const [showApprovalSettings, setShowApprovalSettings] = useState(false)
  
  // Approval spending limit custom inputs
  const [permit2SpendingLimit, setPermit2SpendingLimit] = useState(MAX_UINT160.toString())
  const [routerSpendingLimit, setRouterSpendingLimit] = useState('')
  const [routerSpendingLimitDirty, setRouterSpendingLimitDirty] = useState(false)
  /** Per-leg pending for ActionCta — never share one isLoading across approve + swap (K17 / ethskills). */
  const [pendingLeg, setPendingLeg] = useState<PendingLeg>(null)

  useEffect(() => {
    const validPoolValues = new Set(poolOptions.map((option) => option.value.toLowerCase()))
    const validTokenValues = new Set(tokenOptions.map((option) => String(option.value)))
    const validVaultValues = new Set(filteredVaultOptions.map((option) => String(option.value).toLowerCase()))

    if (selectedPool && !validPoolValues.has(selectedPool.toLowerCase())) {
      const preserveWethPoolSelection =
        !!weth9Address &&
        (tokenIn === 'ETH' || isWethValue(tokenIn) || tokenOut === 'ETH' || isWethValue(tokenOut) || useEthIn || useEthOut) &&
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
    isWethValue,
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
  const isWethSentinelPool = useMemo(() => {
    if (!weth9Address || !rawPoolAddress) return false
    return rawPoolAddress.toLowerCase() === weth9Address.toLowerCase()
  }, [weth9Address, rawPoolAddress])

  const isWethSentinelWrapUnwrapFlow = useMemo(() => {
    if (!isWethSentinelPool) return false
    if (!weth9Address || !tokenInAddress || !tokenOutAddress) return false
    const bothWeth = tokenInAddress.toLowerCase() === weth9Address.toLowerCase() && tokenOutAddress.toLowerCase() === weth9Address.toLowerCase()
    return bothWeth && (useEthIn || useEthOut)
  }, [isWethSentinelPool, weth9Address, tokenInAddress, tokenOutAddress, useEthIn, useEthOut])

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

  /* ---------------------------------------------------------------------- */
  /*    Standard Exchange Vault auto-flagging via the route matcher         */
  /* ---------------------------------------------------------------------- */
  // Two pool shapes, one matcher:
  //   pool == vault       -> IBasicVault.vaultTokens() on the pool itself
  //   pool == balancer    -> IVault.getPoolTokens(pool) + lazy
  //                          IBasicVault.vaultTokens() for any pool tokens that
  //                          appear in the chain's strategy-vaults list.
  // Reads are wagmi-cached per address (vaultTokens is immutable) so the
  // multicall fires at most once per (chain, balancer pool) pair.

  // Reset the manual-toggle guard whenever the user picks a different pool.
  useEffect(() => {
    vaultFlagsManuallyToggled.current = false
  }, [poolAddress])

  // ---- pool == vault: read vaultTokens() directly from the pool ----
  // MultiAsset vault.vaultTokens() reports every token it will accept for
  // exchange, EXCLUDING the vault share itself (the vault always accepts
  // its own share). The matcher uses this set to validate the non-vault
  // side of each route.
  const { data: vaultTokensOfPool } = useReadContract({
    address: poolAddress as `0x${string}` | undefined,
    abi: [
      {
        inputs: [],
        name: 'vaultTokens',
        outputs: [{ name: 'tokens_', type: 'address[]' }],
        stateMutability: 'view',
        type: 'function',
      },
    ] as const,
    functionName: 'vaultTokens',
    query: { enabled: poolType === 'vault' && !!poolAddress },
  })

  // ---- pool == balancer: getPoolTokens + lazy candidate vault reads ----
  const balancerV3VaultAddress = useMemo(
    () => normalizeAddress((platform as any)?.balancerV3Vault),
    [platform]
  )

  const { data: balancerPoolTokens } = useReadContract({
    address: balancerV3VaultAddress as `0x${string}` | undefined,
    abi: [
      {
        inputs: [{ name: 'pool', type: 'address' }],
        name: 'getPoolTokens',
        outputs: [{ name: 'tokens', type: 'address[]' }],
        stateMutability: 'view',
        type: 'function',
      },
    ] as const,
    functionName: 'getPoolTokens',
    args: [(poolAddress ?? ZERO_ADDR) as `0x${string}`],
    query: {
      enabled: poolType === 'balancer' && !!poolAddress && !!balancerV3VaultAddress,
    },
  })

  // Known strategy vault addresses on the active chain — the matcher only needs
  // to read vaultTokens() for those that ALSO show up in the pool's tokens, so
  // we shrink the multicall list by the pool's token list.
  const strategyVaultAddressSet = useMemo(() => {
    const set = new Set<string>()
    for (const { token } of selectFromMenu('vaults-page', resolvedChainId)) {
      set.add(token.address.toLowerCase())
    }
    return set
  }, [resolvedChainId])

  const candidateVaultsInPool = useMemo<`0x${string}`[]>(() => {
    if (poolType !== 'balancer' || !balancerPoolTokens) return []
    return (balancerPoolTokens as readonly `0x${string}`[]).filter((t) =>
      strategyVaultAddressSet.has(t.toLowerCase())
    )
  }, [poolType, balancerPoolTokens, strategyVaultAddressSet])

  const { data: candidateVaultTokensMulticall } = useReadContracts({
    contracts: candidateVaultsInPool.map((addr) => ({
      address: addr,
      abi: [
        {
          inputs: [],
          name: 'vaultTokens',
          outputs: [{ name: 'tokens_', type: 'address[]' }],
          stateMutability: 'view',
          type: 'function',
        },
      ] as const,
      functionName: 'vaultTokens' as const,
    })),
    query: { enabled: candidateVaultsInPool.length > 0 },
  })

  // Build the matcher's underlyingByVault input. For pool==vault we seed
  // [poolAddress -> vaultTokens(pool)]. For pool==balancer we seed each
  // candidate vault address -> its vaultTokens() result from the multicall.
  const underlyingByVault = useMemo(() => {
    const map = new Map<string, readonly `0x${string}`[]>()
    if (poolType === 'vault' && poolAddress && vaultTokensOfPool) {
      map.set(poolAddress.toLowerCase(), vaultTokensOfPool as readonly `0x${string}`[])
    }
    if (poolType === 'balancer' && candidateVaultTokensMulticall) {
      candidateVaultsInPool.forEach((vaultAddr, idx) => {
        const res = candidateVaultTokensMulticall[idx]
        if (res?.status === 'success' && Array.isArray(res.result)) {
          map.set(vaultAddr.toLowerCase(), res.result as readonly `0x${string}`[])
        }
      })
    }
    return map
  }, [poolType, poolAddress, vaultTokensOfPool, candidateVaultsInPool, candidateVaultTokensMulticall])

  // Run the matcher.
  const swapRouteAuto = useMemo<SwapRouteAuto>(() => {
    if (poolType !== 'vault' && poolType !== 'balancer') return null
    if (!poolAddress || !tokenInAddress || !tokenOutAddress) return null
    // WETH wrap/unwrap is a sentinel route handled by buildExactInArgs directly;
    // the WETH9 contract is not a Balancer pool so getPoolTokens reverts and the
    // matcher would otherwise stay pending forever. Skip it.
    if (isWethSentinelWrapUnwrapFlow) return null

    const poolTokens: readonly `0x${string}`[] =
      poolType === 'vault'
        ? [poolAddress as `0x${string}`]
        : ((balancerPoolTokens as readonly `0x${string}`[] | undefined) ?? [])

    // For balancer pools, only declare ready when the multicall has settled
    // for every candidate (so we don't flash an 'invalid' while a vault read
    // is still pending).
    if (poolType === 'balancer') {
      if (!balancerPoolTokens) return { kind: 'pending' }
      if (candidateVaultsInPool.length > 0 && !candidateVaultTokensMulticall) return { kind: 'pending' }
    }

    return resolveRoute({
      poolType,
      poolAddress: poolAddress as `0x${string}`,
      tokenIn: tokenInAddress as `0x${string}`,
      tokenOut: tokenOutAddress as `0x${string}`,
      poolTokens,
      underlyingByVault,
      selectedVaultIn: selectedVaultIn ? (selectedVaultIn as `0x${string}`) : null,
      selectedVaultOut: selectedVaultOut ? (selectedVaultOut as `0x${string}`) : null,
    })
  }, [
    poolType,
    poolAddress,
    tokenInAddress,
    tokenOutAddress,
    isWethSentinelWrapUnwrapFlow,
    balancerPoolTokens,
    candidateVaultsInPool,
    candidateVaultTokensMulticall,
    underlyingByVault,
    selectedVaultIn,
    selectedVaultOut,
  ])

  // Apply the resolved route. Skipped when the user has manually toggled a
  // checkbox (sticky per-pool) or when the resolution is anything other than
  // ok (pending/ambiguous/invalid stays visible in the UI hint but doesn't
  // touch flag state).
  useEffect(() => {
    if (vaultFlagsManuallyToggled.current) return
    if (!swapRouteAuto || swapRouteAuto.kind !== 'ok') return
    setUseTokenInVault(swapRouteAuto.useTokenInVault)
    setUseTokenOutVault(swapRouteAuto.useTokenOutVault)
    if (swapRouteAuto.useTokenInVault && swapRouteAuto.tokenInVault) {
      setSelectedVaultIn(swapRouteAuto.tokenInVault)
    }
    if (swapRouteAuto.useTokenOutVault && swapRouteAuto.tokenOutVault) {
      setSelectedVaultOut(swapRouteAuto.tokenOutVault)
    }
  }, [swapRouteAuto])

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

  const simulateQueryExactIn = useCallback(
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

  const simulateQueryExactOut = useCallback(
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

  // Once all Explicit-mode approvals are issued (Token -> Permit2 and Permit2
  // -> Router), simulate the actual swap function instead of the read-only
  // query. The actual swap path threads through any Standard Exchange Vault
  // hooks that call back into the router, which the query function may skip.
  // simulateContract is RPC-side dry-run only — no state changes commit.
  const simulateActualSwapExactIn = useCallback(
    async (args: NonNullable<BuildArgsOutput['args']>) => {
      if (!publicClient) throw new Error('RPC client unavailable')
      if (!routerAddress || routerHasBytecode !== true) {
        throw new Error('Swap preview unavailable: router is not deployed on this network')
      }
      if (!address) throw new Error('Connect a wallet to simulate the actual swap')

      const [pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, exactAmountIn] = args
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600)

      try {
        const { result } = await publicClient.simulateContract({
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
                { name: 'userData', type: 'bytes' },
              ],
              name: 'swapSingleTokenExactIn',
              outputs: [{ name: '', type: 'uint256' }],
              stateMutability: 'payable',
              type: 'function',
            },
          ] as const,
          functionName: 'swapSingleTokenExactIn',
          args: [pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, exactAmountIn, BigInt(0), deadline, useEthIn, '0x'] as const,
          account: address,
          value: useEthIn ? (exactAmountIn as bigint) : undefined,
        } as const)
        return result as bigint
      } catch (err) {
        throw translatePermit2AllowanceError(err)
      }
    },
    [publicClient, routerAddress, routerHasBytecode, address, useEthIn]
  )

  const simulateActualSwapExactOut = useCallback(
    async (args: NonNullable<BuildArgsOutput['args']>) => {
      if (!publicClient) throw new Error('RPC client unavailable')
      if (!routerAddress || routerHasBytecode !== true) {
        throw new Error('Swap preview unavailable: router is not deployed on this network')
      }
      if (!address) throw new Error('Connect a wallet to simulate the actual swap')

      const [pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, exactAmountOut] = args
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600)
      // For simulation purposes pass an unbounded max-in. The actual swap path's
      // slippage budget is enforced separately by maxIn when the user submits.
      const maxAmountIn = BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')

      try {
        const { result } = await publicClient.simulateContract({
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
                { name: 'userData', type: 'bytes' },
              ],
              name: 'swapSingleTokenExactOut',
              outputs: [{ name: '', type: 'uint256' }],
              stateMutability: 'payable',
              type: 'function',
            },
          ] as const,
          functionName: 'swapSingleTokenExactOut',
          args: [pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, exactAmountOut, maxAmountIn, deadline, useEthIn, '0x'] as const,
          account: address,
          value: useEthIn ? maxAmountIn : undefined,
        } as const)
        return result as bigint
      } catch (err) {
        throw translatePermit2AllowanceError(err)
      }
    },
    [publicClient, routerAddress, routerHasBytecode, address, useEthIn]
  )

  // Switch between query and actual-swap simulation based on approval state.
  // The preview useEffect / debounce machinery just sees these two callbacks
  // and doesn't need to know which underlying function is being simulated.
  // useActualSwapSimulation is updated by a later useEffect once needsApproval
  // is computed (it lives below the simulation block in the render order).
  const [useActualSwapSimulation, setUseActualSwapSimulation] = useState(false)

  const simulatePreviewExactIn = useActualSwapSimulation
    ? simulateActualSwapExactIn
    : simulateQueryExactIn
  const simulatePreviewExactOut = useActualSwapSimulation
    ? simulateActualSwapExactOut
    : simulateQueryExactOut

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
      // Stale signature -> stale Amount Out. Reset so the query-based preview
      // useEffect re-runs and refills it with the read-only quote until the
      // user re-signs.
      setPreviewExactIn(null)
      setPreviewExactOut(null)
      lastCompletedPreviewKeyRef.current = null
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

  // Separate approval checks for each step.
  // When allowance data hasn't loaded yet we conservatively report "needs approval".
  // This prevents the preview useEffect (and its useActualSwapSimulation gate) from
  // briefly thinking approvals are satisfied and firing a real swapSingleTokenExactIn
  // simulation before the Permit2->Router allowance is even known — which would
  // surface to the user as a raw InsufficientAllowance (0xf96fb071) revert.
  const needsTokenApproval = useMemo(() => {
    if (useEthIn) return false
    if (!effectiveAmountIn || effectiveAmountIn <= BigInt(0)) return false
    if (tokenAllowance === undefined || tokenAllowance === null) return true

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
    if (permit2Allowance === undefined || permit2Allowance === null) return true

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

  // Multi-leg primary CTA gate (connect → switch → approve leg(s) → execute).
  // Explicit: both approve legs via split handlers only (never one-shot handleApproval).
  // Signed: token→Permit2 only; permit2→router leg omitted (signedMode).
  const amountValidForGate = useMemo(() => {
    if (lastEditedField === 'in') {
      return !!exactAmountInField && exactAmountInField > BigInt(0)
    }
    return !!exactAmountOutField && exactAmountOutField > BigInt(0)
  }, [lastEditedField, exactAmountInField, exactAmountOutField])

  const hasPreviewForGate = useMemo(() => {
    if (!routerReady) return false
    if (lastEditedField === 'in') return !!previewExactIn
    return !!previewExactOut
  }, [routerReady, lastEditedField, previewExactIn, previewExactOut])

  const isWrongNetworkForGate = useMemo(() => {
    if (!isConnected) return false
    if (isUnsupportedChain) return true
    if (
      typeof walletChainId === 'number' &&
      typeof selectedChainId === 'number' &&
      walletChainId !== selectedChainId
    ) {
      return true
    }
    if (rpcChainId !== null && typeof walletChainId === 'number' && rpcChainId !== walletChainId) {
      return true
    }
    return false
  }, [isConnected, isUnsupportedChain, walletChainId, selectedChainId, rpcChainId])

  const swapWalletGate = useMemo(
    () =>
      resolveWalletGate({
        isConnected,
        isWrongNetwork: isWrongNetworkForGate,
        amountValid: amountValidForGate,
        hasPreview: hasPreviewForGate,
        // ETH-in skips ERC20 approvals entirely
        needsTokenApproval: useEthIn ? false : needsTokenApproval,
        needsPermit2Approval: useEthIn ? false : needsPermit2Approval,
        executeLabel: lastEditedField === 'in' ? 'Swap (Exact In)' : 'Swap (Exact Out)',
        signedMode: effectiveApprovalMode === 'signed',
      }),
    [
      isConnected,
      isWrongNetworkForGate,
      amountValidForGate,
      hasPreviewForGate,
      useEthIn,
      needsTokenApproval,
      needsPermit2Approval,
      lastEditedField,
      effectiveApprovalMode,
    ],
  )

  const effectiveSwapPendingLeg: PendingLeg = useMemo(() => {
    if (pendingLeg) return pendingLeg
    if (isConnectPending) return 'connect'
    if (isSwitchPending) return 'switch'
    if (approvalState === 'approving') {
      if (swapWalletGate.kind === 'approve' && swapWalletGate.leg === 'token-permit2') {
        return 'approve-token-permit2'
      }
      if (swapWalletGate.kind === 'approve' && swapWalletGate.leg === 'permit2-router') {
        return 'approve-permit2-router'
      }
      // Safety: ensureSpendingLimits inside handleSwap may set approving while on execute
      return null
    }
    if (swapPending || lastSwapReceiptStatus === 'pending') return 'execute'
    return null
  }, [
    pendingLeg,
    isConnectPending,
    isSwitchPending,
    approvalState,
    swapWalletGate,
    swapPending,
    lastSwapReceiptStatus,
  ])

  // Bridge from approval-state to the simulation-mode flag declared earlier in
  // the render. In Explicit mode, switch the Amount Out preview from the
  // router's read-only query function to a full simulation of the actual swap
  // function as soon as both approvals (Token -> Permit2 and Permit2 -> Router)
  // are in place. This is so Standard Exchange Vault hooks that re-enter the
  // router are exercised during the preview.
  useEffect(() => {
    setUseActualSwapSimulation(
      effectiveApprovalMode === 'explicit' && !needsApproval && !!address && !useEthIn
    )
  }, [effectiveApprovalMode, needsApproval, address, useEthIn])

  // Switching approval mode flips which approvals are required, but the cached
  // preview key + cached allowance reads don't update on their own. Refetch both
  // allowances and drop the last-completed preview marker so the simulation path
  // is re-chosen with current on-chain state — otherwise a Signed-mode session
  // that never set the Permit2->Router allowance leaves Explicit mode firing a
  // real swap simulation that reverts with InsufficientAllowance.
  useEffect(() => {
    lastCompletedPreviewKeyRef.current = null
    void refetchAllowance()
    void refetchPermit2Allowance()
    // Intentionally only re-run on mode change; refetch fns are stable.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [approvalMode])

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

  /**
   * Legacy one-shot approval orchestrator (both legs in one click).
   * Kept for rare debug / non-sequential callers only.
   * Multi-leg ActionCta MUST use handleIssuePermit2Approval / handleIssueRouterApproval (K17).
   * Do not wire ActionCta onClick to this function.
   */
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

  // Helper: surface a guard failure so the user actually sees it instead of
  // a click that silently does nothing. setApprovalError alone is invisible
  // because the error banner only renders when approvalState === 'error'.
  const failApproval = useCallback((message: string) => {
    setApprovalError(message)
    setApprovalState('error')
    setTimeout(() => {
      setApprovalState('idle')
      setApprovalError('')
    }, 5000)
  }, [])

  // Handler for issuing permit2 approval with custom limit
  // K17: split handler only — ActionCta multi-leg must never call one-shot handleApproval
  const handleIssuePermit2Approval = useCallback(async () => {
    if (useEthIn) {
      failApproval('Token-to-Permit2 approval is not needed when paying in native ETH')
      return
    }
    if (!tokenInAddress) {
      failApproval('Select a Token In before issuing the Token to Permit2 approval')
      return
    }
    if (!address) {
      failApproval('Connect a wallet before issuing the Token to Permit2 approval')
      return
    }
    if (!publicClient) {
      failApproval('RPC client unavailable')
      return
    }

    if (!permit2Address) {
      failApproval('Permit2 not deployed at the address recorded in platform.json')
      return
    }

    const amount = permit2SpendingLimit 
      ? BigInt(permit2SpendingLimit)
      : MAX_UINT160

    setPendingLeg('approve-token-permit2')
    setApprovalState('approving')
    setApprovalError('')

    try {
      await setTokenAllowance(tokenInAddress, permit2Address, amount)
      await refetchAllowance()
      setApprovalState('success')
      setTimeout(() => setApprovalState('idle'), 3000)
    } catch (error) {
      setApprovalState('error')
      setApprovalError(parseContractError(error) || (error instanceof Error ? error.message : 'Permit2 approval failed'))
      setTimeout(() => {
        setApprovalState('idle')
        setApprovalError('')
      }, 5000)
    } finally {
      setPendingLeg(null)
    }
  }, [useEthIn, tokenInAddress, address, publicClient, permit2Address, permit2SpendingLimit, setTokenAllowance, refetchAllowance, MAX_UINT160, failApproval])

  // Handler for issuing router approval with custom limit
  // K17: split handler only — ActionCta multi-leg must never call one-shot handleApproval
  const handleIssueRouterApproval = useCallback(async () => {
    if (useEthIn) {
      failApproval('Permit2-to-Router approval is not needed when paying in native ETH')
      return
    }
    if (!tokenInAddress) {
      failApproval('Select a Token In before issuing the Permit2 to Router approval')
      return
    }
    if (!address) {
      failApproval('Connect a wallet before issuing the Permit2 to Router approval')
      return
    }
    if (!publicClient) {
      failApproval('RPC client unavailable')
      return
    }

    if (!routerAddress || routerHasBytecode !== true) {
      failApproval(
        routerBytecodeError
          ? `Router not usable: ${routerBytecodeError}`
          : 'Router not deployed at the address recorded in platform.json'
      )
      return
    }

    if (rpcChainId !== null && rpcChainId !== resolvedChainId) {
      failApproval(
        `RPC network mismatch (wallet chainId=${resolvedChainId}, rpc chainId=${rpcChainId}) — switch your wallet to the right chain or restart the dev server`
      )
      return
    }

    const amount = routerSpendingLimit
      ? BigInt(routerSpendingLimit)
      : (exactAmountInField ?? MAX_UINT160)

    setPendingLeg('approve-permit2-router')
    setApprovalState('approving')
    setApprovalError('')

    try {
      await setPermit2Allowance(tokenInAddress, routerAddress, amount)
      await refetchPermit2Allowance()
      setApprovalState('success')
      setTimeout(() => setApprovalState('idle'), 3000)
    } catch (error) {
      setApprovalState('error')
      setApprovalError(parseContractError(error) || (error instanceof Error ? error.message : 'Router approval failed'))
      setTimeout(() => {
        setApprovalState('idle')
        setApprovalError('')
      }, 5000)
    } finally {
      setPendingLeg(null)
    }
  }, [useEthIn, tokenInAddress, address, publicClient, routerSpendingLimit, exactAmountInField, routerAddress, routerHasBytecode, routerBytecodeError, rpcChainId, resolvedChainId, setPermit2Allowance, refetchPermit2Allowance, MAX_UINT160, failApproval])

  const handleConnectWallet = useCallback(() => {
    const c = connectors[0]
    if (c) connect({ connector: c })
  }, [connect, connectors])

  const handleSwitchNetwork = useCallback(async () => {
    const target =
      typeof selectedChainId === 'number' && isSupportedChainId(selectedChainId)
        ? selectedChainId
        : CHAIN_ID_SEPOLIA
    try {
      setPendingLeg('switch')
      await switchChainAsync?.({ chainId: target })
    } catch (e) {
      failApproval(parseContractError(e) || 'Failed to switch network')
    } finally {
      setPendingLeg(null)
    }
  }, [selectedChainId, switchChainAsync, failApproval])

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
      // Propagate the accurate-swap simulation into the standard preview state
      // so it surfaces as Amount Out and enables the Swap button without any
      // separate UI path. In Signed mode this is the equivalent of the
      // Explicit-mode useActualSwapSimulation auto-switch — both paths end up
      // updating the same previewExactIn / previewExactOut state.
      if (isExactIn) {
        setPreviewExactIn(accurateResult)
        setPreviewExactInError(null)
      } else {
        setPreviewExactOut(accurateResult)
        setPreviewExactOutError(null)
      }
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
    // Execute path only — approvals must already be done via sequential ActionCta legs.
    // Do not call one-shot handleApproval from multi-leg UI (K17).
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
      setPendingLeg('execute')
      setLastSwapReceiptStatus('pending')
      setLastSwapTxHash(null)
      setLastSwapEthDeltaWei(null)
      setLastSwapEthNetReceivedWei(null)
      setLastSwapHookDebug(null)
      setLastSwapSentinelDebug(null)

      const preBalance = address ? await publicClient.getBalance({ address }) : null

      // Safety re-check of on-chain allowances only (not multi-leg UI). Pending stays on execute.
      if (!useEthIn && requiredAmountIn && effectiveApprovalMode === 'explicit') {
        setApprovalError('')
        try {
          await ensureSpendingLimits(requiredAmountIn)
        } catch (e) {
          setApprovalState('error')
          setApprovalError(parseContractError(e) || (e instanceof Error ? e.message : 'Approval failed'))
          setTimeout(() => {
            setApprovalState('idle')
            setApprovalError('')
          }, 5000)
          setPendingLeg(null)
          setLastSwapReceiptStatus(null)
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
    } finally {
      setPendingLeg(null)
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
    <div className="container mx-auto max-w-2xl px-4">
      <div className="mb-6 pt-4">
        <h1 className="text-2xl font-semibold tracking-tight text-[var(--text-primary,#EDEDED)] md:text-3xl">
          Swap
        </h1>
        <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)]">
          Exchange tokens via the Standard Exchange router.
        </p>
      </div>

      {!isConnected && (
        <div className="mb-4 rounded-lg border border-amber-500/40 bg-amber-600/15 p-3">
          <div className="text-sm font-medium text-amber-200">Wallet not connected</div>
          <div className="mt-1 text-xs text-amber-200/90">
            You can still preview quotes, but you&apos;ll need to connect a wallet to issue approvals or submit a swap.
          </div>
        </div>
      )}

      {isUnsupportedChain && (
        <div className="mb-4 rounded-lg border border-[var(--danger,#E6386A)]/40 bg-[var(--danger,#E6386A)]/10 p-3">
          <div className="text-sm font-medium text-[var(--danger,#E6386A)]">Unsupported network</div>
          <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
            Connected wallet chainId {walletChainId}. Switch to Sepolia ({CHAIN_ID_SEPOLIA}) or the local Anvil fork ({CHAIN_ID_ANVIL}).
          </div>
        </div>
      )}
       
      {/* Advanced: approval mode — default collapsed via showApprovalSettings false */}
      <div className="mb-4">
        <button
          type="button"
          onClick={() => setShowApprovalSettings(!showApprovalSettings)}
          className="flex w-full items-center justify-between rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] px-4 py-2 transition-colors hover:border-[var(--border-accent,rgba(79,212,75,0.45))]"
        >
          <div className="flex items-center gap-2">
            <span className="text-sm font-medium text-[var(--text-primary,#EDEDED)]">Advanced</span>
            <span className="text-xs text-[var(--text-muted,#9aa3b2)]">Approval settings</span>
          </div>
          <svg 
            className={`h-4 w-4 text-[var(--text-muted,#9aa3b2)] transition-transform ${showApprovalSettings ? 'rotate-180' : ''}`} 
            fill="none" 
            stroke="currentColor" 
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
        </button>
        
        {showApprovalSettings && (
          <div className="mt-2 rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] p-4">
            <div className="mb-3 text-xs text-[var(--text-muted,#9aa3b2)]">
              Choose how you authorize token transfers:
            </div>
            
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
          data-testid="swap-pool-select"
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
              data-testid="swap-token-in-select"
              value={tokenIn}
              onChange={(e) => {
                const next = e.target.value
                setTokenIn(next)

                // ETH handling UX:
                // - Selecting ETH means "I'm paying with native ETH" -> enable "Use ETH".
                // - Selecting WETH9 means "I'm paying with the WETH token directly".
                //   Reset useEthIn so a leftover toggle from a prior ETH selection doesn't
                //   silently flip the WETH-sentinel pool into the wrap branch.
                // - Selecting any other token must disable "Use ETH".
                setUseEthIn(next === 'ETH')
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
                  // For the WETH sentinel pool, wrap and unwrap are mutually exclusive
                  // (the router runs at most one of them per call). Auto-clear the
                  // opposite side so a leftover toggle can't silently force the wrong
                  // branch — see BalancerV3StandardExchangeRouterExactInSwapTarget.sol
                  // around the address(this).balance check.
                  if (isWethSentinelPool) {
                    setUseEthOut(false)
                  }

                  // "Use ETH" means we treat WETH9 as the onchain token but pay in native ETH.
                  // Ensure the selected token is compatible with this behavior.
                  if (tokenIn !== 'ETH' && !isWethValue(tokenIn)) {
                    setTokenIn(weth9Address ?? '')
                  }
                  return
                }

                // If the user unchecks while ETH is selected, fall back to WETH9 if available.
                setUseEthIn(false)
                if (tokenIn === 'ETH') {
                  setTokenIn(weth9Address ?? '')
                }
              }}
            />
            Use ETH (wrap to WETH)
          </label>
          </div>

        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">Token Out</label>
              <select
            data-testid="swap-token-out-select"
            value={tokenOut}
            onChange={(e) => {
              const next = e.target.value
              setTokenOut(next)

              // ETH handling UX:
              // - Selecting ETH means "I want native ETH back" -> enable "Use ETH".
              // - Selecting WETH9 means "I want the WETH token back". Reset useEthOut so a
              //   leftover toggle from a prior ETH selection doesn't keep the unwrap path on.
              // - Selecting any other token must disable "Use ETH".
              setUseEthOut(next === 'ETH')
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
                  // Mirror of the Use-ETH-In handler: wrap and unwrap are mutually
                  // exclusive for the WETH sentinel pool. See router contract.
                  if (isWethSentinelPool) {
                    setUseEthIn(false)
                  }

                  // "Use ETH" on output means we unwrap WETH9 to native ETH.
                  // Ensure tokenOut is compatible (WETH9 or ETH).
                  if (tokenOut !== 'ETH' && !isWethValue(tokenOut)) {
                    setTokenOut(weth9Address ?? '')
                  }
                  return
                }

                setUseEthOut(false)
                if (tokenOut === 'ETH') {
                  setTokenOut(weth9Address ?? '')
                }
              }}
            />
            Use ETH (unwrap from WETH)
            </label>
          </div>
        </div>

      {/* Vault Selection — Standard Exchange Router auto-detection hint */}
      {swapRouteAuto && swapRouteAuto.kind === 'pending' && (
        <div className="text-xs text-gray-400 mb-2">⏳ Resolving route…</div>
      )}
      {swapRouteAuto && swapRouteAuto.kind === 'ok' && (
        <div className="text-xs text-emerald-300 mb-2">
          Detected route: {swapRouteAuto.route}. Vault flags set automatically — toggle a checkbox to override.
        </div>
      )}
      {swapRouteAuto && swapRouteAuto.kind === 'ambiguous' && (
        <div className="text-xs text-amber-300 mb-2 space-y-1">
          <div>
            ⚠️ Ambiguous {swapRouteAuto.side === 'both' ? 'Token In and Token Out' : swapRouteAuto.side === 'in' ? 'Token In' : 'Token Out'} —
            multiple Standard Exchange Vaults in this pool can wrap your selection. Pick one to clarify:
          </div>
          {swapRouteAuto.tokenInCandidates && (
            <div>
              <span className="mr-1">Token In via:</span>
              {swapRouteAuto.tokenInCandidates.map((addr) => (
                <button
                  key={addr}
                  onClick={() => setSelectedVaultIn(addr as `0x${string}`)}
                  className="ml-1 px-2 py-0.5 bg-slate-700 hover:bg-slate-600 rounded text-emerald-200 font-mono"
                >
                  {addr.slice(0, 6)}…{addr.slice(-4)}
                </button>
              ))}
            </div>
          )}
          {swapRouteAuto.tokenOutCandidates && (
            <div>
              <span className="mr-1">Token Out via:</span>
              {swapRouteAuto.tokenOutCandidates.map((addr) => (
                <button
                  key={addr}
                  onClick={() => setSelectedVaultOut(addr as `0x${string}`)}
                  className="ml-1 px-2 py-0.5 bg-slate-700 hover:bg-slate-600 rounded text-emerald-200 font-mono"
                >
                  {addr.slice(0, 6)}…{addr.slice(-4)}
                </button>
              ))}
            </div>
          )}
        </div>
      )}
      {swapRouteAuto && swapRouteAuto.kind === 'invalid' && (
        <div className="text-xs text-amber-300 mb-2 space-y-1">
          <div>
            ⚠️ Selected Token In / Token Out don&apos;t match any Standard Exchange Router route for this pool.
          </div>
          <div>
            Pool tokens:{' '}
            <code>{swapRouteAuto.poolTokens.map((t) => `${t.slice(0, 6)}…${t.slice(-4)}`).join(', ')}</code>
          </div>
          {Array.from(swapRouteAuto.underlyingByVault.entries()).length > 0 && (
            <div>
              Vault → underlying mappings considered:
              <ul className="list-disc ml-5">
                {Array.from(swapRouteAuto.underlyingByVault.entries()).map(([vault, underlying]) => (
                  <li key={vault} className="font-mono">
                    {vault.slice(0, 6)}…{vault.slice(-4)} → {underlying.map((u) => `${u.slice(0, 6)}…${u.slice(-4)}`).join(', ')}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}
      <div className="grid grid-cols-2 gap-4 mb-6">
        <div>
          <label className="flex items-center gap-2 text-sm text-gray-300 mb-2">
            <input
              data-testid="swap-deposit-vault-toggle"
              type="checkbox"
              checked={useTokenInVault}
              onChange={(e) => {
                vaultFlagsManuallyToggled.current = true
                setUseTokenInVault(e.target.checked)
              }}
            />
            Use Token In Vault
          </label>
          {useTokenInVault && (
            <select
              data-testid="swap-vault-in-select"
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
              data-testid="swap-withdraw-vault-toggle"
              type="checkbox"
              checked={useTokenOutVault}
              onChange={(e) => {
                vaultFlagsManuallyToggled.current = true
                setUseTokenOutVault(e.target.checked)
              }}
            />
            Use Token Out Vault
            </label>
          {useTokenOutVault && (
              <select
                data-testid="swap-vault-out-select"
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
          data-testid="swap-amount-in"
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
          data-testid="swap-amount-out"
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
        {/* Surface why a quote isn't appearing — explicit-approval users were
            seeing the Swap button stay disabled with no visible reason because
            buildExactInArgs returned valid:false and the simulation silently
            never fired. */}
        {lastEditedField === 'in' && previewExactInError && (
          <div className="text-xs text-amber-300 mt-2">Quote error: {previewExactInError.message}</div>
        )}
        {lastEditedField === 'in' &&
          !previewExactInError &&
          !previewExactIn &&
          !!exactAmountInField && (
            <div className="text-xs text-gray-400 mt-2">
              {!routerReady
                ? '⏳ Router unavailable — see the warning above.'
                : !builtExactIn.valid
                  ? `⚠️ Cannot build a swap route from this selection. Missing: ${
                      builtExactIn.missing && builtExactIn.missing.length > 0
                        ? builtExactIn.missing.join(', ')
                        : '(no matching route — check the Use Token In/Out Vault toggles)'
                    }`
                  : previewExactInPending
                    ? useActualSwapSimulation
                      ? '⏳ Simulating swapSingleTokenExactIn on the router…'
                      : '⏳ Simulating querySwapSingleTokenExactIn on the router…'
                    : '⏳ Waiting for quote…'}
            </div>
          )}
      </div>

      {/* Route Info */}
      {routePattern && (
        <div data-testid="swap-route-pattern" className="mb-6 p-4 bg-slate-700/50 rounded-lg">
          <div className="text-sm text-blue-300 font-medium">Route: {routePattern}</div>
          <div className="text-xs text-gray-400 mt-1">
            {getRouteDescription()}
          </div>
        </div>
      )}
      
      {/* Preview — hierarchy: form → preview → ActionCta */}
      {lastEditedField === 'in' && previewExactIn && (
        <div className="mb-6 rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] p-4">
          <div className="text-sm font-medium text-[var(--text-primary,#EDEDED)]">Preview (Exact In)</div>
          <div className="mt-1 font-mono text-xs tabular-nums text-[var(--text-muted,#9aa3b2)]">
            Expected Output: {formatUnits(previewExactIn, tokenOutAddress ? getTokenDecimalsByAddressForChain(resolvedChainId, tokenOutAddress) : 18)} {tokenOut}
          </div>
          {minOut && (
            <div className="font-mono text-xs tabular-nums text-[var(--text-muted,#9aa3b2)]">
              Minimum Output: {formatUnits(minOut, tokenOutAddress ? getTokenDecimalsByAddressForChain(resolvedChainId, tokenOutAddress) : 18)} {tokenOut}
            </div>
          )}
        </div>
      )}

      {lastEditedField === 'out' && previewExactOut && (
        <div className="mb-6 rounded-xl border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] p-4">
          <div className="text-sm font-medium text-[var(--text-primary,#EDEDED)]">Preview (Exact Out)</div>
          <div className="mt-1 font-mono text-xs tabular-nums text-[var(--text-muted,#9aa3b2)]">
            Expected Input: {formatUnits(previewExactOut, tokenInAddress ? getTokenDecimalsByAddressForChain(resolvedChainId, tokenInAddress) : 18)} {tokenIn}
          </div>
          <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
            Preview is conservative for exact-out: actual input used may be lower.
          </div>
          {maxIn && (
            <div className="font-mono text-xs tabular-nums text-[var(--text-muted,#9aa3b2)]">
              Maximum Input: {formatUnits(maxIn, tokenInAddress ? getTokenDecimalsByAddressForChain(resolvedChainId, tokenInAddress) : 18)} {tokenIn}
            </div>
          )}
        </div>
      )}
      
      {/* Primary action strip: single multi-leg ActionCta (never Approve + Swap together). */}
      <Card className="space-y-3 p-4">
        {/* Secondary advanced (signed quote / spending limits) — default collapsed */}
        <details className="rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)]">
          <summary className="cursor-pointer px-3 py-2 text-sm text-[var(--text-muted,#9aa3b2)]">
            Advanced options
          </summary>
          <div className="space-y-3 border-t border-[var(--border-subtle,rgba(255,255,255,0.08))] p-3">
            {approvalMode === 'signed' && !useEthIn && (
              <div className="rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] p-3">
                <div className="text-sm font-medium text-[var(--text-primary,#EDEDED)]">Signed approval mode</div>
                <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
                  Sign a permit with your wallet for the swap. Pre-approval is only needed for Token → Permit2 when allowance is insufficient.
                </div>
              </div>
            )}

            {approvalMode === 'signed' &&
              !useEthIn &&
              ((lastEditedField === 'in' && builtExactIn.valid) ||
                (lastEditedField === 'out' && builtExactOut.valid)) && (
                <div className="rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] p-3">
                  <div className="mb-2 text-xs text-[var(--text-muted,#9aa3b2)]">
                    Optional: sign a permit to simulate an accurate quote before swapping.
                  </div>
                  {accurateQuote && (
                    <div className="mb-2 w-full rounded-md border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] p-3 text-[var(--text-primary,#EDEDED)]">
                      <div className="mb-1 text-sm text-[var(--text-muted,#9aa3b2)]">
                        {lastEditedField === 'in' ? 'Accurate Quote' : "You'll Pay"}
                      </div>
                      <div className="font-mono text-base tabular-nums">
                        {lastEditedField === 'in'
                          ? `${formatUnits(accurateQuote, tokenOutDecimals)} ${/^0x[a-fA-F0-9]{40}$/.test(tokenOut) ? 'Token Out' : tokenOut}`
                          : `${formatUnits(accurateQuote, tokenInDecimals)} ${/^0x[a-fA-F0-9]{40}$/.test(tokenIn) ? 'Token In' : tokenIn}`}
                      </div>
                    </div>
                  )}
                  <button
                    type="button"
                    onClick={handleGetAccurateQuote}
                    disabled={
                      accurateQuoteLoading ||
                      (!exactAmountInField && lastEditedField === 'in') ||
                      (!exactAmountOutField && lastEditedField === 'out')
                    }
                    className="w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] py-2 px-4 text-sm text-[var(--text-primary,#EDEDED)] disabled:opacity-50"
                  >
                    {accurateQuoteLoading ? 'Getting Accurate Quote...' : 'Get Accurate Quote (Sign Permit)'}
                  </button>
                  {accurateQuoteError && (
                    <div className="mt-2 text-xs text-[var(--danger,#E6386A)]">{accurateQuoteError}</div>
                  )}
                </div>
              )}

            {swapWalletGate.kind === 'approve' && swapWalletGate.leg === 'token-permit2' && !useEthIn && (
              <div
                data-testid="swap-approve-permit2-limits"
                className="rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] p-3"
              >
                <div className="mb-2 text-xs text-[var(--text-muted,#9aa3b2)]">
                  Token → Permit2 spending limit (optional)
                </div>
                <div className="relative">
                  <input
                    type="number"
                    placeholder="Token → Permit2 spending limit"
                    value={permit2SpendingLimit}
                    onChange={(e) => setPermit2SpendingLimit(e.target.value)}
                    className="w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 pr-16 text-sm text-[var(--text-primary,#EDEDED)]"
                  />
                  <button
                    type="button"
                    onClick={() => handleSetPermit2SpendingLimit(MAX_UINT160)}
                    className="absolute right-1 top-1/2 -translate-y-1/2 rounded bg-[var(--surface-1,#14171f)] px-2 py-1 text-xs text-[var(--text-primary,#EDEDED)] hover:brightness-110"
                  >
                    Max
                  </button>
                </div>
                {tokenAllowance !== undefined && (
                  <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
                    Current: {tokenAllowance.toString()} wei
                  </div>
                )}
              </div>
            )}
            {swapWalletGate.kind === 'approve' &&
              swapWalletGate.leg === 'permit2-router' &&
              approvalMode === 'explicit' &&
              !useEthIn && (
                <div
                  data-testid="swap-approve-router-limits"
                  className="rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)] p-3"
                >
                  <div className="mb-2 text-xs text-[var(--text-muted,#9aa3b2)]">
                    Permit2 → Router spending limit (optional)
                  </div>
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
                      className="w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 pr-16 text-sm text-[var(--text-primary,#EDEDED)]"
                    />
                    <button
                      type="button"
                      onClick={() => handleSetRouterSpendingLimit(MAX_UINT160)}
                      className="absolute right-1 top-1/2 -translate-y-1/2 rounded bg-[var(--surface-1,#14171f)] px-2 py-1 text-xs text-[var(--text-primary,#EDEDED)] hover:brightness-110"
                    >
                      Max
                    </button>
                  </div>
                  {permit2Allowance?.[0] !== undefined && (
                    <div className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
                      Current: {permit2Allowance[0].toString()} wei
                    </div>
                  )}
                </div>
              )}
          </div>
        </details>

        {/* Explicit mode: router availability warnings (not primary CTA) */}
        {approvalMode === 'explicit' && !useEthIn && !routerSpenderAddress && (
          <div className="rounded-lg border border-amber-600/50 bg-amber-700/20 p-3 text-sm text-amber-200">
            Swap router not deployed on this chain. Deploy{' '}
            <code className="mx-1 rounded bg-[var(--surface-0,#0a0a0a)] px-1">balancerV3StandardExchangeRouter</code>{' '}
            before Permit2 → Router approval.
          </div>
        )}
        {approvalMode === 'explicit' &&
          !useEthIn &&
          routerSpenderAddress &&
          routerHasBytecode === false && (
            <div className="rounded-lg border border-amber-600/50 bg-amber-700/20 p-3 text-sm text-amber-200">
              Swap router address {routerSpenderAddress} has no bytecode on this chain.
              {routerBytecodeError ? ` (${routerBytecodeError})` : ''}
            </div>
          )}

        {approvalState === 'success' && (
          <div className="w-full rounded-md bg-[var(--accent,#4FD44B)]/80 py-2 px-3 text-center text-sm text-black">
            Approval confirmed. Continue with the next step.
          </div>
        )}
        {approvalState === 'error' && approvalError && (
          <div className="w-full rounded-md bg-[var(--danger,#E6386A)]/80 py-2 px-3 text-center text-sm text-white">
            {approvalError}
          </div>
        )}

        <DebugPanel title="🔍 Swap Button State" className="mt-2">
          <div>Gate: {swapWalletGate.kind}
            {swapWalletGate.kind === 'approve' ? ` (${swapWalletGate.leg})` : ''}
            {swapWalletGate.kind === 'disabled' ? ` (${swapWalletGate.reason})` : ''}
          </div>
          <div>Pending leg: {effectiveSwapPendingLeg ?? 'null'}</div>
          <div>Mode: {lastEditedField === 'in' ? 'Exact In' : 'Exact Out'}</div>
          <div>
            Ready: {ready ? '✅' : '❌'} | Preview: {hasPreviewForGate ? '✅' : '❌'} | NeedsApproval:{' '}
            {needsApproval ? '❌' : '✅'}
          </div>
          <div>Allowances Ready: {allowancesReady ? '✅' : '❌'}</div>
          <div>Approval mode: {approvalMode} | signedMode gate: {String(effectiveApprovalMode === 'signed')}</div>
        </DebugPanel>

        <button
          data-testid="swap-preview"
          type="button"
          onClick={() => {
            lastCompletedPreviewKeyRef.current = null
            handlePreview()
          }}
          disabled={!previewReady && !builtExactIn.valid && !builtExactOut.valid}
          className="w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] py-2 px-4 text-sm text-[var(--text-primary,#EDEDED)] disabled:opacity-50"
        >
          {previewExactInPending || previewExactOutPending ? 'Refreshing quote…' : 'Refresh Quote'}
        </button>

        {/*
          Single sequential primary CTA.
          Explicit: onApproveTokenPermit2 → handleIssuePermit2Approval only;
                    onApprovePermit2Router → handleIssueRouterApproval only.
          Signed: signedMode omits permit2→router; only token→Permit2 then execute/sign path.
          Never wire onClick to one-shot handleApproval for multi-leg sequential UI (K17).
        */}
        <ActionCta
          data-testid="swap-submit"
          className="w-full"
          gate={swapWalletGate}
          pendingLeg={effectiveSwapPendingLeg}
          onConnect={handleConnectWallet}
          onSwitchNetwork={() => void handleSwitchNetwork()}
          onApproveTokenPermit2={() => void handleIssuePermit2Approval()}
          onApprovePermit2Router={() => void handleIssueRouterApproval()}
          onExecute={() => void handleSwap()}
        />
      </Card>
      
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

export default function SwapPage() {
  return (
    <Suspense fallback={<div className="text-sm text-gray-400 py-8">Loading swap…</div>}>
      <SwapPageInner />
    </Suspense>
  )
}
