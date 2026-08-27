'use client'

import { useMemo, useState } from 'react'
import {
  useAccount,
  usePublicClient,
  useReadContract,
  useReadContracts,
  useSwitchChain,
  useWriteContract,
} from 'wagmi'
import { zeroAddress } from 'viem'

import { CHAIN_ID_ANVIL, CHAIN_ID_LOCALHOST } from '@indexedex/protocol/addressArtifacts'
import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'

import { AddressLink } from '../components/ui/AddressLink'
import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { PageHeader } from '../components/ui/PageHeader'
import { resolveSePlatform } from '../create/lib/sePlatform'
import { addressesMatch, walletCanSignOnChain } from '../insights/lib/claimRewardsGate'
import { parseContractError } from '../lib/tx/parseContractError'
import { FEE_ORACLE_ABI, asBondTerms, type BondTerms } from './lib/feeOracleAbi'
import {
  formatLockDuration,
  formatWadPercent,
  parseDaysToSeconds,
  parseEthAddress,
  parsePercentToWad,
  parseTypeId,
  uniqueTypeIds,
} from './lib/formatFeeOracle'

const inputClass =
  'mt-1 w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm text-[var(--text-primary,#EDEDED)]'

const ZERO = zeroAddress

function resultOf<T>(entry: { status: string; result?: unknown } | undefined): T | undefined {
  if (entry?.status !== 'success') return undefined
  return entry.result as T
}

function Row({ label, value, testId }: { label: string; value: string; testId?: string }) {
  return (
    <div className="flex flex-col gap-0.5 py-2 sm:flex-row sm:items-baseline sm:justify-between sm:gap-4">
      <dt className="text-sm text-[var(--text-muted,#9aa3b2)]">{label}</dt>
      <dd className="font-mono text-sm text-[var(--text-primary,#EDEDED)]" data-testid={testId}>
        {value}
      </dd>
    </div>
  )
}

function BondRows({ terms, prefix }: { terms: BondTerms | null; prefix?: string }) {
  const p = prefix ? `${prefix} ` : ''
  return (
    <>
      <Row label={`${p}Min lock`} value={formatLockDuration(terms?.minLockDuration)} />
      <Row label={`${p}Max lock`} value={formatLockDuration(terms?.maxLockDuration)} />
      <Row label={`${p}Min bond bonus`} value={formatWadPercent(terms?.minBonusPercentage, { zeroMeansZero: true })} />
      <Row label={`${p}Max bond bonus`} value={formatWadPercent(terms?.maxBonusPercentage, { zeroMeansZero: true })} />
    </>
  )
}

function Field({
  label,
  value,
  onChange,
  placeholder,
  testId,
}: {
  label: string
  value: string
  onChange: (v: string) => void
  placeholder?: string
  testId?: string
}) {
  return (
    <label className="block text-xs text-[var(--text-muted,#9aa3b2)]">
      {label}
      <input
        className={inputClass}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        data-testid={testId}
      />
    </label>
  )
}

export default function ProtocolPageClient() {
  const { address, isConnected, chainId: walletChainId } = useAccount()
  const { environment } = useDeploymentEnvironment()
  const { selectedChainId } = useSelectedNetwork()
  const chainId = selectedChainId ?? CHAIN_ID_ANVIL
  const { switchChainAsync } = useSwitchChain()
  const { writeContractAsync, isPending } = useWriteContract()
  const publicClient = usePublicClient({ chainId })

  const platform = useMemo(() => resolveSePlatform(chainId, environment), [chainId, environment])
  const oracle = platform.feeOracle ?? undefined

  const [status, setStatus] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [pendingKey, setPendingKey] = useState<string | null>(null)

  const [usageFee, setUsageFee] = useState('')
  const [dexFee, setDexFee] = useState('')
  const [minLockDays, setMinLockDays] = useState('')
  const [maxLockDays, setMaxLockDays] = useState('')
  const [minBonus, setMinBonus] = useState('')
  const [maxBonus, setMaxBonus] = useState('')
  const [callerShare, setCallerShare] = useState('')
  const [feeToShare, setFeeToShare] = useState('')
  const [creatorShare, setCreatorShare] = useState('')
  const [liquidReserve, setLiquidReserve] = useState('')
  const [feeToInput, setFeeToInput] = useState('')

  const [typeIdInput, setTypeIdInput] = useState('')
  const [typeUsageFee, setTypeUsageFee] = useState('')
  const [typeDexFee, setTypeDexFee] = useState('')
  const [typeMinLock, setTypeMinLock] = useState('')
  const [typeMaxLock, setTypeMaxLock] = useState('')
  const [typeMinBonus, setTypeMinBonus] = useState('')
  const [typeMaxBonus, setTypeMaxBonus] = useState('')
  const [typeCallerShare, setTypeCallerShare] = useState('')
  const [typeFeeToShare, setTypeFeeToShare] = useState('')
  const [typeCreatorShare, setTypeCreatorShare] = useState('')
  const [typeLiquid, setTypeLiquid] = useState('')

  const [vaultInput, setVaultInput] = useState('')
  const [vaultLookup, setVaultLookup] = useState<`0x${string}` | null>(null)
  const [vaultUsageFee, setVaultUsageFee] = useState('')
  const [vaultDexFee, setVaultDexFee] = useState('')
  const [vaultMinLock, setVaultMinLock] = useState('')
  const [vaultMaxLock, setVaultMaxLock] = useState('')
  const [vaultMinBonus, setVaultMinBonus] = useState('')
  const [vaultMaxBonus, setVaultMaxBonus] = useState('')
  const [vaultCallerShare, setVaultCallerShare] = useState('')
  const [vaultFeeToShare, setVaultFeeToShare] = useState('')
  const [vaultCreatorShare, setVaultCreatorShare] = useState('')
  const [vaultLiquid, setVaultLiquid] = useState('')

  const localWallet = walletChainId === CHAIN_ID_ANVIL || walletChainId === CHAIN_ID_LOCALHOST
  const canSign = walletCanSignOnChain({
    isConnected,
    walletChainId,
    appChainId: chainId,
    localWallet,
  })

  const enabled = !!oracle
  const globals = useReadContracts({
    contracts: oracle
      ? [
          { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'owner', chainId },
          { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'pendingOwner', chainId },
          { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'feeTo', chainId },
          { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'defaultUsageFee', chainId },
          { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'defaultDexSwapFee', chainId },
          { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'defaultBondTerms', chainId },
          { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'defaultSeigniorageIncentivePercentage', chainId },
          { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'defaultSeigniorageFeeToSharePercentage', chainId },
          { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'defaultSeigniorageCreatorSharePercentage', chainId },
          { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'defaultLiquidReservePercentage', chainId },
          { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'usageFeeVaultTypeIds', chainId },
          { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'dexSwapFeeVaultTypeIds', chainId },
          { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'bondVaultTypesIds', chainId },
          { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'seigniorageVaultTypeIds', chainId },
        ]
      : [],
    query: { enabled },
  })

  const owner = resultOf<`0x${string}`>(globals.data?.[0])
  const pendingOwner = resultOf<`0x${string}`>(globals.data?.[1])
  const feeTo = resultOf<`0x${string}`>(globals.data?.[2])
  const defaultUsageFee = resultOf<bigint>(globals.data?.[3])
  const defaultDexSwapFee = resultOf<bigint>(globals.data?.[4])
  const defaultBondTerms = asBondTerms(resultOf(globals.data?.[5]))
  const defaultCallerShare = resultOf<bigint>(globals.data?.[6])
  const defaultFeeToShare = resultOf<bigint>(globals.data?.[7])
  const defaultCreatorShare = resultOf<bigint>(globals.data?.[8])
  const defaultLiquid = resultOf<bigint>(globals.data?.[9])
  const typeIds = uniqueTypeIds([
    resultOf<readonly `0x${string}`[]>(globals.data?.[10]),
    resultOf<readonly `0x${string}`[]>(globals.data?.[11]),
    resultOf<readonly `0x${string}`[]>(globals.data?.[12]),
    resultOf<readonly `0x${string}`[]>(globals.data?.[13]),
  ])

  const isOwner = addressesMatch(address, owner)
  const showOwnerForms = isConnected && isOwner

  const typeReads = useReadContracts({
    contracts:
      oracle && typeIds.length > 0
        ? typeIds.flatMap((id) => [
            { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'defaultUsageFeeOfTypeId' as const, args: [id] as const, chainId },
            { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'defaultDexSwapFeeOfTypeId' as const, args: [id] as const, chainId },
            { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'defaultBondTermsOfVaultTypeId' as const, args: [id] as const, chainId },
            { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'seigniorageIncentivePercentageOfTypeId' as const, args: [id] as const, chainId },
            { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'seigniorageFeeToSharePercentageOfTypeId' as const, args: [id] as const, chainId },
            { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'seigniorageCreatorSharePercentageOfTypeId' as const, args: [id] as const, chainId },
            { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'defaultLiquidReservePercentageOfTypeId' as const, args: [id] as const, chainId },
          ])
        : [],
    query: { enabled: !!oracle && typeIds.length > 0 },
  })

  const vaultReads = useReadContracts({
    contracts:
      oracle && vaultLookup
        ? [
            { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'usageFeeOfVault' as const, args: [vaultLookup] as const, chainId },
            { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'dexSwapFeeOfVault' as const, args: [vaultLookup] as const, chainId },
            { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'bondTermsOfVault' as const, args: [vaultLookup] as const, chainId },
            { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'seigniorageSplitOfVault' as const, args: [vaultLookup] as const, chainId },
            { address: oracle, abi: FEE_ORACLE_ABI, functionName: 'liquidReservePercentageOfVault' as const, args: [vaultLookup] as const, chainId },
          ]
        : [],
    query: { enabled: !!oracle && !!vaultLookup },
  })

  const { data: isOperator } = useReadContract({
    address: oracle,
    abi: FEE_ORACLE_ABI,
    functionName: 'isOperator',
    args: address ? [address] : undefined,
    chainId,
    query: { enabled: !!oracle && !!address },
  })

  const refetchAll = async () => {
    await Promise.all([globals.refetch(), typeReads.refetch(), vaultReads.refetch()])
  }

  const runWrite = async (key: string, fn: () => Promise<`0x${string}`>) => {
    setError(null)
    setStatus(null)
    setPendingKey(key)
    try {
      if (!canSign && !localWallet && walletChainId && walletChainId !== chainId) {
        await switchChainAsync({ chainId })
      }
      const hash = await fn()
      if (!publicClient) throw new Error('No RPC client.')
      const receipt = await publicClient.waitForTransactionReceipt({ hash })
      if (receipt.status === 'reverted') throw new Error('Transaction reverted')
      setStatus(`Saved. ${hash.slice(0, 10)}…`)
      await refetchAll()
    } catch (err) {
      setError(parseContractError(err))
    } finally {
      setPendingKey(null)
    }
  }

  const writeOracle = (key: string, functionName: string, args: readonly unknown[]) => {
    if (!oracle) return
    return runWrite(key, () =>
      writeContractAsync({
        address: oracle,
        abi: FEE_ORACLE_ABI,
        functionName: functionName as never,
        args: args as never,
      }),
    )
  }

  const busy = isPending || pendingKey != null

  const vaultSplit = resultOf<readonly [bigint, bigint, bigint]>(vaultReads.data?.[3])
  const vaultBond = asBondTerms(resultOf(vaultReads.data?.[2]))

  return (
    <div className="mx-auto max-w-4xl space-y-8 px-4 py-8 sm:px-6">
      <PageHeader
        title="Protocol fees"
        subtitle="Live Vault Fee Oracle settings. Percents are of the action. Unset (0) means the next default applies."
      />

      {!oracle ? (
        <Card>
          <p className="text-sm text-[var(--text-muted,#9aa3b2)]">
            No fee oracle address on this chain. Check the selected network and artifacts.
          </p>
        </Card>
      ) : (
        <>
          <Card data-testid="protocol-identity">
            <p className="text-xs uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]">Oracle</p>
            <dl className="mt-3 divide-y divide-[var(--border-subtle,rgba(255,255,255,0.08))]">
              <div className="flex flex-col gap-1 py-2 sm:flex-row sm:items-center sm:justify-between">
                <dt className="text-sm text-[var(--text-muted,#9aa3b2)]">Fee oracle</dt>
                <dd>
                  <AddressLink chainId={chainId} address={oracle} display="full" />
                </dd>
              </div>
              <div className="flex flex-col gap-1 py-2 sm:flex-row sm:items-center sm:justify-between">
                <dt className="text-sm text-[var(--text-muted,#9aa3b2)]">Owner</dt>
                <dd data-testid="protocol-owner">
                  {owner && owner !== ZERO ? (
                    <AddressLink chainId={chainId} address={owner} display="full" />
                  ) : (
                    <span className="font-mono text-sm text-[var(--text-muted,#9aa3b2)]">—</span>
                  )}
                </dd>
              </div>
              {pendingOwner && pendingOwner !== ZERO ? (
                <div className="flex flex-col gap-1 py-2 sm:flex-row sm:items-center sm:justify-between">
                  <dt className="text-sm text-[var(--text-muted,#9aa3b2)]">Pending owner</dt>
                  <dd>
                    <AddressLink chainId={chainId} address={pendingOwner} display="full" />
                  </dd>
                </div>
              ) : null}
              <div className="flex flex-col gap-1 py-2 sm:flex-row sm:items-center sm:justify-between">
                <dt className="text-sm text-[var(--text-muted,#9aa3b2)]">Fee collector</dt>
                <dd data-testid="protocol-fee-to">
                  {feeTo && feeTo !== ZERO ? (
                    <AddressLink chainId={chainId} address={feeTo} display="full" />
                  ) : (
                    <span className="font-mono text-sm text-[var(--text-muted,#9aa3b2)]">Unset</span>
                  )}
                </dd>
              </div>
            </dl>
            {isConnected && isOwner ? (
              <p className="mt-3 text-sm text-[var(--accent,#4FD44B)]" data-testid="protocol-owner-connected">
                Connected wallet is the owner. Change forms are open below.
              </p>
            ) : isConnected && isOperator ? (
              <p className="mt-3 text-sm text-[var(--text-muted,#9aa3b2)]">
                Connected wallet is an operator. Owner forms stay hidden; only the owner address above can use them here.
              </p>
            ) : null}
          </Card>

          <Card data-testid="protocol-globals">
            <h2 className="text-lg font-semibold text-[var(--text-primary,#EDEDED)]">Global defaults</h2>
            <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
              Bond pot (p) is used twice on mint: the quote treats deposited capital as if it were (1 + p), then the minted DETF is split user (1 − p) / pot p. A bond does not boost the join; it mints extra (1 − p) to the bonder and 2p to the pot. Natural expansion does not take p. Fee collector and creator weights split the pot; the rest goes to bond purchasers.
            </p>
            <dl className="mt-3 divide-y divide-[var(--border-subtle,rgba(255,255,255,0.08))]">
              <Row label="Vault usage fee" value={formatWadPercent(defaultUsageFee)} testId="protocol-usage-fee" />
              <Row label="DEX swap fee" value={formatWadPercent(defaultDexSwapFee)} testId="protocol-dex-fee" />
              <BondRows terms={defaultBondTerms} />
              <Row label="Bond pot (share of minted DETF)" value={formatWadPercent(defaultCallerShare)} />
              <Row label="Fee collector weight of the pot" value={formatWadPercent(defaultFeeToShare)} />
              <Row label="Creator weight of the pot" value={formatWadPercent(defaultCreatorShare)} />
              <Row label="Liquid reserve target" value={formatWadPercent(defaultLiquid)} />
            </dl>
          </Card>

          {showOwnerForms ? (
            <Card data-testid="protocol-owner-forms">
              <h2 className="text-lg font-semibold text-[var(--text-primary,#EDEDED)]">Change global defaults</h2>
              <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
                Percents as numbers (5 = 5%). Lock as whole days. Set 0 to clear a percent default.
              </p>
              <div className="mt-4 grid gap-4 sm:grid-cols-2">
                <Field label="Vault usage fee %" value={usageFee} onChange={setUsageFee} placeholder="0.1" />
                <div className="flex items-end">
                  <Button
                    size="sm"
                    disabled={busy || parsePercentToWad(usageFee) == null}
                    loading={pendingKey === 'usage'}
                    onClick={() => {
                      const wad = parsePercentToWad(usageFee)
                      if (wad == null) return
                      void writeOracle('usage', 'setDefaultUsageFee', [wad])
                    }}
                  >
                    Save usage fee
                  </Button>
                </div>
                <Field label="DEX swap fee %" value={dexFee} onChange={setDexFee} placeholder="5" />
                <div className="flex items-end">
                  <Button
                    size="sm"
                    disabled={busy || parsePercentToWad(dexFee) == null}
                    loading={pendingKey === 'dex'}
                    onClick={() => {
                      const wad = parsePercentToWad(dexFee)
                      if (wad == null) return
                      void writeOracle('dex', 'setDefaultDexSwapFee', [wad])
                    }}
                  >
                    Save DEX fee
                  </Button>
                </div>
                <Field label="Min lock (days)" value={minLockDays} onChange={setMinLockDays} placeholder="30" />
                <Field label="Max lock (days)" value={maxLockDays} onChange={setMaxLockDays} placeholder="180" />
                <Field label="Min bond bonus %" value={minBonus} onChange={setMinBonus} placeholder="0" />
                <Field label="Max bond bonus %" value={maxBonus} onChange={setMaxBonus} placeholder="5" />
                <div className="sm:col-span-2">
                  <Button
                    size="sm"
                    disabled={
                      busy
                      || parseDaysToSeconds(minLockDays) == null
                      || parseDaysToSeconds(maxLockDays) == null
                      || parsePercentToWad(minBonus) == null
                      || parsePercentToWad(maxBonus) == null
                    }
                    loading={pendingKey === 'bond'}
                    onClick={() => {
                      const minLock = parseDaysToSeconds(minLockDays)
                      const maxLock = parseDaysToSeconds(maxLockDays)
                      const minB = parsePercentToWad(minBonus)
                      const maxB = parsePercentToWad(maxBonus)
                      if (minLock == null || maxLock == null || minB == null || maxB == null) return
                      void writeOracle('bond', 'setDefaultBondTerms', [{
                        minLockDuration: minLock,
                        maxLockDuration: maxLock,
                        minBonusPercentage: minB,
                        maxBonusPercentage: maxB,
                      }])
                    }}
                  >
                    Save bond terms
                  </Button>
                </div>
                <Field label="Bond pot %" value={callerShare} onChange={setCallerShare} placeholder="5" />
                <div className="flex items-end">
                  <Button
                    size="sm"
                    disabled={busy || parsePercentToWad(callerShare) == null}
                    loading={pendingKey === 'caller'}
                    onClick={() => {
                      const wad = parsePercentToWad(callerShare)
                      if (wad == null) return
                      void writeOracle('caller', 'setDefaultSeigniorageIncentivePercentage', [wad])
                    }}
                  >
                    Save bond pot
                  </Button>
                </div>
                <Field label="Fee collector weight of the pot %" value={feeToShare} onChange={setFeeToShare} placeholder="12" />
                <Field label="Creator weight of the pot %" value={creatorShare} onChange={setCreatorShare} placeholder="28" />
                <div className="sm:col-span-2">
                  <Button
                    size="sm"
                    disabled={busy || parsePercentToWad(feeToShare) == null || parsePercentToWad(creatorShare) == null}
                    loading={pendingKey === 'pot'}
                    onClick={() => {
                      const f = parsePercentToWad(feeToShare)
                      const c = parsePercentToWad(creatorShare)
                      if (f == null || c == null) return
                      void writeOracle('pot', 'setDefaultSeignioragePotShares', [f, c])
                    }}
                  >
                    Save pot weights
                  </Button>
                </div>
                <Field label="Liquid reserve target %" value={liquidReserve} onChange={setLiquidReserve} placeholder="5" />
                <div className="flex items-end">
                  <Button
                    size="sm"
                    disabled={busy || parsePercentToWad(liquidReserve) == null}
                    loading={pendingKey === 'liquid'}
                    onClick={() => {
                      const wad = parsePercentToWad(liquidReserve)
                      if (wad == null) return
                      void writeOracle('liquid', 'setDefaultLiquidReservePercentage', [wad])
                    }}
                  >
                    Save liquid reserve
                  </Button>
                </div>
                <Field label="Fee collector address" value={feeToInput} onChange={setFeeToInput} placeholder="0x…" />
                <div className="flex items-end">
                  <Button
                    size="sm"
                    disabled={busy || parseEthAddress(feeToInput) == null}
                    loading={pendingKey === 'feeto'}
                    onClick={() => {
                      const next = parseEthAddress(feeToInput)
                      if (!next) return
                      void writeOracle('feeto', 'setFeeTo', [next])
                    }}
                  >
                    Save fee collector
                  </Button>
                </div>
              </div>
            </Card>
          ) : null}

          <Card data-testid="protocol-types">
            <h2 className="text-lg font-semibold text-[var(--text-primary,#EDEDED)]">Type defaults</h2>
            <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
              Per vault-type id. Unset falls back to the global default.
            </p>
            {typeIds.length === 0 ? (
              <p className="mt-3 text-sm text-[var(--text-muted,#9aa3b2)]">No type ids registered yet.</p>
            ) : (
              <div className="mt-4 space-y-4">
                {typeIds.map((id, i) => {
                  const base = i * 7
                  const terms = asBondTerms(resultOf(typeReads.data?.[base + 2]))
                  return (
                    <div
                      key={id}
                      className="rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] p-3"
                    >
                      <p className="font-mono text-xs text-[var(--accent,#4FD44B)]">{id}</p>
                      <dl className="mt-2 divide-y divide-[var(--border-subtle,rgba(255,255,255,0.08))]">
                        <Row label="Vault usage fee" value={formatWadPercent(resultOf<bigint>(typeReads.data?.[base]))} />
                        <Row label="DEX swap fee" value={formatWadPercent(resultOf<bigint>(typeReads.data?.[base + 1]))} />
                        <BondRows terms={terms} />
                        <Row label="Bond pot (share of minted DETF)" value={formatWadPercent(resultOf<bigint>(typeReads.data?.[base + 3]))} />
                        <Row label="Fee collector weight of the pot" value={formatWadPercent(resultOf<bigint>(typeReads.data?.[base + 4]))} />
                        <Row label="Creator weight of the pot" value={formatWadPercent(resultOf<bigint>(typeReads.data?.[base + 5]))} />
                        <Row label="Liquid reserve target" value={formatWadPercent(resultOf<bigint>(typeReads.data?.[base + 6]))} />
                      </dl>
                    </div>
                  )
                })}
              </div>
            )}
          </Card>

          {showOwnerForms ? (
            <Card>
              <h2 className="text-lg font-semibold text-[var(--text-primary,#EDEDED)]">Change a type default</h2>
              <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">Type id is 4 bytes, like 0x1234abcd. Empty fields are skipped.</p>
              <div className="mt-4 grid gap-4 sm:grid-cols-2">
                <div className="sm:col-span-2">
                  <Field label="Type id" value={typeIdInput} onChange={setTypeIdInput} placeholder="0x1234abcd" />
                </div>
                <Field label="Vault usage fee %" value={typeUsageFee} onChange={setTypeUsageFee} />
                <div className="flex items-end">
                  <Button
                    size="sm"
                    disabled={busy || parseTypeId(typeIdInput) == null || parsePercentToWad(typeUsageFee) == null}
                    loading={pendingKey === 't-usage'}
                    onClick={() => {
                      const id = parseTypeId(typeIdInput)
                      const wad = parsePercentToWad(typeUsageFee)
                      if (!id || wad == null) return
                      void writeOracle('t-usage', 'setDefaultUsageFeeOfTypeId', [id, wad])
                    }}
                  >
                    Save type usage fee
                  </Button>
                </div>
                <Field label="DEX swap fee %" value={typeDexFee} onChange={setTypeDexFee} />
                <div className="flex items-end">
                  <Button
                    size="sm"
                    disabled={busy || parseTypeId(typeIdInput) == null || parsePercentToWad(typeDexFee) == null}
                    loading={pendingKey === 't-dex'}
                    onClick={() => {
                      const id = parseTypeId(typeIdInput)
                      const wad = parsePercentToWad(typeDexFee)
                      if (!id || wad == null) return
                      void writeOracle('t-dex', 'setDefaultDexSwapFeeOfTypeId', [id, wad])
                    }}
                  >
                    Save type DEX fee
                  </Button>
                </div>
                <Field label="Min lock (days)" value={typeMinLock} onChange={setTypeMinLock} />
                <Field label="Max lock (days)" value={typeMaxLock} onChange={setTypeMaxLock} />
                <Field label="Min bond bonus %" value={typeMinBonus} onChange={setTypeMinBonus} />
                <Field label="Max bond bonus %" value={typeMaxBonus} onChange={setTypeMaxBonus} />
                <div className="sm:col-span-2">
                  <Button
                    size="sm"
                    disabled={
                      busy
                      || parseTypeId(typeIdInput) == null
                      || parseDaysToSeconds(typeMinLock) == null
                      || parseDaysToSeconds(typeMaxLock) == null
                      || parsePercentToWad(typeMinBonus) == null
                      || parsePercentToWad(typeMaxBonus) == null
                    }
                    loading={pendingKey === 't-bond'}
                    onClick={() => {
                      const id = parseTypeId(typeIdInput)
                      const minLock = parseDaysToSeconds(typeMinLock)
                      const maxLock = parseDaysToSeconds(typeMaxLock)
                      const minB = parsePercentToWad(typeMinBonus)
                      const maxB = parsePercentToWad(typeMaxBonus)
                      if (!id || minLock == null || maxLock == null || minB == null || maxB == null) return
                      void writeOracle('t-bond', 'setDefaultBondTermsOfTypeId', [id, {
                        minLockDuration: minLock,
                        maxLockDuration: maxLock,
                        minBonusPercentage: minB,
                        maxBonusPercentage: maxB,
                      }])
                    }}
                  >
                    Save type bond terms
                  </Button>
                </div>
                <Field label="Bond pot %" value={typeCallerShare} onChange={setTypeCallerShare} />
                <div className="flex items-end">
                  <Button
                    size="sm"
                    disabled={busy || parseTypeId(typeIdInput) == null || parsePercentToWad(typeCallerShare) == null}
                    loading={pendingKey === 't-caller'}
                    onClick={() => {
                      const id = parseTypeId(typeIdInput)
                      const wad = parsePercentToWad(typeCallerShare)
                      if (!id || wad == null) return
                      void writeOracle('t-caller', 'setDefaultSeigniorageIncentivePercentageOfTypeId', [id, wad])
                    }}
                  >
                    Save type bond pot
                  </Button>
                </div>
                <Field label="Fee collector weight of the pot %" value={typeFeeToShare} onChange={setTypeFeeToShare} />
                <Field label="Creator weight of the pot %" value={typeCreatorShare} onChange={setTypeCreatorShare} />
                <div className="sm:col-span-2">
                  <Button
                    size="sm"
                    disabled={
                      busy
                      || parseTypeId(typeIdInput) == null
                      || parsePercentToWad(typeFeeToShare) == null
                      || parsePercentToWad(typeCreatorShare) == null
                    }
                    loading={pendingKey === 't-pot'}
                    onClick={() => {
                      const id = parseTypeId(typeIdInput)
                      const f = parsePercentToWad(typeFeeToShare)
                      const c = parsePercentToWad(typeCreatorShare)
                      if (!id || f == null || c == null) return
                      void writeOracle('t-pot', 'setDefaultSeignioragePotSharesOfTypeId', [id, f, c])
                    }}
                  >
                    Save type pot weights
                  </Button>
                </div>
                <Field label="Liquid reserve target %" value={typeLiquid} onChange={setTypeLiquid} />
                <div className="flex items-end">
                  <Button
                    size="sm"
                    disabled={busy || parseTypeId(typeIdInput) == null || parsePercentToWad(typeLiquid) == null}
                    loading={pendingKey === 't-liquid'}
                    onClick={() => {
                      const id = parseTypeId(typeIdInput)
                      const wad = parsePercentToWad(typeLiquid)
                      if (!id || wad == null) return
                      void writeOracle('t-liquid', 'setDefaultLiquidReservePercentageOfTypeId', [id, wad])
                    }}
                  >
                    Save type liquid reserve
                  </Button>
                </div>
              </div>
            </Card>
          ) : null}

          <Card data-testid="protocol-vault">
            <h2 className="text-lg font-semibold text-[var(--text-primary,#EDEDED)]">Vault lookup</h2>
            <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
              Resolved values after vault → type → global fallback.
            </p>
            <div className="mt-4 flex flex-col gap-3 sm:flex-row sm:items-end">
              <div className="flex-1">
                <Field label="Vault address" value={vaultInput} onChange={setVaultInput} placeholder="0x…" testId="protocol-vault-input" />
              </div>
              <Button
                size="sm"
                onClick={() => setVaultLookup(parseEthAddress(vaultInput))}
                disabled={parseEthAddress(vaultInput) == null}
              >
                Read vault
              </Button>
            </div>
            {vaultLookup ? (
              <dl className="mt-4 divide-y divide-[var(--border-subtle,rgba(255,255,255,0.08))]">
                <Row label="Vault usage fee" value={formatWadPercent(resultOf<bigint>(vaultReads.data?.[0]))} />
                <Row label="DEX swap fee" value={formatWadPercent(resultOf<bigint>(vaultReads.data?.[1]))} />
                <BondRows terms={vaultBond} />
                <Row label="Bond pot (share of minted DETF)" value={formatWadPercent(vaultSplit?.[0])} />
                <Row label="Fee collector weight of the pot" value={formatWadPercent(vaultSplit?.[1])} />
                <Row label="Creator weight of the pot" value={formatWadPercent(vaultSplit?.[2])} />
                <Row label="Liquid reserve target" value={formatWadPercent(resultOf<bigint>(vaultReads.data?.[4]))} />
              </dl>
            ) : null}

            {showOwnerForms && vaultLookup ? (
              <div className="mt-6 grid gap-4 border-t border-[var(--border-subtle,rgba(255,255,255,0.08))] pt-4 sm:grid-cols-2">
                <h3 className="sm:col-span-2 text-sm font-semibold text-[var(--text-primary,#EDEDED)]">
                  Vault overrides (0 clears the override)
                </h3>
                <Field label="Vault usage fee %" value={vaultUsageFee} onChange={setVaultUsageFee} />
                <div className="flex items-end">
                  <Button
                    size="sm"
                    disabled={busy || parsePercentToWad(vaultUsageFee) == null}
                    loading={pendingKey === 'v-usage'}
                    onClick={() => {
                      const wad = parsePercentToWad(vaultUsageFee)
                      if (wad == null) return
                      void writeOracle('v-usage', 'setUsageFeeOfVault', [vaultLookup, wad])
                    }}
                  >
                    Save vault usage fee
                  </Button>
                </div>
                <Field label="DEX swap fee %" value={vaultDexFee} onChange={setVaultDexFee} />
                <div className="flex items-end">
                  <Button
                    size="sm"
                    disabled={busy || parsePercentToWad(vaultDexFee) == null}
                    loading={pendingKey === 'v-dex'}
                    onClick={() => {
                      const wad = parsePercentToWad(vaultDexFee)
                      if (wad == null) return
                      void writeOracle('v-dex', 'setVaultDexSwapFee', [vaultLookup, wad])
                    }}
                  >
                    Save vault DEX fee
                  </Button>
                </div>
                <Field label="Min lock (days)" value={vaultMinLock} onChange={setVaultMinLock} />
                <Field label="Max lock (days)" value={vaultMaxLock} onChange={setVaultMaxLock} />
                <Field label="Min bond bonus %" value={vaultMinBonus} onChange={setVaultMinBonus} />
                <Field label="Max bond bonus %" value={vaultMaxBonus} onChange={setVaultMaxBonus} />
                <div className="sm:col-span-2">
                  <Button
                    size="sm"
                    disabled={
                      busy
                      || parseDaysToSeconds(vaultMinLock) == null
                      || parseDaysToSeconds(vaultMaxLock) == null
                      || parsePercentToWad(vaultMinBonus) == null
                      || parsePercentToWad(vaultMaxBonus) == null
                    }
                    loading={pendingKey === 'v-bond'}
                    onClick={() => {
                      const minLock = parseDaysToSeconds(vaultMinLock)
                      const maxLock = parseDaysToSeconds(vaultMaxLock)
                      const minB = parsePercentToWad(vaultMinBonus)
                      const maxB = parsePercentToWad(vaultMaxBonus)
                      if (minLock == null || maxLock == null || minB == null || maxB == null) return
                      void writeOracle('v-bond', 'setVaultBondTerms', [vaultLookup, {
                        minLockDuration: minLock,
                        maxLockDuration: maxLock,
                        minBonusPercentage: minB,
                        maxBonusPercentage: maxB,
                      }])
                    }}
                  >
                    Save vault bond terms
                  </Button>
                </div>
                <Field label="Bond pot %" value={vaultCallerShare} onChange={setVaultCallerShare} />
                <div className="flex items-end">
                  <Button
                    size="sm"
                    disabled={busy || parsePercentToWad(vaultCallerShare) == null}
                    loading={pendingKey === 'v-caller'}
                    onClick={() => {
                      const wad = parsePercentToWad(vaultCallerShare)
                      if (wad == null) return
                      void writeOracle('v-caller', 'setSeigniorageIncentivePercentageOfVault', [vaultLookup, wad])
                    }}
                  >
                    Save vault bond pot
                  </Button>
                </div>
                <Field label="Fee collector weight of the pot %" value={vaultFeeToShare} onChange={setVaultFeeToShare} />
                <Field label="Creator weight of the pot %" value={vaultCreatorShare} onChange={setVaultCreatorShare} />
                <div className="sm:col-span-2">
                  <Button
                    size="sm"
                    disabled={busy || parsePercentToWad(vaultFeeToShare) == null || parsePercentToWad(vaultCreatorShare) == null}
                    loading={pendingKey === 'v-pot'}
                    onClick={() => {
                      const f = parsePercentToWad(vaultFeeToShare)
                      const c = parsePercentToWad(vaultCreatorShare)
                      if (f == null || c == null) return
                      void writeOracle('v-pot', 'setSeignioragePotSharesOfVault', [vaultLookup, f, c])
                    }}
                  >
                    Save vault pot weights
                  </Button>
                </div>
                <Field label="Liquid reserve target %" value={vaultLiquid} onChange={setVaultLiquid} />
                <div className="flex items-end">
                  <Button
                    size="sm"
                    disabled={busy || parsePercentToWad(vaultLiquid) == null}
                    loading={pendingKey === 'v-liquid'}
                    onClick={() => {
                      const wad = parsePercentToWad(vaultLiquid)
                      if (wad == null) return
                      void writeOracle('v-liquid', 'setLiquidReservePercentageOfVault', [vaultLookup, wad])
                    }}
                  >
                    Save vault liquid reserve
                  </Button>
                </div>
              </div>
            ) : null}
          </Card>

          {error ? (
            <p className="text-sm text-[var(--danger,#E6386A)]" data-testid="protocol-error">
              {error}
            </p>
          ) : null}
          {status ? (
            <p className="text-sm text-[var(--accent,#4FD44B)]" data-testid="protocol-status">
              {status}
            </p>
          ) : null}
        </>
      )}
    </div>
  )
}
