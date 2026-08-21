'use client'

import { useMemo, useState } from 'react'
import { erc20Abi, formatUnits, parseUnits } from 'viem'
import { useAccount, usePublicClient, useReadContract, useWriteContract } from 'wagmi'

import { resolveAppChain } from '@indexedex/protocol/runtimeChains'

import { AmountField } from '../../components/ui/AmountField'
import { Button } from '../../components/ui/Button'
import { Card } from '../../components/ui/Card'
import { Tabs, TabPanel } from '../../components/ui/Tabs'
import { bondNftAbi, insightsViewAbi } from '../lib/insightsAbi'
import { isZero } from '../lib/tokenLabels'
import { lockSecondsFromDays, MAX_LOCK_DAYS, MIN_LOCK_DAYS } from '../lib/lockSeconds'

export type ActionToken = { address: `0x${string}`; symbol: string }

const inputClass =
  'mt-1 w-full rounded-lg border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-2,#1c2030)] px-3 py-2 text-sm text-[var(--text-primary,#EDEDED)]'

function deadline(): bigint {
  return BigInt(Math.floor(Date.now() / 1000) + 20 * 60)
}

function parseAmount(raw: string, decimals: number): bigint | undefined {
  if (!raw.trim()) return undefined
  try {
    return parseUnits(raw.trim(), decimals)
  } catch {
    return undefined
  }
}

export function DetfActions({
  detf,
  detfSymbol,
  pairTokens,
  chainId,
}: {
  detf?: `0x${string}`
  detfSymbol: string
  pairTokens: ActionToken[]
  chainId: number
}) {
  const { address, isConnected, chainId: walletChainId } = useAccount()
  const publicClient = usePublicClient({ chainId })
  const { writeContractAsync, isPending } = useWriteContract()
  const targetChain = resolveAppChain(chainId)
  const walletMatches = isConnected && walletChainId === chainId

  const [tab, setTab] = useState('mint')
  const [token, setToken] = useState(pairTokens[0]?.address ?? '')
  const [amount, setAmount] = useState('')
  const [lockDays, setLockDays] = useState(String(MIN_LOCK_DAYS))
  const [tokenId, setTokenId] = useState('')
  const [status, setStatus] = useState('')

  const tokenAddr = (token || pairTokens[0]?.address || '') as `0x${string}` | ''
  const tokenMeta = pairTokens.find((t) => t.address.toLowerCase() === tokenAddr.toLowerCase()) ?? pairTokens[0]
  const decimals = 18
  const parsed = parseAmount(amount, decimals)
  const lock = lockSecondsFromDays(lockDays)
  const parsedId = useMemo(() => {
    try {
      if (!tokenId.trim()) return undefined
      return BigInt(tokenId.trim())
    } catch {
      return undefined
    }
  }, [tokenId])

  const { data: balance } = useReadContract({
    address: tokenAddr || undefined,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!tokenAddr && !!address },
  })
  const { data: allowance } = useReadContract({
    address: tokenAddr || undefined,
    abi: erc20Abi,
    functionName: 'allowance',
    args: address && detf ? [address, detf] : undefined,
    query: { enabled: !!tokenAddr && !!address && !!detf },
  })
  const { data: preview } = useReadContract({
    address: detf,
    abi: insightsViewAbi,
    functionName: 'previewExchangeIn',
    args: parsed && tokenAddr && detf ? [tokenAddr, parsed, detf] : undefined,
    query: { enabled: tab === 'mint' && !!detf && !!tokenAddr && parsed != null && parsed > BigInt(0) },
  })
  const { data: bondVault } = useReadContract({
    address: detf,
    abi: insightsViewAbi,
    functionName: 'bondNftVault',
    query: { enabled: !!detf },
  })
  const { data: protocolVault } = useReadContract({
    address: detf,
    abi: insightsViewAbi,
    functionName: 'protocolNFTVault',
    query: { enabled: !!detf },
  })
  const nftVault =
    bondVault && !isZero(bondVault) ? bondVault : protocolVault && !isZero(protocolVault) ? protocolVault : undefined

  const { data: pending } = useReadContract({
    address: nftVault,
    abi: bondNftAbi,
    functionName: 'pendingRewards',
    args: parsedId !== undefined ? [parsedId] : undefined,
    query: { enabled: tab === 'claim' && !!nftVault && parsedId !== undefined },
  })
  const { data: ownerOf } = useReadContract({
    address: nftVault,
    abi: bondNftAbi,
    functionName: 'ownerOf',
    args: parsedId !== undefined ? [parsedId] : undefined,
    query: { enabled: tab === 'claim' && !!nftVault && parsedId !== undefined },
  })

  const needApprove = parsed != null && parsed > BigInt(0) && (allowance == null || allowance < parsed)
  const canSign = isConnected && walletMatches && !!detf && !!address && !isPending

  async function wait(hash: `0x${string}`, label: string) {
    setStatus(`${label} submitted.`)
    if (publicClient) {
      await publicClient.waitForTransactionReceipt({ hash })
      setStatus(`${label} confirmed.`)
    }
  }

  async function approve() {
    if (!detf || !tokenAddr || parsed == null || !address) return
    const hash = await writeContractAsync({
      chain: targetChain,
      account: address,
      address: tokenAddr,
      abi: erc20Abi,
      functionName: 'approve',
      args: [detf, parsed],
    })
    await wait(hash, 'Approve')
  }

  async function mint() {
    if (!detf || !tokenAddr || parsed == null || !address) return
    const minOut =
      preview != null && preview > BigInt(0) ? (preview * BigInt(99)) / BigInt(100) : BigInt(0)
    const hash = await writeContractAsync({
      chain: targetChain,
      account: address,
      address: detf,
      abi: insightsViewAbi,
      functionName: 'exchangeIn',
      args: [tokenAddr, parsed, detf, minOut, address, false, deadline()],
    })
    await wait(hash, 'Mint')
  }

  async function bond() {
    if (!detf || !tokenAddr || parsed == null || !address || lock == null) return
    const hash = await writeContractAsync({
      chain: targetChain,
      account: address,
      address: detf,
      abi: insightsViewAbi,
      functionName: 'bond',
      args: [tokenAddr, parsed, lock, address, false, deadline()],
    })
    await wait(hash, 'Bond')
  }

  async function claim() {
    if (!address || parsedId === undefined) return
    const target = nftVault ?? detf
    if (!target) return
    const hash = await writeContractAsync({
      chain: targetChain,
      account: address,
      address: target,
      abi: bondNftAbi,
      functionName: 'claimRewards',
      args: [parsedId, address],
    })
    await wait(hash, 'Claim rewards')
  }

  if (!detf) return null

  const blockedCopy = !isConnected
    ? 'Connect a wallet to sign.'
    : !walletMatches
      ? `Switch the wallet to chain ${chainId}.`
      : null

  return (
    <Card id="detf-actions" data-testid="detf-actions">
      <p className="text-[11px] uppercase tracking-wide text-[var(--accent,#4FD44B)]">Use this DETF</p>
      <h3 className="mt-1 text-lg font-semibold text-[var(--text-primary,#EDEDED)]">Mint, bond, claim</h3>
      <p className="mt-1 text-sm text-[var(--text-muted,#9aa3b2)]">
        Mint pays pair token and receives {detfSymbol}. Bond locks pair token for a bond NFT. Claim
        takes DETF that accrued to that bond. Claiming is not cashing the bond out.
      </p>

      <div className="mt-4">
        <Tabs
          tabs={[
            { id: 'mint', label: 'Mint' },
            { id: 'bond', label: 'Bond' },
            { id: 'claim', label: 'Claim rewards' },
          ]}
          active={tab}
          onChange={setTab}
        />
      </div>

      {tab !== 'claim' ? (
        <label className="block text-sm text-[var(--text-primary,#EDEDED)]">
          Pair token
          <select
            className={inputClass}
            value={tokenAddr}
            onChange={(e) => setToken(e.target.value)}
            data-testid="detf-action-token"
          >
            {pairTokens.map((t) => (
              <option key={t.address} value={t.address}>
                {t.symbol}
              </option>
            ))}
          </select>
        </label>
      ) : null}

      <TabPanel when="mint" active={tab}>
        <AmountField
          className="mt-4"
          label="Pay"
          symbol={tokenMeta?.symbol}
          value={amount}
          onChange={setAmount}
          decimals={decimals}
          balance={typeof balance === 'bigint' ? balance : undefined}
          data-testid="detf-mint-amount"
        />
        <p className="mt-2 text-xs text-[var(--text-muted,#9aa3b2)]">
          Preview: {preview != null ? `${formatUnits(preview, 18)} ${detfSymbol}` : '—'}
        </p>
        {blockedCopy ? <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">{blockedCopy}</p> : null}
        <div className="mt-4 flex flex-wrap gap-2">
          {needApprove ? (
            <Button type="button" onClick={() => void approve().catch((e) => setStatus(String(e?.shortMessage ?? e)))} disabled={!canSign || parsed == null} loading={isPending}>
              Approve {tokenMeta?.symbol ?? 'token'}
            </Button>
          ) : (
            <Button type="button" onClick={() => void mint().catch((e) => setStatus(String(e?.shortMessage ?? e)))} disabled={!canSign || parsed == null} loading={isPending} data-testid="detf-mint">
              Mint {detfSymbol}
            </Button>
          )}
        </div>
      </TabPanel>

      <TabPanel when="bond" active={tab}>
        <AmountField
          className="mt-4"
          label="Lock"
          symbol={tokenMeta?.symbol}
          value={amount}
          onChange={setAmount}
          decimals={decimals}
          balance={typeof balance === 'bigint' ? balance : undefined}
          data-testid="detf-bond-amount"
        />
        <label className="mt-4 block text-sm text-[var(--text-primary,#EDEDED)]">
          Lock (days)
          <input
            className={`${inputClass} font-mono`}
            value={lockDays}
            onChange={(e) => setLockDays(e.target.value)}
            inputMode="numeric"
            data-testid="detf-bond-days"
          />
        </label>
        <p className="mt-1 text-xs text-[var(--text-muted,#9aa3b2)]">
          Minimum {MIN_LOCK_DAYS} day. Maximum {MAX_LOCK_DAYS} days. You cannot cash the bond principal until it
          matures.
        </p>
        {blockedCopy ? <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">{blockedCopy}</p> : null}
        <div className="mt-4 flex flex-wrap gap-2">
          {needApprove ? (
            <Button type="button" onClick={() => void approve().catch((e) => setStatus(String(e?.shortMessage ?? e)))} disabled={!canSign || parsed == null} loading={isPending}>
              Approve {tokenMeta?.symbol ?? 'token'}
            </Button>
          ) : (
            <Button
              type="button"
              onClick={() => void bond().catch((e) => setStatus(String(e?.shortMessage ?? e)))}
              disabled={!canSign || parsed == null || lock == null}
              loading={isPending}
              data-testid="detf-bond"
            >
              Bond {tokenMeta?.symbol ?? ''}
            </Button>
          )}
        </div>
      </TabPanel>

      <TabPanel when="claim" active={tab}>
        <label className="mt-4 block text-sm text-[var(--text-primary,#EDEDED)]">
          Bond token ID
          <input
            className={`${inputClass} font-mono`}
            value={tokenId}
            onChange={(e) => setTokenId(e.target.value)}
            placeholder="1"
            data-testid="detf-claim-id"
          />
        </label>
        <p className="mt-2 text-xs text-[var(--text-muted,#9aa3b2)]">
          Pending: {pending != null ? `${formatUnits(pending, 18)} ${detfSymbol}` : '—'}
          {ownerOf && address && ownerOf.toLowerCase() !== address.toLowerCase()
            ? '. This wallet does not own that bond.'
            : ''}
        </p>
        {blockedCopy ? <p className="mt-2 text-sm text-[var(--text-muted,#9aa3b2)]">{blockedCopy}</p> : null}
        <Button
          type="button"
          className="mt-4"
          onClick={() => void claim().catch((e) => setStatus(String(e?.shortMessage ?? e)))}
          disabled={!canSign || parsedId === undefined}
          loading={isPending}
          data-testid="detf-claim"
        >
          Claim rewards
        </Button>
      </TabPanel>

      {status ? (
        <p className="mt-3 text-xs text-[var(--text-muted,#9aa3b2)]" data-testid="detf-action-status">
          {status}
        </p>
      ) : null}
    </Card>
  )
}
