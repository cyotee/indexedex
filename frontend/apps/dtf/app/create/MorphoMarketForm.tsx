'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import { decodeEventLog, type Address } from 'viem'
import {
  useAccount,
  useConnect,
  useReadContract,
  useSwitchChain,
  useWriteContract,
} from 'wagmi'

import { CHAIN_ID_ANVIL, CHAIN_ID_LOCALHOST } from '@indexedex/protocol/addressArtifacts'
import type { TokenListEntry } from '@indexedex/protocol/tokenlists'
import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'

import { ActionCta } from '../components/ui/ActionCta'
import { Card } from '../components/ui/Card'
import { resolveWalletGate } from '../lib/tx/actionState'
import { parseContractError } from '../lib/tx/parseContractError'
import {
  MORPHO_ABI,
  MORPHO_SE_INFO_ABI,
  MORPHO_SE_PKG_ABI,
  NEW_VAULT_EVENT,
  VAULT_REGISTRY_SE_ABI,
} from './lib/seAbi'
import { resolveSePlatform } from './lib/sePlatform'
import {
  isMorphoCreateWalletRevert,
  lastUpdateFromMarket,
  marketStatusCopy,
  morphoMarketExists,
  morphoMarketId,
  MORPHO_LLTV_80,
  MORPHO_LLTV_OPTIONS,
  type MorphoMarketParams,
} from './lib/seMorpho'
import { uniqueAddresses } from './lib/sePoolRead'
import { requireContractCode, resolveWalletProvider, waitForCreateReceipt } from './lib/seTx'
import { useCreateChainClients } from './lib/useCreateChainClients'

const inputClass =
  'mt-1 w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm text-[var(--text-primary,#EDEDED)] placeholder:text-[var(--text-muted,#9aa3b2)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--accent,#4FD44B)]'

function shortAddr(addr: string): string {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`
}

function same(a: string, b: string): boolean {
  return a.toLowerCase() === b.toLowerCase()
}

export function MorphoMarketForm({
  tokens,
  selectedVault,
  onSelectVault,
  onSelectPair,
  persistPair,
  testIdPrefix,
}: {
  tokens: TokenListEntry[]
  selectedVault: `0x${string}` | ''
  onSelectVault: (vault: `0x${string}` | '') => void
  onSelectPair: (token: `0x${string}` | '') => void
  persistPair?: boolean
  testIdPrefix: string
}) {
  const { selectedChainId } = useSelectedNetwork()
  const { environment } = useDeploymentEnvironment()
  const { connect, connectors } = useConnect()
  const { switchChainAsync } = useSwitchChain()
  const { writeContractAsync } = useWriteContract()
  const { address, isConnected, chainId: walletChainId, connector } = useAccount()
  const { readClient } = useCreateChainClients(selectedChainId)
  const platform = useMemo(
    () => resolveSePlatform(selectedChainId, environment),
    [selectedChainId, environment],
  )

  const [loanToken, setLoanToken] = useState<`0x${string}` | ''>('')
  const [collateralToken, setCollateralToken] = useState<`0x${string}` | ''>('')
  const [lltv, setLltv] = useState<bigint>(MORPHO_LLTV_80)
  const [status, setStatus] = useState<string | null>(null)
  const [pending, setPending] = useState<'market' | 'vault' | null>(null)
  const [deployAnother, setDeployAnother] = useState(false)
  const [confirmedMarketId, setConfirmedMarketId] = useState('')
  const [discoverTick, setDiscoverTick] = useState(0)
  const [httpVaults, setHttpVaults] = useState<Address[]>([])

  const morpho = platform.morpho
  const irm = platform.morphoIrm
  const oracle = platform.morphoOracle
  const pkg = platform.morphoBlueSePkg

  const params = useMemo((): MorphoMarketParams | null => {
    if (!loanToken || !collateralToken || !oracle || !irm) return null
    if (same(loanToken, collateralToken)) return null
    return {
      loanToken,
      collateralToken,
      oracle,
      irm,
      lltv,
    }
  }, [loanToken, collateralToken, oracle, irm, lltv])

  const marketId = params ? morphoMarketId(params) : undefined
  const prevMarketId = useRef(marketId)

  const { data: marketRaw, refetch: refetchMarket, isFetched: marketFetched } = useReadContract({
    address: morpho ?? undefined,
    abi: MORPHO_ABI,
    functionName: 'market',
    args: marketId ? [marketId] : undefined,
    chainId: selectedChainId,
    query: { enabled: !!morpho && !!marketId, staleTime: 0 },
  })
  const { data: irmEnabled } = useReadContract({
    address: morpho ?? undefined,
    abi: MORPHO_ABI,
    functionName: 'isIrmEnabled',
    args: irm ? [irm] : undefined,
    chainId: selectedChainId,
    query: { enabled: !!morpho && !!irm },
  })
  const { data: lltvEnabled } = useReadContract({
    address: morpho ?? undefined,
    abi: MORPHO_ABI,
    functionName: 'isLltvEnabled',
    args: [lltv],
    chainId: selectedChainId,
    query: { enabled: !!morpho },
  })

  const lastUpdate = lastUpdateFromMarket(marketRaw)
  const justCreated = confirmedMarketId !== '' && confirmedMarketId === marketId
  const marketExists = morphoMarketExists(lastUpdate) || justCreated
  const marketLookupDone = !params || !morpho || marketFetched || justCreated

  useEffect(() => {
    if (!marketId || !pkg || !loanToken || !platform.registry || !readClient || !marketExists) {
      setHttpVaults([])
      return
    }
    let cancelled = false
    const run = async () => {
      try {
        const raw = (await readClient.readContract({
          address: platform.registry!,
          abi: VAULT_REGISTRY_SE_ABI,
          functionName: 'vaultsOfPkgOfTokens',
          args: [pkg, [loanToken as Address]],
        })) as Address[]
        const unique = uniqueAddresses(raw)
        const matched: Address[] = []
        for (const vault of unique) {
          try {
            const mp = (await readClient.readContract({
              address: vault,
              abi: MORPHO_SE_INFO_ABI,
              functionName: 'marketParams',
            })) as readonly [Address, Address, Address, Address, bigint]
            if (
              params &&
              same(mp[0], params.loanToken) &&
              same(mp[1], params.collateralToken) &&
              same(mp[2], params.oracle) &&
              same(mp[3], params.irm) &&
              mp[4] === params.lltv
            ) {
              matched.push(vault)
            }
          } catch {
            /* skip */
          }
        }
        if (!cancelled) setHttpVaults(matched.length > 0 ? matched : unique)
      } catch {
        if (!cancelled) setHttpVaults([])
      }
    }
    void run()
    return () => {
      cancelled = true
    }
  }, [
    marketId,
    pkg,
    loanToken,
    platform.registry,
    readClient,
    marketExists,
    params,
    discoverTick,
  ])

  useEffect(() => {
    if (prevMarketId.current === marketId) return
    prevMarketId.current = marketId
    setDeployAnother(false)
    setConfirmedMarketId('')
    setHttpVaults([])
    if (selectedVault) onSelectVault('')
  }, [marketId, selectedVault, onSelectVault])

  useEffect(() => {
    if (selectedVault) return
    if (confirmedMarketId === marketId) return
    if (httpVaults.length === 1) onSelectVault(httpVaults[0]!)
  }, [selectedVault, httpVaults, onSelectVault, confirmedMarketId, marketId])

  const lastPushedPair = useRef('')
  useEffect(() => {
    if (!persistPair || !loanToken) return
    if (lastPushedPair.current.toLowerCase() === loanToken.toLowerCase()) return
    lastPushedPair.current = loanToken
    onSelectPair(loanToken)
  }, [persistPair, loanToken, onSelectPair])

  const localWallet = walletChainId === CHAIN_ID_ANVIL || walletChainId === CHAIN_ID_LOCALHOST
  const isWrongNetwork = Boolean(
    isConnected &&
      typeof walletChainId === 'number' &&
      walletChainId !== selectedChainId &&
      !localWallet,
  )

  const canAct = !!params
  const morphoReady = !!morpho
  const pkgReady = !!pkg
  const irmOk = irmEnabled === true
  const lltvOk = lltvEnabled === true

  const marketGate = resolveWalletGate({
    isConnected,
    isWrongNetwork,
    amountValid: canAct && morphoReady && marketLookupDone && irmOk && lltvOk,
    hasPreview: canAct && morphoReady && marketLookupDone,
    needsTokenApproval: false,
    needsPermit2Approval: false,
    executeLabel: marketLookupDone ? 'Create market' : 'Checking market',
  })
  const vaultGate = resolveWalletGate({
    isConnected,
    isWrongNetwork,
    amountValid: canAct && pkgReady && marketExists,
    hasPreview: canAct && pkgReady && marketExists,
    needsTokenApproval: false,
    needsPermit2Approval: false,
    executeLabel: 'Deploy strategy vault',
  })

  const showDeploy =
    marketExists && (httpVaults.length === 0 || deployAnother)
  const showPickExisting = marketExists && httpVaults.length > 0 && !deployAnother

  const connectWallet = () => {
    const next =
      connectors.find((c) => c.id === 'metaMask' || c.id === 'metaMaskSDK') ??
      connectors.find((c) => c.id === 'injected') ??
      connectors[0]
    if (next) connect({ connector: next })
  }

  const writeOnWallet = async (writeParams: Parameters<typeof writeContractAsync>[0]) => {
    if (
      typeof walletChainId === 'number' &&
      walletChainId !== selectedChainId &&
      !localWallet
    ) {
      await switchChainAsync({ chainId: selectedChainId })
    }
    const { chainId: _c, chain: _ch, ...rest } = writeParams as typeof writeParams & {
      chainId?: number
      chain?: unknown
    }
    return writeContractAsync(rest)
  }

  const waitMined = async (hash: `0x${string}`) => {
    const walletProvider = await resolveWalletProvider(
      connector?.getProvider ? () => connector.getProvider() : undefined,
    )
    return waitForCreateReceipt({
      hash,
      readClient,
      walletProvider,
      timeoutMs: 180_000,
    })
  }

  const runTx = async (kind: 'market' | 'vault') => {
    setStatus(null)
    if (!params) {
      setStatus('Pick a lending token and a different collateral token.')
      return
    }
    if (!readClient) {
      setStatus('No RPC client.')
      return
    }
    const walletProvider = await resolveWalletProvider(
      connector?.getProvider ? () => connector.getProvider() : undefined,
    )
    if (!walletProvider) {
      setStatus('Connect a wallet.')
      return
    }
    setPending(kind)
    let submittedHash: `0x${string}` | undefined
    try {
      if (kind === 'market') {
        if (!morpho) throw new Error('No Morpho on this network.')
        await requireContractCode({
          walletProvider,
          address: morpho,
          label: 'Morpho Blue',
        })
        if (!marketExists) {
          try {
            submittedHash = await writeOnWallet({
              address: morpho,
              abi: MORPHO_ABI,
              functionName: 'createMarket',
              args: [params],
            })
            setStatus('Waiting for the market transaction…')
            await waitMined(submittedHash)
          } catch (err) {
            if (!isMorphoCreateWalletRevert(err)) throw err
          }
        }
        setConfirmedMarketId(marketId ?? '')
        setStatus('Market is ready. Deploy the strategy vault next.')
      } else {
        if (!pkg) throw new Error('No Morpho strategy vault factory on this network.')
        if (!morpho) throw new Error('No Morpho on this network.')
        await requireContractCode({
          walletProvider,
          address: pkg,
          label: 'The strategy vault factory',
        })
        submittedHash = await writeOnWallet({
          address: pkg,
          abi: MORPHO_SE_PKG_ABI,
          functionName: 'deployVault',
          args: [{ morpho, marketParams: params }],
        })
        setStatus('Waiting for the vault transaction…')
        const receipt = await waitMined(submittedHash)
        const vault = vaultFromReceipt(receipt.logs, pkg)
        if (vault) {
          onSelectVault(vault)
          setDeployAnother(false)
        }
        setStatus('Strategy vault deployed.')
      }
      setDiscoverTick((n) => n + 1)
      await refetchMarket()
    } catch (err) {
      const parsed = parseContractError(err)
      if (kind === 'market' && isMorphoCreateWalletRevert(err)) {
        setConfirmedMarketId(marketId ?? '')
        setStatus('This market already exists. Deploy the strategy vault next.')
        setDiscoverTick((n) => n + 1)
        await refetchMarket()
      } else if (kind === 'market' && submittedHash) {
        setConfirmedMarketId(marketId ?? '')
        setStatus('Wallet confirmed the market. Deploy the strategy vault next.')
        setDiscoverTick((n) => n + 1)
      } else {
        setStatus(parsed)
      }
    } finally {
      setPending(null)
    }
  }

  return (
    <Card>
      <p className="landing-section-label">Morpho market</p>
      <p className="mt-2 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
        A Morpho market is lending token, collateral token, oracle, rate model, and LLTV. If that
        market is already on Morpho, this page uses it. It does not create a second one.
      </p>
      <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
        <TokenSelect
          label="Lending token"
          value={loanToken}
          tokens={tokens}
          exclude={collateralToken}
          testId={`${testIdPrefix}-loan`}
          onChange={setLoanToken}
        />
        <TokenSelect
          label="Collateral token"
          value={collateralToken}
          tokens={tokens}
          exclude={loanToken}
          testId={`${testIdPrefix}-collateral`}
          onChange={setCollateralToken}
        />
        <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
          LLTV
          <select
            className={inputClass}
            value={String(lltv)}
            onChange={(e) => setLltv(BigInt(e.target.value))}
            data-testid={`${testIdPrefix}-lltv`}
          >
            {MORPHO_LLTV_OPTIONS.map((opt) => (
              <option key={opt.label} value={String(opt.wad)}>
                {opt.label}
              </option>
            ))}
          </select>
          <span className="mt-1 block text-xs text-[var(--text-muted,#9aa3b2)]">
            Liquidation loan-to-value. Only values Morpho has enabled can be used.
          </span>
        </label>
      </div>

      <div className="mt-4 space-y-1 text-sm text-[var(--text-muted,#9aa3b2)]">
        {!morpho ? <p>No Morpho on this network.</p> : null}
        {!irm ? <p>No Morpho rate model on this network.</p> : null}
        {!oracle ? <p>No Morpho price oracle on this network.</p> : null}
        {!pkgReady ? <p>No Morpho strategy vault factory on this network.</p> : null}
        {irm && irmEnabled === false ? (
          <p>This rate model is not enabled on Morpho. The market cannot be created.</p>
        ) : null}
        {lltvEnabled === false ? (
          <p>This LLTV is not enabled on Morpho. The market cannot be created.</p>
        ) : null}
        {irm ? (
          <p className="font-mono text-xs">
            Rate model {shortAddr(irm)}
            {oracle ? ` · Oracle ${shortAddr(oracle)}` : ''}
          </p>
        ) : null}
        {params && morphoReady ? (
          <p data-testid={`${testIdPrefix}-status`}>
            Market: {marketLookupDone ? marketStatusCopy(marketExists) : 'checking…'}. Strategy
            vault:{' '}
            {httpVaults.length === 0
              ? 'not found'
              : httpVaults.length === 1
                ? shortAddr(httpVaults[0]!)
                : `${httpVaults.length} for this lending token`}
            .
          </p>
        ) : null}
      </div>

      {showPickExisting ? (
        <label className="mt-4 block text-sm text-[var(--text-primary,#EDEDED)]">
          Strategy vault for this market
          <select
            className={inputClass}
            value={selectedVault}
            onChange={(e) => onSelectVault((e.target.value as `0x${string}`) || '')}
            data-testid={`${testIdPrefix}-existing`}
          >
            <option value="">Select a strategy vault</option>
            {httpVaults.map((addr) => (
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
            Deploy another strategy vault for this market
          </button>
        </label>
      ) : null}

      <div className="mt-4 flex flex-wrap gap-3">
        {params && !marketLookupDone ? (
          <p className="text-sm text-[var(--text-muted,#9aa3b2)]">Checking if this market exists…</p>
        ) : null}
        {!marketExists && marketLookupDone ? (
          <ActionCta
            gate={marketGate}
            pendingLeg={pending === 'market' ? 'execute' : null}
            onConnect={connectWallet}
            onSwitchNetwork={() => void switchChainAsync({ chainId: selectedChainId })}
            onExecute={() => void runTx('market')}
            data-testid={`${testIdPrefix}-create-market`}
          />
        ) : null}
        {showDeploy ? (
          <ActionCta
            gate={vaultGate}
            pendingLeg={pending === 'vault' ? 'execute' : null}
            onConnect={connectWallet}
            onSwitchNetwork={() => void switchChainAsync({ chainId: selectedChainId })}
            onExecute={() => void runTx('vault')}
            data-testid={`${testIdPrefix}-deploy-vault`}
          />
        ) : null}
      </div>
      {status ? <p className="mt-3 text-sm text-[var(--text-primary,#EDEDED)]">{status}</p> : null}
    </Card>
  )
}

function TokenSelect({
  label,
  value,
  tokens,
  exclude,
  onChange,
  testId,
}: {
  label: string
  value: string
  tokens: TokenListEntry[]
  exclude?: string
  onChange: (addr: `0x${string}` | '') => void
  testId: string
}) {
  const options = exclude ? tokens.filter((t) => !same(t.address, exclude)) : tokens
  return (
    <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
      {label}
      <select
        className={inputClass}
        value={value}
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
