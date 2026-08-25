'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import { decodeEventLog, type Address } from 'viem'
import { useAccount, useConnect, usePublicClient, useReadContract, useSwitchChain, useWriteContract } from 'wagmi'

import { CHAIN_ID_ANVIL, CHAIN_ID_LOCALHOST } from '@indexedex/protocol/addressArtifacts'
import type { TokenListEntry } from '@indexedex/protocol/tokenlists'
import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'

import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { ActionCta } from '../components/ui/ActionCta'
import { resolveWalletGate } from '../lib/tx/actionState'
import { parseContractError } from '../lib/tx/parseContractError'
import { toPoolId } from '../swap/lib/v4PoolId'
import { ZERO_ADDRESS } from '../swap/lib/v4Types'

import {
  NEW_VAULT_EVENT,
  V3_FACTORY_ABI,
  V3_POOL_ABI,
  V3_SE_PKG_ABI,
  V4_POOL_MANAGER_ABI,
  V4_SE_PKG_ABI,
  VAULT_REGISTRY_SE_ABI,
  VAULT_TOKENS_ABI,
} from './lib/seAbi'
import { resolveSePlatform } from './lib/sePlatform'
import { createAppReadClient, readV4PoolInitialized, uniqueAddresses } from './lib/sePoolRead'
import {
  SQRT_PRICE_1_1,
  V3_FEE_TIERS,
  V4_FEE_TIERS,
  isPoolAlreadyExistsError,
  checksumAddress,
  parseV3PoolAddressInput,
  poolActionLabel,
  poolReadyState,
  poolStatusCopy,
  type PoolVersion,
  sortPoolTokens,
  sqrtPriceX96FromHuman,
  tickSpacingForV3Fee,
} from './lib/sePool'

const inputClass =
  'mt-1 w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm text-[var(--text-primary,#EDEDED)] placeholder:text-[var(--text-muted,#9aa3b2)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--accent,#4FD44B)]'

function shortAddr(addr: string): string {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`
}

function same(a: string, b: string): boolean {
  return a.toLowerCase() === b.toLowerCase()
}

export function SeVaultSlot({
  listedVaults,
  tokens,
  selectedVault,
  pairToken,
  weight,
  showWeight,
  persistPair,
  onSelectVault,
  onSelectPair,
  onWeight,
  testIdPrefix,
}: {
  listedVaults: TokenListEntry[]
  tokens: TokenListEntry[]
  selectedVault: `0x${string}` | ''
  pairToken: `0x${string}` | ''
  weight?: string
  showWeight?: boolean
  persistPair?: boolean
  onSelectVault: (vault: `0x${string}` | '') => void
  onSelectPair: (token: `0x${string}` | '') => void
  onWeight?: (value: string) => void
  testIdPrefix: string
}) {
  const { selectedChainId } = useSelectedNetwork()
  const { environment } = useDeploymentEnvironment()
  const { connect, connectors } = useConnect()
  const { switchChainAsync } = useSwitchChain()
  const { writeContractAsync } = useWriteContract()
  const publicClient = usePublicClient({ chainId: selectedChainId })
  const { address, isConnected, chainId: walletChainId } = useAccount()

  const platform = useMemo(
    () => resolveSePlatform(selectedChainId, environment),
    [selectedChainId, environment],
  )

  const [source, setSource] = useState<'listed' | 'build'>(listedVaults.length > 0 ? 'listed' : 'build')
  const [tokenA, setTokenA] = useState<`0x${string}` | ''>('')
  const [tokenB, setTokenB] = useState<`0x${string}` | ''>('')
  const [version, setVersion] = useState<PoolVersion>('v4')
  const [fee, setFee] = useState(3000)
  const [tickSpacing, setTickSpacing] = useState(60)
  const [hooks, setHooks] = useState<string>(ZERO_ADDRESS)
  const [width, setWidth] = useState('1')
  const [initPrice, setInitPrice] = useState('1')
  const [status, setStatus] = useState<string | null>(null)
  const [pending, setPending] = useState<'pool' | 'vault' | null>(null)
  const [deployAnother, setDeployAnother] = useState(false)
  const [confirmedPoolKey, setConfirmedPoolKey] = useState('')
  const [discoverTick, setDiscoverTick] = useState(0)
  const [v4Live, setV4Live] = useState(false)
  const [httpVaults, setHttpVaults] = useState<Address[]>([])
  const [localPair, setLocalPair] = useState<`0x${string}` | ''>(pairToken)
  const [v4Entry, setV4Entry] = useState<'tokens' | 'poolkey'>('tokens')
  const [customFee, setCustomFee] = useState(false)
  const [v3Entry, setV3Entry] = useState<'tokens' | 'pool'>('tokens')
  const [v3PoolRaw, setV3PoolRaw] = useState('')
  const [v3PoolError, setV3PoolError] = useState<string | null>(null)
  const [appliedV3, setAppliedV3] = useState<{
    pool: Address
    tokenA: Address
    tokenB: Address
    fee: number
  } | null>(null)
  const [v3ApplyPending, setV3ApplyPending] = useState(false)

  const readClient = useMemo(() => createAppReadClient(selectedChainId), [selectedChainId])

  const sorted = useMemo(() => {
    if (!tokenA || !tokenB || same(tokenA, tokenB)) return null
    const [currency0, currency1] = sortPoolTokens(tokenA, tokenB)
    return { currency0, currency1 }
  }, [tokenA, tokenB])

  const pairKey = sorted ? `${version}:${fee}:${tickSpacing}:${hooks}:${sorted.currency0}:${sorted.currency1}` : ''
  const prevPairKey = useRef(pairKey)

  const v4Key = useMemo(() => {
    if (!sorted || version !== 'v4') return null
    const currency0 = checksumAddress(sorted.currency0)
    const currency1 = checksumAddress(sorted.currency1)
    if (!currency0 || !currency1) return null
    return {
      currency0,
      currency1,
      fee,
      tickSpacing,
      hooks: checksumAddress(hooks) ?? ZERO_ADDRESS,
    }
  }, [sorted, version, fee, tickSpacing, hooks])

  const v4PoolId = v4Key ? toPoolId(v4Key) : undefined

  const { data: v3PoolAddr, refetch: refetchV3Pool } = useReadContract({
    address: platform.v3Factory ?? undefined,
    abi: V3_FACTORY_ABI,
    functionName: 'getPool',
    args: sorted ? [sorted.currency0, sorted.currency1, fee] : undefined,
    chainId: selectedChainId,
    query: { enabled: version === 'v3' && !!platform.v3Factory && !!sorted },
  })

  const appliedV3Matches = Boolean(
    appliedV3 &&
      tokenA &&
      tokenB &&
      appliedV3.fee === fee &&
      ((same(tokenA, appliedV3.tokenA) && same(tokenB, appliedV3.tokenB)) ||
        (same(tokenA, appliedV3.tokenB) && same(tokenB, appliedV3.tokenA))),
  )
  const v3PoolForReads: Address | undefined =
    (appliedV3Matches ? appliedV3!.pool : undefined) ||
    (v3PoolAddr && v3PoolAddr !== ZERO_ADDRESS ? (v3PoolAddr as Address) : undefined)

  const { data: v3Slot0, refetch: refetchV3Slot } = useReadContract({
    address: v3PoolForReads,
    abi: V3_POOL_ABI,
    functionName: 'slot0',
    chainId: selectedChainId,
    query: { enabled: version === 'v3' && !!v3PoolForReads },
  })

  const pkg = version === 'v4' ? platform.uniV4SePkg : platform.uniV3SePkg
  const pairTokens = useMemo(
    () => (sorted ? ([sorted.currency0, sorted.currency1] as Address[]) : undefined),
    [sorted],
  )

  const candidateVaults = httpVaults

  useEffect(() => {
    if (source !== 'build' || !sorted) {
      setV4Live(false)
      setHttpVaults([])
      return
    }
    let cancelled = false
    const run = async () => {
      try {
        if (version === 'v4') {
          if (!platform.poolManager || !v4PoolId) {
            if (!cancelled) {
              setV4Live(false)
              setHttpVaults([])
            }
            return
          }
          const live = await readV4PoolInitialized(readClient, platform.poolManager, v4PoolId)
          if (cancelled) return
          setV4Live(live)
          if (!live || !platform.registry || !pkg || !pairTokens) {
            setHttpVaults([])
            return
          }
          const raw = (await readClient.readContract({
            address: platform.registry,
            abi: VAULT_REGISTRY_SE_ABI,
            functionName: 'vaultsOfPkgOfTokens',
            args: [pkg, pairTokens],
          })) as Address[]
          if (!cancelled) setHttpVaults(uniqueAddresses(raw))
          return
        }
        if (!cancelled) setV4Live(false)
      } catch {
        if (!cancelled) {
          setV4Live(false)
          setHttpVaults([])
        }
      }
    }
    void run()
    return () => {
      cancelled = true
    }
  }, [
    source,
    sorted,
    version,
    v4PoolId,
    pairTokens,
    pkg,
    platform.poolManager,
    platform.registry,
    readClient,
    discoverTick,
  ])

  const { data: selectedVaultTokens, refetch: refetchVaultTokens } = useReadContract({
    address: selectedVault || undefined,
    abi: VAULT_TOKENS_ABI,
    functionName: 'vaultTokens',
    chainId: selectedChainId,
    query: { enabled: !!selectedVault },
  })

  const pairOptions = useMemo(() => {
    const addrs = (selectedVaultTokens as Address[] | undefined) ?? []
    return addrs.map((addr) => {
      const known = tokens.find((t) => t.address.toLowerCase() === addr.toLowerCase())
      return {
        address: addr,
        symbol: known?.symbol ?? shortAddr(addr),
        name: known?.name ?? 'Vault token',
      }
    })
  }, [selectedVaultTokens, tokens])

  const effectivePair = persistPair === false ? localPair || pairToken : pairToken

  useEffect(() => {
    if (!selectedVault || pairOptions.length === 0) return
    const ok = pairOptions.some((p) => effectivePair && same(p.address, effectivePair))
    if (ok) return
    const next = '' as const
    setLocalPair(next)
    if (pairToken) onSelectPair(next)
  }, [selectedVault, pairOptions, effectivePair, pairToken, onSelectPair])

  useEffect(() => {
    if (source !== 'build') return
    if (prevPairKey.current === pairKey) return
    prevPairKey.current = pairKey
    setDeployAnother(false)
    setConfirmedPoolKey('')
    setV4Live(false)
    setHttpVaults([])
    if (selectedVault) onSelectVault('')
  }, [pairKey, source, selectedVault, onSelectVault])

  useEffect(() => {
    if (source !== 'build') return
    if (selectedVault) return
    if (confirmedPoolKey === pairKey) return
    if (candidateVaults.length === 1) onSelectVault(candidateVaults[0]!)
  }, [source, selectedVault, candidateVaults, onSelectVault, confirmedPoolKey, pairKey])

  const v3PoolExists = !!v3PoolForReads
  const v3Initialized = v3PoolExists && !!v3Slot0 && (v3Slot0[0] as bigint) > BigInt(0)
  const v4Exists = v4Live
  const justCreatedThisPool = confirmedPoolKey !== '' && confirmedPoolKey === pairKey
  const readyState = poolReadyState({
    version,
    v3PoolExists,
    v3Initialized,
    v4Exists: v4Exists || (version === 'v4' && justCreatedThisPool),
  })
  const poolExists = readyState === 'ready' || justCreatedThisPool
  const v4PoolKeyWarning =
    version === 'v4' && v4Entry === 'poolkey'
      ? tokenA && !checksumAddress(tokenA)
        ? 'currency0 is not a valid address.'
        : tokenB && !checksumAddress(tokenB)
          ? 'currency1 is not a valid address.'
          : hooks.trim() && !checksumAddress(hooks)
            ? 'hooks is not a valid address.'
            : tokenA && tokenB && same(tokenA, tokenB)
              ? 'The two pool tokens must be different.'
              : v4Key && !poolExists
                ? 'No initialized pool with this key on this network.'
                : null
      : null

  const listedOptions = useMemo(() => {
    const list = listedVaults.slice()
    if (selectedVault && !list.some((v) => same(v.address, selectedVault))) {
      list.unshift({
        chainId: selectedChainId,
        address: selectedVault,
        name: 'Deployed SE vault',
        symbol: shortAddr(selectedVault),
        decimals: 18,
        tags: ['vault', 'se'],
      })
    }
    return list
  }, [listedVaults, selectedVault, selectedChainId])

  const canAct = !!sorted && tokenA !== tokenB
  const v3Ready = version !== 'v3' || !!platform.v3Factory
  const v4Ready = version !== 'v4' || !!platform.poolManager
  const pkgReady = version === 'v4' ? !!platform.uniV4SePkg : !!platform.uniV3SePkg
  const networkReady = version === 'v3' ? v3Ready : v4Ready

  const poolGate = resolveWalletGate({
    isConnected,
    isWrongNetwork: false,
    amountValid: canAct && networkReady,
    hasPreview: canAct && networkReady,
    needsTokenApproval: false,
    needsPermit2Approval: false,
    executeLabel: poolActionLabel(readyState),
  })

  const vaultGate = resolveWalletGate({
    isConnected,
    isWrongNetwork: false,
    amountValid: canAct && pkgReady,
    hasPreview: canAct && pkgReady,
    needsTokenApproval: false,
    needsPermit2Approval: false,
    executeLabel: 'Deploy SE vault',
  })

  const widthMul = (() => {
    const n = Number(width)
    if (!Number.isFinite(n) || n < 1 || n > 1_000_000) return 1
    return Math.floor(n)
  })()

  const refetchAll = async () => {
    setDiscoverTick((n) => n + 1)
    await Promise.all([refetchV3Pool(), refetchV3Slot(), refetchVaultTokens()])
  }

  const connectWallet = () => {
    const connector =
      connectors.find((c) => c.id === 'metaMask' || c.id === 'metaMaskSDK') ??
      connectors.find((c) => c.id === 'injected') ??
      connectors[0]
    if (connector) connect({ connector })
  }

  const writeOnAppNetwork = async (params: Parameters<typeof writeContractAsync>[0]) => {
    const localWallet =
      walletChainId === CHAIN_ID_ANVIL || walletChainId === CHAIN_ID_LOCALHOST
    if (
      typeof walletChainId === 'number' &&
      walletChainId !== selectedChainId &&
      !localWallet
    ) {
      await switchChainAsync({ chainId: selectedChainId })
    }
    const { chainId: _c, chain: _ch, ...rest } = params as typeof params & { chainId?: number; chain?: unknown }
    return writeContractAsync(rest)
  }

  const runTx = async (kind: 'pool' | 'vault') => {
    setStatus(null)
    if (!sorted) {
      setStatus('Pick two different tokens.')
      return
    }
    if (!publicClient) {
      setStatus('No RPC client.')
      return
    }
    setPending(kind)
    try {
      const sqrtPrice = sqrtPriceX96FromHuman(initPrice) || SQRT_PRICE_1_1
      if (kind === 'pool') {
        if (version === 'v3') {
          if (!platform.v3Factory) throw new Error('No Uniswap V3 factory on this network.')
          if (!v3PoolExists) {
            const hash = await writeOnAppNetwork({
              address: platform.v3Factory,
              abi: V3_FACTORY_ABI,
              functionName: 'createPool',
              args: [sorted.currency0, sorted.currency1, fee],
            })
            await publicClient.waitForTransactionReceipt({ hash })
          }
          const pool = v3PoolForReads
            ? v3PoolForReads
            : ((await publicClient.readContract({
                address: platform.v3Factory,
                abi: V3_FACTORY_ABI,
                functionName: 'getPool',
                args: [sorted.currency0, sorted.currency1, fee],
              })) as Address)
          if (!pool || pool === ZERO_ADDRESS) throw new Error('Pool was not created.')
          const slot = await publicClient.readContract({
            address: pool,
            abi: V3_POOL_ABI,
            functionName: 'slot0',
          })
          if (!slot || (slot[0] as bigint) === BigInt(0)) {
            try {
              const hash = await writeOnAppNetwork({
                address: pool,
                abi: V3_POOL_ABI,
                functionName: 'initialize',
                args: [sqrtPrice],
              })
              await publicClient.waitForTransactionReceipt({ hash })
            } catch (err) {
              if (!isPoolAlreadyExistsError(err)) throw err
            }
          }
        } else {
          if (!platform.poolManager) throw new Error('No Uniswap V4 pool manager on this network.')
          if (!v4Key) throw new Error('Need two tokens, fee, and tick spacing.')
          try {
            const hash = await writeOnAppNetwork({
              address: platform.poolManager,
              abi: V4_POOL_MANAGER_ABI,
              functionName: 'initialize',
              args: [v4Key, sqrtPrice],
            })
            await publicClient.waitForTransactionReceipt({ hash })
          } catch (err) {
            if (!isPoolAlreadyExistsError(err)) throw err
          }
        }
        setConfirmedPoolKey(pairKey)
        setStatus('Pool is ready. Deploy the SE vault next.')
      } else {
        const w = widthMul as number
        let vault: Address | undefined
        if (version === 'v4') {
          if (!platform.uniV4SePkg) throw new Error('No Uniswap V4 SE package on this network.')
          if (!v4Key) throw new Error('Need a V4 pool key.')
          try {
            await publicClient.estimateContractGas({
              address: platform.uniV4SePkg,
              abi: V4_SE_PKG_ABI,
              functionName: 'deployVault',
              args: [v4Key, w],
              account: address,
              gas: 16_000_000n,
            })
          } catch (err) {
            throw new Error(parseContractError(err))
          }
          const hash = await writeOnAppNetwork({
            address: platform.uniV4SePkg,
            abi: V4_SE_PKG_ABI,
            functionName: 'deployVault',
            args: [v4Key, w],
          })
          const receipt = await publicClient.waitForTransactionReceipt({ hash })
          vault = vaultFromReceipt(receipt.logs, platform.uniV4SePkg)
        } else {
          if (!platform.uniV3SePkg) throw new Error('No Uniswap V3 SE package on this network.')
          const pool =
            v3PoolForReads && v3PoolForReads !== ZERO_ADDRESS
              ? v3PoolForReads
              : ((await publicClient.readContract({
                  address: platform.v3Factory!,
                  abi: V3_FACTORY_ABI,
                  functionName: 'getPool',
                  args: [sorted.currency0, sorted.currency1, fee],
                })) as Address)
          if (!pool || pool === ZERO_ADDRESS) throw new Error('Create the V3 pool first.')
          const hash = await writeOnAppNetwork({
            address: platform.uniV3SePkg,
            abi: V3_SE_PKG_ABI,
            functionName: 'deployVault',
            args: [pool, w],
          })
          const receipt = await publicClient.waitForTransactionReceipt({ hash })
          vault = vaultFromReceipt(receipt.logs, platform.uniV3SePkg)
        }
        if (vault) {
          onSelectVault(vault)
          setDeployAnother(false)
        }
        setStatus('SE vault deployed.')
      }
      await refetchAll()
    } catch (err) {
      setStatus(parseContractError(err))
    } finally {
      setPending(null)
    }
  }

  const feeTiers = version === 'v3' ? V3_FEE_TIERS : V4_FEE_TIERS
  const showDeploy =
    poolExists && (candidateVaults.length === 0 || deployAnother || justCreatedThisPool)
  const showPickExisting =
    poolExists && candidateVaults.length > 0 && !deployAnother && !justCreatedThisPool

  const pickPair = (token: `0x${string}` | '') => {
    setLocalPair(token)
    onSelectPair(token)
  }

  const applyV3Pool = async () => {
    const parsed = parseV3PoolAddressInput(v3PoolRaw)
    if (typeof parsed !== 'string') {
      setV3PoolError(parsed.error)
      return
    }
    const client = readClient ?? publicClient
    if (!client) {
      setV3PoolError('No RPC client.')
      return
    }
    setV3ApplyPending(true)
    setV3PoolError(null)
    try {
      const code = await client.getCode({ address: parsed })
      if (!code || code === '0x') {
        setV3PoolError('No contract at that address.')
        return
      }
      const [token0, token1, poolFee, poolTick] = await Promise.all([
        client.readContract({ address: parsed, abi: V3_POOL_ABI, functionName: 'token0' }),
        client.readContract({ address: parsed, abi: V3_POOL_ABI, functionName: 'token1' }),
        client.readContract({ address: parsed, abi: V3_POOL_ABI, functionName: 'fee' }),
        client.readContract({ address: parsed, abi: V3_POOL_ABI, functionName: 'tickSpacing' }),
      ])
      const c0 = checksumAddress(token0 as string)
      const c1 = checksumAddress(token1 as string)
      const feeN = Number(poolFee)
      if (!c0 || !c1 || c0.toLowerCase() === c1.toLowerCase()) {
        setV3PoolError('That contract is not a Uniswap V3 pool.')
        return
      }
      if (!Number.isFinite(feeN) || !Number.isInteger(feeN) || feeN < 0) {
        setV3PoolError('Could not read the pool fee.')
        return
      }
      const tickN = Number(poolTick)
      setAppliedV3({ pool: parsed, tokenA: c0, tokenB: c1, fee: feeN })
      setVersion('v3')
      setHooks(ZERO_ADDRESS)
      setTokenA(c0)
      setTokenB(c1)
      setFee(feeN)
      setTickSpacing(
        Number.isFinite(tickN) && Number.isInteger(tickN) && tickN > 0
          ? tickN
          : tickSpacingForV3Fee(feeN),
      )
      setCustomFee(!V3_FEE_TIERS.some((t) => t.fee === feeN))
      const slot = await client.readContract({
        address: parsed,
        abi: V3_POOL_ABI,
        functionName: 'slot0',
      })
      if (slot && (slot[0] as bigint) > 0n) {
        const [sorted0, sorted1] = sortPoolTokens(c0, c1)
        setConfirmedPoolKey(
          `v3:${feeN}:${Number.isFinite(tickN) && tickN > 0 ? tickN : tickSpacingForV3Fee(feeN)}:${ZERO_ADDRESS}:${sorted0}:${sorted1}`,
        )
      }
    } catch {
      setV3PoolError('That contract is not a Uniswap V3 pool.')
    } finally {
      setV3ApplyPending(false)
    }
  }

  return (
    <div className="space-y-4" data-testid={testIdPrefix}>
      <div className="flex flex-wrap gap-2">
        <Button
          type="button"
          size="sm"
          variant={source === 'listed' ? 'primary' : 'secondary'}
          onClick={() => setSource('listed')}
        >
          Listed SE vault
        </Button>
        <Button
          type="button"
          size="sm"
          variant={source === 'build' ? 'primary' : 'secondary'}
          onClick={() => setSource('build')}
          data-testid={`${testIdPrefix}-build`}
        >
          Tokens and pool
        </Button>
      </div>

      {source === 'listed' ? (
        <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
          SE vault
          <select
            className={inputClass}
            value={selectedVault}
            onChange={(e) => onSelectVault((e.target.value as `0x${string}`) || '')}
            data-testid={`${testIdPrefix}-listed`}
          >
            <option value="">Select an SE vault</option>
            {listedOptions.map((v) => (
              <option key={v.address} value={v.address}>
                {v.symbol} · {v.name}
              </option>
            ))}
          </select>
          {listedVaults.length === 0 ? (
            <p className="mt-2 text-xs text-[var(--text-muted,#9aa3b2)]">
              No listed SE vaults on this network. Use Tokens and pool to create one.
            </p>
          ) : null}
        </label>
      ) : (
        <Card>
          <p className="landing-section-label">Pool</p>
          {version === 'v4' ? (
            <div className="mt-4 flex flex-wrap gap-2">
              <Button
                type="button"
                size="sm"
                variant={v4Entry === 'tokens' ? 'primary' : 'secondary'}
                onClick={() => setV4Entry('tokens')}
                data-testid={`${testIdPrefix}-v4-entry-tokens`}
              >
                Tokens
              </Button>
              <Button
                type="button"
                size="sm"
                variant={v4Entry === 'poolkey' ? 'primary' : 'secondary'}
                onClick={() => setV4Entry('poolkey')}
                data-testid={`${testIdPrefix}-v4-entry-poolkey`}
              >
                Pool key
              </Button>
            </div>
          ) : null}
          {version === 'v3' ? (
            <div className="mt-4 flex flex-wrap gap-2">
              <Button
                type="button"
                size="sm"
                variant={v3Entry === 'tokens' ? 'primary' : 'secondary'}
                onClick={() => setV3Entry('tokens')}
                data-testid={`${testIdPrefix}-v3-entry-tokens`}
              >
                Tokens
              </Button>
              <Button
                type="button"
                size="sm"
                variant={v3Entry === 'pool' ? 'primary' : 'secondary'}
                onClick={() => setV3Entry('pool')}
                data-testid={`${testIdPrefix}-v3-entry-pool`}
              >
                Pool address
              </Button>
            </div>
          ) : null}
          {version === 'v4' && v4Entry === 'poolkey' ? (
            <p className="mt-4 text-xs text-[var(--text-muted,#9aa3b2)]">
              The SE vault deploys with this Uniswap V4 pool key. Native ETH is
              currency0 {ZERO_ADDRESS}, not wrapped ETH.
            </p>
          ) : null}
          {version === 'v3' && v3Entry === 'pool' ? (
            <div className="mt-4 space-y-3">
              <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
                Pool address
                <input
                  className={`${inputClass} font-mono`}
                  value={v3PoolRaw}
                  onChange={(e) => {
                    setV3PoolRaw(e.target.value)
                    if (v3PoolError) setV3PoolError(null)
                  }}
                  data-testid={`${testIdPrefix}-v3-pool`}
                  spellCheck={false}
                  autoComplete="off"
                />
                <span className="mt-1 block text-xs text-[var(--text-muted,#9aa3b2)]">
                  Uniswap V3 pool contract. Apply reads the two tokens and the fee.
                </span>
              </label>
              <Button
                type="button"
                size="sm"
                onClick={() => void applyV3Pool()}
                disabled={v3ApplyPending}
                data-testid={`${testIdPrefix}-apply-v3-pool`}
              >
                {v3ApplyPending ? 'Reading pool…' : 'Apply pool'}
              </Button>
              {v3PoolError ? (
                <p
                  className="text-sm text-[var(--danger,#E6386A)]"
                  role="alert"
                  data-testid={`${testIdPrefix}-v3-pool-error`}
                >
                  {v3PoolError}
                </p>
              ) : null}
            </div>
          ) : null}
          <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
            {version === 'v4' && v4Entry === 'poolkey' ? (
              <>
                <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
                  currency0
                  <input
                    className={`${inputClass} font-mono`}
                    value={tokenA}
                    onChange={(e) => setTokenA((e.target.value as `0x${string}`) || '')}
                    data-testid={`${testIdPrefix}-currency0`}
                    spellCheck={false}
                    autoComplete="off"
                    placeholder={ZERO_ADDRESS}
                  />
                </label>
                <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
                  currency1
                  <input
                    className={`${inputClass} font-mono`}
                    value={tokenB}
                    onChange={(e) => setTokenB((e.target.value as `0x${string}`) || '')}
                    data-testid={`${testIdPrefix}-currency1`}
                    spellCheck={false}
                    autoComplete="off"
                  />
                </label>
              </>
            ) : (
              <>
                <TokenSelect
                  label="Token A"
                  value={tokenA}
                  tokens={tokens}
                  exclude={tokenB}
                  testId={`${testIdPrefix}-token-a`}
                  onChange={setTokenA}
                  allowNative={version === 'v4'}
                  chainId={selectedChainId}
                />
                <TokenSelect
                  label="Token B"
                  value={tokenB}
                  tokens={tokens}
                  exclude={tokenA}
                  testId={`${testIdPrefix}-token-b`}
                  onChange={setTokenB}
                  allowNative={version === 'v4'}
                  chainId={selectedChainId}
                />
              </>
            )}
            <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
              Pool type
              <select
                className={inputClass}
                value={version}
                onChange={(e) => {
                  const next = e.target.value as PoolVersion
                  setVersion(next)
                  setTickSpacing(tickSpacingForV3Fee(fee))
                  if (next !== 'v4') setV4Entry('tokens')
                  if (next !== 'v3') setV3Entry('tokens')
                }}
                data-testid={`${testIdPrefix}-version`}
              >
                <option value="v4">Uniswap V4</option>
                <option value="v3">Uniswap V3</option>
              </select>
            </label>
            <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
              Fee
              <select
                className={inputClass}
                value={
                  customFee || !feeTiers.some((t) => t.fee === fee) ? 'custom' : String(fee)
                }
                onChange={(e) => {
                  if (e.target.value === 'custom') {
                    setCustomFee(true)
                    return
                  }
                  const next = Number(e.target.value)
                  setCustomFee(false)
                  setFee(next)
                  setTickSpacing(tickSpacingForV3Fee(next))
                }}
                data-testid={`${testIdPrefix}-fee`}
              >
                {feeTiers.map((t) => (
                  <option key={t.fee} value={t.fee}>
                    {t.label} ({t.fee})
                  </option>
                ))}
                <option value="custom">Custom</option>
              </select>
            </label>
            {customFee || !feeTiers.some((t) => t.fee === fee) ? (
              <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
                Custom fee
                <input
                  className={`${inputClass} font-mono`}
                  value={String(fee)}
                  onChange={(e) => {
                    const n = Number(e.target.value)
                    if (!Number.isFinite(n)) return
                    setFee(Math.max(0, Math.min(0xff_ffff, Math.floor(n))))
                  }}
                  inputMode="numeric"
                  data-testid={`${testIdPrefix}-fee-custom`}
                />
                <span className="mt-1 block text-xs text-[var(--text-muted,#9aa3b2)]">
                  {version === 'v4'
                    ? 'Uniswap V4 fee in millionths. 0 is a zero-fee pool. 3000 is 0.3%.'
                    : 'Uniswap V3 fee in millionths. 3000 is 0.3%.'}
                </span>
              </label>
            ) : null}
            {version === 'v4' ? (
              <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
                Tick spacing
                <input
                  className={`${inputClass} font-mono`}
                  value={String(tickSpacing)}
                  onChange={(e) => setTickSpacing(Number(e.target.value) || 60)}
                  inputMode="numeric"
                  data-testid={`${testIdPrefix}-tick-spacing`}
                />
              </label>
            ) : null}
            {version === 'v4' ? (
              <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
                Hooks
                <input
                  className={`${inputClass} font-mono`}
                  value={hooks}
                  onChange={(e) => setHooks(e.target.value)}
                  placeholder={ZERO_ADDRESS}
                  data-testid={`${testIdPrefix}-hooks`}
                />
                <span className="mt-1 block text-xs text-[var(--text-muted,#9aa3b2)]">
                  Zero address is a normal Uniswap V4 pool with no hook.
                </span>
              </label>
            ) : null}
            <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
              Initial price (token1 per token0)
              <input
                className={`${inputClass} font-mono`}
                value={initPrice}
                onChange={(e) => setInitPrice(e.target.value)}
                inputMode="decimal"
              />
              <span className="mt-1 block text-xs text-[var(--text-muted,#9aa3b2)]">
                Used when the pool does not exist yet. 1 is 1:1.
              </span>
            </label>
          </div>

          <p className="landing-section-label mt-6">SE vault</p>
          <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
            <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
              Width multiplier
              <input
                className={`${inputClass} font-mono`}
                value={width}
                onChange={(e) => setWidth(e.target.value)}
                inputMode="numeric"
              />
              <span className="mt-1 block text-xs text-[var(--text-muted,#9aa3b2)]">
                How many tick spacings wide the vault position is. 1 is the default.
              </span>
            </label>
          </div>

          <div className="mt-4 space-y-1 text-sm text-[var(--text-muted,#9aa3b2)]">
            {!v3Ready ? <p>No Uniswap V3 factory on this network.</p> : null}
            {!v4Ready ? <p>No Uniswap V4 pool manager on this network.</p> : null}
            {!pkgReady ? <p>No {version === 'v4' ? 'V4' : 'V3'} SE package on this network.</p> : null}
            {sorted && networkReady ? (
              <p data-testid={`${testIdPrefix}-status`}>
                Pool: {poolStatusCopy(readyState)}. SE vault:{' '}
                {candidateVaults.length === 0
                  ? 'not found'
                  : candidateVaults.length === 1
                    ? shortAddr(candidateVaults[0]!)
                    : `${candidateVaults.length} for these tokens`}
                .
              </p>
            ) : null}
          </div>
          {v4PoolKeyWarning ? (
            <p
              className="mt-3 text-sm text-[var(--danger,#E6386A)]"
              role="alert"
              data-testid={`${testIdPrefix}-pool-key-error`}
            >
              {v4PoolKeyWarning}
            </p>
          ) : null}

          {showPickExisting ? (
            <label className="mt-4 block text-sm text-[var(--text-primary,#EDEDED)]">
              SE vault for these tokens
              <select
                className={inputClass}
                value={selectedVault}
                onChange={(e) => onSelectVault((e.target.value as `0x${string}`) || '')}
                data-testid={`${testIdPrefix}-existing`}
              >
                <option value="">Select an SE vault</option>
                {candidateVaults.map((addr) => (
                  <option key={addr} value={addr}>
                    {shortAddr(addr)}
                  </option>
                ))}
              </select>
              <button
                type="button"
                className="mt-2 text-xs text-[var(--accent,#4FD44B)] underline-offset-2 hover:underline"
                onClick={() => setDeployAnother(true)}
              >
                Deploy another SE vault for this pool
              </button>
            </label>
          ) : null}

          <div className="mt-4 flex flex-wrap gap-3">
            {!poolExists ? (
              <ActionCta
                gate={poolGate}
                pendingLeg={pending === 'pool' ? 'execute' : null}
                onConnect={connectWallet}
                onExecute={() => void runTx('pool')}
                data-testid={`${testIdPrefix}-create-pool`}
              />
            ) : null}
            {showDeploy ? (
              <ActionCta
                gate={vaultGate}
                pendingLeg={pending === 'vault' ? 'execute' : null}
                onConnect={connectWallet}
                onExecute={() => void runTx('vault')}
                data-testid={`${testIdPrefix}-deploy-vault`}
              />
            ) : null}
          </div>
          {status ? <p className="mt-3 text-sm text-[var(--text-primary,#EDEDED)]">{status}</p> : null}
        </Card>
      )}

      {selectedVault ? (
        <div className="space-y-3">
          <p className="text-xs font-mono text-[var(--text-muted,#9aa3b2)]">
            Vault {shortAddr(selectedVault)}
          </p>
          {showWeight && onWeight ? (
            <label className="flex items-center gap-2 text-sm text-[var(--text-primary,#EDEDED)]">
              Weight %
              <input
                className="w-20 rounded-md border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-2 py-1 font-mono text-sm"
                value={weight ?? ''}
                onChange={(e) => onWeight(e.target.value)}
                inputMode="decimal"
              />
            </label>
          ) : null}
          <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
            Pair token
            <select
              className={inputClass}
              value={effectivePair}
              onChange={(e) => pickPair((e.target.value as `0x${string}`) || '')}
              data-testid={persistPair ? 'create-pair-token' : `${testIdPrefix}-pair`}
            >
              <option value="">Select a pair token</option>
              {pairOptions.map((t) => (
                <option key={t.address} value={t.address}>
                  {t.symbol} · {t.name}
                </option>
              ))}
            </select>
          </label>
          <p className="text-xs text-[var(--text-muted,#9aa3b2)]">
            Options are the tokens in this SE vault. Mint and bond settle against the pair token.
          </p>
          {pairOptions.length === 0 ? (
            <p className="text-xs text-[var(--text-muted,#9aa3b2)]">Reading vault tokens…</p>
          ) : null}
        </div>
      ) : null}
    </div>
  )
}

function TokenSelect({
  label,
  value,
  tokens,
  exclude,
  onChange,
  testId,
  allowNative = false,
  chainId = 0,
}: {
  label: string
  value: string
  tokens: TokenListEntry[]
  exclude?: string
  onChange: (addr: `0x${string}` | '') => void
  testId: string
  allowNative?: boolean
  chainId?: number
}) {
  const extras: TokenListEntry[] = []
  if (allowNative && !tokens.some((t) => same(t.address, ZERO_ADDRESS))) {
    extras.push({
      chainId,
      address: ZERO_ADDRESS,
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18,
    })
  }
  if (value && ![...extras, ...tokens].some((t) => same(t.address, value))) {
    extras.push({
      chainId,
      address: value as Address,
      name: same(value, ZERO_ADDRESS) ? 'Ether' : 'Token',
      symbol: same(value, ZERO_ADDRESS) ? 'ETH' : shortAddr(value),
      decimals: 18,
    })
  }
  const merged = [...extras, ...tokens]
  const options = (exclude ? merged.filter((t) => !same(t.address, exclude)) : merged).filter(
    (t, i, list) => list.findIndex((x) => same(x.address, t.address)) === i,
  )
  const selected = options.find((t) => same(t.address, value))?.address ?? value
  return (
    <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
      {label}
      <select
        className={inputClass}
        value={selected}
        onChange={(e) => onChange((e.target.value as `0x${string}`) || '')}
        data-testid={testId}
      >
        <option value="">Select a token</option>
        {options.map((t) => (
          <option key={t.address} value={t.address}>
            {t.symbol} · {t.name}
          </option>
        ))}
      </select>
    </label>
  )
}

function vaultFromReceipt(
  logs: { data: `0x${string}`; topics: readonly `0x${string}`[] }[] | undefined,
  pkg: Address,
): Address | undefined {
  if (!logs) return undefined
  for (const log of logs) {
    try {
      const decoded = decodeEventLog({
        abi: [NEW_VAULT_EVENT],
        data: log.data,
        topics: log.topics as [`0x${string}`, ...`0x${string}`[]],
      })
      if (decoded.eventName !== 'NewVault') continue
      const args = decoded.args as { vault?: Address; package?: Address }
      if (args.package && args.package.toLowerCase() === pkg.toLowerCase() && args.vault) {
        return args.vault
      }
      if (args.vault) return args.vault
    } catch {
      /* next */
    }
  }
  return undefined
}
